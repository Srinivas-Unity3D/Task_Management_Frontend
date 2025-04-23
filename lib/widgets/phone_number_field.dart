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
  List<CountryCode> _filteredCountries = [];
  final List<CountryCode> _countries = Utils.getCountryCodes();

  @override
  void initState() {
    super.initState();
    _filteredCountries = _countries;
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
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: 'Search country or code',
              hintStyle: const TextStyle(color: AppColors.textGrey),
              prefixIcon: const Icon(Icons.search, color: AppColors.textGrey),
              filled: true,
              fillColor: AppColors.inputBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _filterCountries,
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _filteredCountries.length,
            itemBuilder: (context, index) {
              final country = _filteredCountries[index];
              return InkWell(
                onTap: () => widget.onSelect(country),
                child: Container(
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
      const CountryCode(name: 'India', dialCode: '+91', alpha2Code: 'IN'),
      const CountryCode(name: 'United States', dialCode: '+1', alpha2Code: 'US'),
      const CountryCode(name: 'United Kingdom', dialCode: '+44', alpha2Code: 'GB'),
      const CountryCode(name: 'Canada', dialCode: '+1', alpha2Code: 'CA'),
      const CountryCode(name: 'Australia', dialCode: '+61', alpha2Code: 'AU'),
      const CountryCode(name: 'Afghanistan', dialCode: '+93', alpha2Code: 'AF'),
      const CountryCode(name: 'Albania', dialCode: '+355', alpha2Code: 'AL'),
      const CountryCode(name: 'Algeria', dialCode: '+213', alpha2Code: 'DZ'),
      const CountryCode(name: 'American Samoa', dialCode: '+1684', alpha2Code: 'AS'),
      const CountryCode(name: 'Andorra', dialCode: '+376', alpha2Code: 'AD'),
      const CountryCode(name: 'Angola', dialCode: '+244', alpha2Code: 'AO'),
      const CountryCode(name: 'Anguilla', dialCode: '+1264', alpha2Code: 'AI'),
      // Add more countries as needed
    ];
  }
} 