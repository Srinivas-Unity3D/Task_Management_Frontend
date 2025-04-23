import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import '../theme/colors.dart';

class PhoneNumberField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final Function(PhoneNumber)? onInputChanged;

  const PhoneNumberField({
    Key? key,
    required this.label,
    required this.hint,
    required this.controller,
    this.validator,
    this.onInputChanged,
  }) : super(key: key);

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  final TextEditingController _phoneController = TextEditingController();
  String initialCountry = 'IN';
  PhoneNumber number = PhoneNumber(isoCode: 'IN');
  bool isValid = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneNumberChanged);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneNumberChanged() {
    widget.controller.text = _phoneController.text;
  }

  void _showCountryPicker(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    
    final availableSpace = screenSize.height - position.dy - size.height - bottomPadding - 16;
    final maxHeight = availableSpace.clamp(
      0.0,
      MediaQuery.of(context).size.height * 0.4,
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation1, animation2, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation1,
          curve: Curves.easeInOutCubic,
        );
        
        return Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.translucent,
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Positioned(
              top: position.dy + size.height + 8,
              left: position.dx,
              width: size.width,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.15),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: FadeTransition(
                  opacity: Tween<double>(
                    begin: 0.0,
                    end: 1.0,
                  ).animate(CurvedAnimation(
                    parent: animation1,
                    curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
                  )),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.borderColor,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CountrySearchList(
                        onSelect: (country) {
                          setState(() {
                            number = PhoneNumber(
                              isoCode: country.alpha2Code,
                              dialCode: country.dialCode,
                            );
                          });
                          if (widget.onInputChanged != null) {
                            widget.onInputChanged!(number);
                          }
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: AppColors.accentCyan,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            InkWell(
              onTap: () => _showCountryPicker(context),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.borderColor,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      Utils.getCountryFlag(number.isoCode ?? 'IN'),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      number.dialCode ?? '+91',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.textGrey,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor: AppColors.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.borderColor,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.borderColor,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.accentCyan,
                      width: 1,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                validator: widget.validator,
                onChanged: (value) {
                  if (widget.onInputChanged != null) {
                    widget.onInputChanged!(
                      PhoneNumber(
                        phoneNumber: value,
                        isoCode: number.isoCode,
                        dialCode: number.dialCode,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class CountrySearchList extends StatefulWidget {
  final Function(CountryCode) onSelect;

  const CountrySearchList({
    Key? key,
    required this.onSelect,
  }) : super(key: key);

  @override
  State<CountrySearchList> createState() => _CountrySearchListState();
}

class _CountrySearchListState extends State<CountrySearchList> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<CountryCode> _filteredCountries = [];
  final List<CountryCode> _countries = Utils.getCountryCodes();
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _filteredCountries = _countries;
    // Find the initial selected country (IN for India)
    _selectedIndex = _countries.indexWhere((country) => country.alpha2Code == 'IN');
    // Scroll to selected country after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedIndex != null) {
        _scrollToIndex(_selectedIndex!);
      }
    });
  }

  void _scrollToIndex(int index) {
    if (_scrollController.hasClients) {
      final itemHeight = 52.0; // Approximate height of each country item
      final offset = index * itemHeight;
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _filterCountries(String query) {
    setState(() {
      _filteredCountries = _countries.where((country) {
        return country.name.toLowerCase().contains(query.toLowerCase()) ||
            country.dialCode.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.borderColor.withOpacity(0.5),
                width: 1,
              ),
            ),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: 'Search country or code',
              hintStyle: const TextStyle(color: AppColors.textGrey),
              prefixIcon: const Icon(Icons.search, color: AppColors.textGrey),
              filled: true,
              fillColor: AppColors.inputBackground,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: _filterCountries,
          ),
        ),
        Flexible(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: _filteredCountries.length,
            itemBuilder: (context, index) {
              final country = _filteredCountries[index];
              return InkWell(
                onTap: () => widget.onSelect(country),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: index != _filteredCountries.length - 1
                          ? BorderSide(
                              color: AppColors.borderColor.withOpacity(0.5),
                              width: 1,
                            )
                          : BorderSide.none,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        Utils.getCountryFlag(country.alpha2Code),
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          country.name,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        country.dialCode,
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class CountryCode {
  final String name;
  final String dialCode;
  final String alpha2Code;

  const CountryCode({
    required this.name,
    required this.dialCode,
    required this.alpha2Code,
  });
}

class Utils {
  static String getCountryFlag(String countryCode) {
    return countryCode.toUpperCase().replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => String.fromCharCode(127397 + match.group(0)!.codeUnitAt(0)),
        );
  }

  static List<CountryCode> getCountryCodes() {
    return [
      const CountryCode(name: 'Afghanistan', dialCode: '+93', alpha2Code: 'AF'),
      const CountryCode(name: 'Albania', dialCode: '+355', alpha2Code: 'AL'),
      const CountryCode(name: 'Algeria', dialCode: '+213', alpha2Code: 'DZ'),
      const CountryCode(name: 'American Samoa', dialCode: '+1684', alpha2Code: 'AS'),
      const CountryCode(name: 'Andorra', dialCode: '+376', alpha2Code: 'AD'),
      const CountryCode(name: 'Angola', dialCode: '+244', alpha2Code: 'AO'),
      const CountryCode(name: 'Anguilla', dialCode: '+1264', alpha2Code: 'AI'),
      const CountryCode(name: 'Antarctica', dialCode: '+672', alpha2Code: 'AQ'),
      const CountryCode(name: 'Antigua and Barbuda', dialCode: '+1268', alpha2Code: 'AG'),
      const CountryCode(name: 'Argentina', dialCode: '+54', alpha2Code: 'AR'),
      const CountryCode(name: 'Armenia', dialCode: '+374', alpha2Code: 'AM'),
      const CountryCode(name: 'Aruba', dialCode: '+297', alpha2Code: 'AW'),
      const CountryCode(name: 'Austria', dialCode: '+43', alpha2Code: 'AT'),
      const CountryCode(name: 'Azerbaijan', dialCode: '+994', alpha2Code: 'AZ'),
      const CountryCode(name: 'Bahamas', dialCode: '+1242', alpha2Code: 'BS'),
      const CountryCode(name: 'Bahrain', dialCode: '+973', alpha2Code: 'BH'),
      const CountryCode(name: 'Bangladesh', dialCode: '+880', alpha2Code: 'BD'),
      const CountryCode(name: 'Barbados', dialCode: '+1246', alpha2Code: 'BB'),
      const CountryCode(name: 'Belarus', dialCode: '+375', alpha2Code: 'BY'),
      const CountryCode(name: 'Belgium', dialCode: '+32', alpha2Code: 'BE'),
      const CountryCode(name: 'Belize', dialCode: '+501', alpha2Code: 'BZ'),
      const CountryCode(name: 'Benin', dialCode: '+229', alpha2Code: 'BJ'),
      const CountryCode(name: 'Bermuda', dialCode: '+1441', alpha2Code: 'BM'),
      const CountryCode(name: 'Bhutan', dialCode: '+975', alpha2Code: 'BT'),
      const CountryCode(name: 'Bolivia', dialCode: '+591', alpha2Code: 'BO'),
      const CountryCode(name: 'Bosnia and Herzegovina', dialCode: '+387', alpha2Code: 'BA'),
      const CountryCode(name: 'Botswana', dialCode: '+267', alpha2Code: 'BW'),
      const CountryCode(name: 'Brazil', dialCode: '+55', alpha2Code: 'BR'),
      const CountryCode(name: 'British Indian Ocean Territory', dialCode: '+246', alpha2Code: 'IO'),
      const CountryCode(name: 'Brunei Darussalam', dialCode: '+673', alpha2Code: 'BN'),
      const CountryCode(name: 'Bulgaria', dialCode: '+359', alpha2Code: 'BG'),
      const CountryCode(name: 'Burkina Faso', dialCode: '+226', alpha2Code: 'BF'),
      const CountryCode(name: 'Burundi', dialCode: '+257', alpha2Code: 'BI'),
      const CountryCode(name: 'Cambodia', dialCode: '+855', alpha2Code: 'KH'),
      const CountryCode(name: 'Cameroon', dialCode: '+237', alpha2Code: 'CM'),
      const CountryCode(name: 'Cape Verde', dialCode: '+238', alpha2Code: 'CV'),
      const CountryCode(name: 'Cayman Islands', dialCode: '+1345', alpha2Code: 'KY'),
      const CountryCode(name: 'Central African Republic', dialCode: '+236', alpha2Code: 'CF'),
      const CountryCode(name: 'Chad', dialCode: '+235', alpha2Code: 'TD'),
      const CountryCode(name: 'Chile', dialCode: '+56', alpha2Code: 'CL'),
      const CountryCode(name: 'China', dialCode: '+86', alpha2Code: 'CN'),
      const CountryCode(name: 'Christmas Island', dialCode: '+61', alpha2Code: 'CX'),
      const CountryCode(name: 'Cocos (Keeling) Islands', dialCode: '+61', alpha2Code: 'CC'),
      const CountryCode(name: 'Colombia', dialCode: '+57', alpha2Code: 'CO'),
      const CountryCode(name: 'Comoros', dialCode: '+269', alpha2Code: 'KM'),
      const CountryCode(name: 'Congo', dialCode: '+242', alpha2Code: 'CG'),
      const CountryCode(name: 'Cook Islands', dialCode: '+682', alpha2Code: 'CK'),
      const CountryCode(name: 'Costa Rica', dialCode: '+506', alpha2Code: 'CR'),
      const CountryCode(name: 'Croatia', dialCode: '+385', alpha2Code: 'HR'),
      const CountryCode(name: 'Cuba', dialCode: '+53', alpha2Code: 'CU'),
      const CountryCode(name: 'Cyprus', dialCode: '+357', alpha2Code: 'CY'),
      const CountryCode(name: 'Czech Republic', dialCode: '+420', alpha2Code: 'CZ'),
      const CountryCode(name: 'Denmark', dialCode: '+45', alpha2Code: 'DK'),
      const CountryCode(name: 'Djibouti', dialCode: '+253', alpha2Code: 'DJ'),
      const CountryCode(name: 'Dominica', dialCode: '+1767', alpha2Code: 'DM'),
      const CountryCode(name: 'Dominican Republic', dialCode: '+1849', alpha2Code: 'DO'),
      const CountryCode(name: 'Ecuador', dialCode: '+593', alpha2Code: 'EC'),
      const CountryCode(name: 'Egypt', dialCode: '+20', alpha2Code: 'EG'),
      const CountryCode(name: 'El Salvador', dialCode: '+503', alpha2Code: 'SV'),
      const CountryCode(name: 'Equatorial Guinea', dialCode: '+240', alpha2Code: 'GQ'),
      const CountryCode(name: 'Eritrea', dialCode: '+291', alpha2Code: 'ER'),
      const CountryCode(name: 'Estonia', dialCode: '+372', alpha2Code: 'EE'),
      const CountryCode(name: 'Ethiopia', dialCode: '+251', alpha2Code: 'ET'),
      const CountryCode(name: 'Falkland Islands', dialCode: '+500', alpha2Code: 'FK'),
      const CountryCode(name: 'Faroe Islands', dialCode: '+298', alpha2Code: 'FO'),
      const CountryCode(name: 'Fiji', dialCode: '+679', alpha2Code: 'FJ'),
      const CountryCode(name: 'Finland', dialCode: '+358', alpha2Code: 'FI'),
      const CountryCode(name: 'France', dialCode: '+33', alpha2Code: 'FR'),
      const CountryCode(name: 'French Guiana', dialCode: '+594', alpha2Code: 'GF'),
      const CountryCode(name: 'French Polynesia', dialCode: '+689', alpha2Code: 'PF'),
      const CountryCode(name: 'Gabon', dialCode: '+241', alpha2Code: 'GA'),
      const CountryCode(name: 'Gambia', dialCode: '+220', alpha2Code: 'GM'),
      const CountryCode(name: 'Georgia', dialCode: '+995', alpha2Code: 'GE'),
      const CountryCode(name: 'Germany', dialCode: '+49', alpha2Code: 'DE'),
      const CountryCode(name: 'Ghana', dialCode: '+233', alpha2Code: 'GH'),
      const CountryCode(name: 'Gibraltar', dialCode: '+350', alpha2Code: 'GI'),
      const CountryCode(name: 'Greece', dialCode: '+30', alpha2Code: 'GR'),
      const CountryCode(name: 'Greenland', dialCode: '+299', alpha2Code: 'GL'),
      const CountryCode(name: 'Grenada', dialCode: '+1473', alpha2Code: 'GD'),
      const CountryCode(name: 'Guadeloupe', dialCode: '+590', alpha2Code: 'GP'),
      const CountryCode(name: 'Guam', dialCode: '+1671', alpha2Code: 'GU'),
      const CountryCode(name: 'Guatemala', dialCode: '+502', alpha2Code: 'GT'),
      const CountryCode(name: 'Guinea', dialCode: '+224', alpha2Code: 'GN'),
      const CountryCode(name: 'Guinea-Bissau', dialCode: '+245', alpha2Code: 'GW'),
      const CountryCode(name: 'Guyana', dialCode: '+592', alpha2Code: 'GY'),
      const CountryCode(name: 'Haiti', dialCode: '+509', alpha2Code: 'HT'),
      const CountryCode(name: 'Honduras', dialCode: '+504', alpha2Code: 'HN'),
      const CountryCode(name: 'Hong Kong', dialCode: '+852', alpha2Code: 'HK'),
      const CountryCode(name: 'Hungary', dialCode: '+36', alpha2Code: 'HU'),
      const CountryCode(name: 'Iceland', dialCode: '+354', alpha2Code: 'IS'),
      const CountryCode(name: 'Indonesia', dialCode: '+62', alpha2Code: 'ID'),
      const CountryCode(name: 'Iran', dialCode: '+98', alpha2Code: 'IR'),
      const CountryCode(name: 'Iraq', dialCode: '+964', alpha2Code: 'IQ'),
      const CountryCode(name: 'Ireland', dialCode: '+353', alpha2Code: 'IE'),
      const CountryCode(name: 'Israel', dialCode: '+972', alpha2Code: 'IL'),
      const CountryCode(name: 'Italy', dialCode: '+39', alpha2Code: 'IT'),
      const CountryCode(name: 'Jamaica', dialCode: '+1876', alpha2Code: 'JM'),
      const CountryCode(name: 'Japan', dialCode: '+81', alpha2Code: 'JP'),
      const CountryCode(name: 'Jordan', dialCode: '+962', alpha2Code: 'JO'),
      const CountryCode(name: 'Kazakhstan', dialCode: '+7', alpha2Code: 'KZ'),
      const CountryCode(name: 'Kenya', dialCode: '+254', alpha2Code: 'KE'),
      const CountryCode(name: 'Kiribati', dialCode: '+686', alpha2Code: 'KI'),
      const CountryCode(name: 'Kuwait', dialCode: '+965', alpha2Code: 'KW'),
      const CountryCode(name: 'Kyrgyzstan', dialCode: '+996', alpha2Code: 'KG'),
      const CountryCode(name: 'Laos', dialCode: '+856', alpha2Code: 'LA'),
      const CountryCode(name: 'Latvia', dialCode: '+371', alpha2Code: 'LV'),
      const CountryCode(name: 'Lebanon', dialCode: '+961', alpha2Code: 'LB'),
      const CountryCode(name: 'Lesotho', dialCode: '+266', alpha2Code: 'LS'),
      const CountryCode(name: 'Liberia', dialCode: '+231', alpha2Code: 'LR'),
      const CountryCode(name: 'Libya', dialCode: '+218', alpha2Code: 'LY'),
      const CountryCode(name: 'Liechtenstein', dialCode: '+423', alpha2Code: 'LI'),
      const CountryCode(name: 'Lithuania', dialCode: '+370', alpha2Code: 'LT'),
      const CountryCode(name: 'Luxembourg', dialCode: '+352', alpha2Code: 'LU'),
      const CountryCode(name: 'Macao', dialCode: '+853', alpha2Code: 'MO'),
      const CountryCode(name: 'Madagascar', dialCode: '+261', alpha2Code: 'MG'),
      const CountryCode(name: 'Malawi', dialCode: '+265', alpha2Code: 'MW'),
      const CountryCode(name: 'Malaysia', dialCode: '+60', alpha2Code: 'MY'),
      const CountryCode(name: 'Maldives', dialCode: '+960', alpha2Code: 'MV'),
      const CountryCode(name: 'Mali', dialCode: '+223', alpha2Code: 'ML'),
      const CountryCode(name: 'Malta', dialCode: '+356', alpha2Code: 'MT'),
      const CountryCode(name: 'Marshall Islands', dialCode: '+692', alpha2Code: 'MH'),
      const CountryCode(name: 'Martinique', dialCode: '+596', alpha2Code: 'MQ'),
      const CountryCode(name: 'Mauritania', dialCode: '+222', alpha2Code: 'MR'),
      const CountryCode(name: 'Mauritius', dialCode: '+230', alpha2Code: 'MU'),
      const CountryCode(name: 'Mexico', dialCode: '+52', alpha2Code: 'MX'),
      const CountryCode(name: 'Moldova', dialCode: '+373', alpha2Code: 'MD'),
      const CountryCode(name: 'Monaco', dialCode: '+377', alpha2Code: 'MC'),
      const CountryCode(name: 'Mongolia', dialCode: '+976', alpha2Code: 'MN'),
      const CountryCode(name: 'Montenegro', dialCode: '+382', alpha2Code: 'ME'),
      const CountryCode(name: 'Montserrat', dialCode: '+1664', alpha2Code: 'MS'),
      const CountryCode(name: 'Morocco', dialCode: '+212', alpha2Code: 'MA'),
      const CountryCode(name: 'Mozambique', dialCode: '+258', alpha2Code: 'MZ'),
      const CountryCode(name: 'Myanmar', dialCode: '+95', alpha2Code: 'MM'),
      const CountryCode(name: 'Namibia', dialCode: '+264', alpha2Code: 'NA'),
      const CountryCode(name: 'Nauru', dialCode: '+674', alpha2Code: 'NR'),
      const CountryCode(name: 'Nepal', dialCode: '+977', alpha2Code: 'NP'),
      const CountryCode(name: 'Netherlands', dialCode: '+31', alpha2Code: 'NL'),
      const CountryCode(name: 'New Caledonia', dialCode: '+687', alpha2Code: 'NC'),
      const CountryCode(name: 'New Zealand', dialCode: '+64', alpha2Code: 'NZ'),
      const CountryCode(name: 'Nicaragua', dialCode: '+505', alpha2Code: 'NI'),
      const CountryCode(name: 'Niger', dialCode: '+227', alpha2Code: 'NE'),
      const CountryCode(name: 'Nigeria', dialCode: '+234', alpha2Code: 'NG'),
      const CountryCode(name: 'Niue', dialCode: '+683', alpha2Code: 'NU'),
      const CountryCode(name: 'Norfolk Island', dialCode: '+672', alpha2Code: 'NF'),
      const CountryCode(name: 'North Korea', dialCode: '+850', alpha2Code: 'KP'),
      const CountryCode(name: 'Northern Mariana Islands', dialCode: '+1670', alpha2Code: 'MP'),
      const CountryCode(name: 'Norway', dialCode: '+47', alpha2Code: 'NO'),
      const CountryCode(name: 'Oman', dialCode: '+968', alpha2Code: 'OM'),
      const CountryCode(name: 'Pakistan', dialCode: '+92', alpha2Code: 'PK'),
      const CountryCode(name: 'Palau', dialCode: '+680', alpha2Code: 'PW'),
      const CountryCode(name: 'Palestine', dialCode: '+970', alpha2Code: 'PS'),
      const CountryCode(name: 'Panama', dialCode: '+507', alpha2Code: 'PA'),
      const CountryCode(name: 'Papua New Guinea', dialCode: '+675', alpha2Code: 'PG'),
      const CountryCode(name: 'Paraguay', dialCode: '+595', alpha2Code: 'PY'),
      const CountryCode(name: 'Peru', dialCode: '+51', alpha2Code: 'PE'),
      const CountryCode(name: 'Philippines', dialCode: '+63', alpha2Code: 'PH'),
      const CountryCode(name: 'Poland', dialCode: '+48', alpha2Code: 'PL'),
      const CountryCode(name: 'Portugal', dialCode: '+351', alpha2Code: 'PT'),
      const CountryCode(name: 'Puerto Rico', dialCode: '+1939', alpha2Code: 'PR'),
      const CountryCode(name: 'Qatar', dialCode: '+974', alpha2Code: 'QA'),
      const CountryCode(name: 'Romania', dialCode: '+40', alpha2Code: 'RO'),
      const CountryCode(name: 'Russia', dialCode: '+7', alpha2Code: 'RU'),
      const CountryCode(name: 'Rwanda', dialCode: '+250', alpha2Code: 'RW'),
      const CountryCode(name: 'Saint Kitts and Nevis', dialCode: '+1869', alpha2Code: 'KN'),
      const CountryCode(name: 'Saint Lucia', dialCode: '+1758', alpha2Code: 'LC'),
      const CountryCode(name: 'Saint Vincent and the Grenadines', dialCode: '+1784', alpha2Code: 'VC'),
      const CountryCode(name: 'Samoa', dialCode: '+685', alpha2Code: 'WS'),
      const CountryCode(name: 'San Marino', dialCode: '+378', alpha2Code: 'SM'),
      const CountryCode(name: 'Sao Tome and Principe', dialCode: '+239', alpha2Code: 'ST'),
      const CountryCode(name: 'Saudi Arabia', dialCode: '+966', alpha2Code: 'SA'),
      const CountryCode(name: 'Senegal', dialCode: '+221', alpha2Code: 'SN'),
      const CountryCode(name: 'Serbia', dialCode: '+381', alpha2Code: 'RS'),
      const CountryCode(name: 'Seychelles', dialCode: '+248', alpha2Code: 'SC'),
      const CountryCode(name: 'Sierra Leone', dialCode: '+232', alpha2Code: 'SL'),
      const CountryCode(name: 'Singapore', dialCode: '+65', alpha2Code: 'SG'),
      const CountryCode(name: 'Slovakia', dialCode: '+421', alpha2Code: 'SK'),
      const CountryCode(name: 'Slovenia', dialCode: '+386', alpha2Code: 'SI'),
      const CountryCode(name: 'Solomon Islands', dialCode: '+677', alpha2Code: 'SB'),
      const CountryCode(name: 'Somalia', dialCode: '+252', alpha2Code: 'SO'),
      const CountryCode(name: 'South Africa', dialCode: '+27', alpha2Code: 'ZA'),
      const CountryCode(name: 'South Korea', dialCode: '+82', alpha2Code: 'KR'),
      const CountryCode(name: 'South Sudan', dialCode: '+211', alpha2Code: 'SS'),
      const CountryCode(name: 'Spain', dialCode: '+34', alpha2Code: 'ES'),
      const CountryCode(name: 'Sri Lanka', dialCode: '+94', alpha2Code: 'LK'),
      const CountryCode(name: 'Sudan', dialCode: '+249', alpha2Code: 'SD'),
      const CountryCode(name: 'Suriname', dialCode: '+597', alpha2Code: 'SR'),
      const CountryCode(name: 'Swaziland', dialCode: '+268', alpha2Code: 'SZ'),
      const CountryCode(name: 'Sweden', dialCode: '+46', alpha2Code: 'SE'),
      const CountryCode(name: 'Switzerland', dialCode: '+41', alpha2Code: 'CH'),
      const CountryCode(name: 'Syria', dialCode: '+963', alpha2Code: 'SY'),
      const CountryCode(name: 'Taiwan', dialCode: '+886', alpha2Code: 'TW'),
      const CountryCode(name: 'Tajikistan', dialCode: '+992', alpha2Code: 'TJ'),
      const CountryCode(name: 'Tanzania', dialCode: '+255', alpha2Code: 'TZ'),
      const CountryCode(name: 'Thailand', dialCode: '+66', alpha2Code: 'TH'),
      const CountryCode(name: 'Timor-Leste', dialCode: '+670', alpha2Code: 'TL'),
      const CountryCode(name: 'Togo', dialCode: '+228', alpha2Code: 'TG'),
      const CountryCode(name: 'Tokelau', dialCode: '+690', alpha2Code: 'TK'),
      const CountryCode(name: 'Tonga', dialCode: '+676', alpha2Code: 'TO'),
      const CountryCode(name: 'Trinidad and Tobago', dialCode: '+1868', alpha2Code: 'TT'),
      const CountryCode(name: 'Tunisia', dialCode: '+216', alpha2Code: 'TN'),
      const CountryCode(name: 'Turkey', dialCode: '+90', alpha2Code: 'TR'),
      const CountryCode(name: 'Turkmenistan', dialCode: '+993', alpha2Code: 'TM'),
      const CountryCode(name: 'Turks and Caicos Islands', dialCode: '+1649', alpha2Code: 'TC'),
      const CountryCode(name: 'Tuvalu', dialCode: '+688', alpha2Code: 'TV'),
      const CountryCode(name: 'Uganda', dialCode: '+256', alpha2Code: 'UG'),
      const CountryCode(name: 'Ukraine', dialCode: '+380', alpha2Code: 'UA'),
      const CountryCode(name: 'United Arab Emirates', dialCode: '+971', alpha2Code: 'AE'),
      const CountryCode(name: 'Uruguay', dialCode: '+598', alpha2Code: 'UY'),
      const CountryCode(name: 'Uzbekistan', dialCode: '+998', alpha2Code: 'UZ'),
      const CountryCode(name: 'Vanuatu', dialCode: '+678', alpha2Code: 'VU'),
      const CountryCode(name: 'Vatican City', dialCode: '+379', alpha2Code: 'VA'),
      const CountryCode(name: 'Venezuela', dialCode: '+58', alpha2Code: 'VE'),
      const CountryCode(name: 'Vietnam', dialCode: '+84', alpha2Code: 'VN'),
      const CountryCode(name: 'Virgin Islands, British', dialCode: '+1284', alpha2Code: 'VG'),
      const CountryCode(name: 'Virgin Islands, U.S.', dialCode: '+1340', alpha2Code: 'VI'),
      const CountryCode(name: 'Wallis and Futuna', dialCode: '+681', alpha2Code: 'WF'),
      const CountryCode(name: 'Yemen', dialCode: '+967', alpha2Code: 'YE'),
      const CountryCode(name: 'Zambia', dialCode: '+260', alpha2Code: 'ZM'),
      const CountryCode(name: 'Zimbabwe', dialCode: '+263', alpha2Code: 'ZW'),
    ];
  }
} 