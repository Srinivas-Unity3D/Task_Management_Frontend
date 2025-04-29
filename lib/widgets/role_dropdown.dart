import 'package:flutter/material.dart';
import '../theme/colors.dart';

class RoleDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final List<String> items;
  final String? value;
  final void Function(String?)? onChanged;
  final String? Function(String?)? validator;
  final bool showError;
  final bool isLoading;

  const RoleDropdown({
    Key? key,
    required this.label,
    required this.hint,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.showError = false,
    this.isLoading = false,
  }) : super(key: key);

  void _showRoleSelector(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    
    // Calculate available space below the dropdown
    final availableSpace = screenSize.height - position.dy - size.height - bottomPadding - 16;
    
    // Calculate maximum height for the dropdown
    final maxHeight = availableSpace.clamp(
      0.0,
      MediaQuery.of(context).size.height * 0.4,
    );

    // Create scroll controller
    final ScrollController scrollController = ScrollController();
    
    // Calculate initial scroll position if there's a selected value
    if (value != null) {
      final selectedIndex = items.indexOf(value!);
      if (selectedIndex != -1) {
        // Wait for the list to be built before scrolling
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final itemHeight = 44.0; // Height of each item (padding + content)
          final targetScroll = (selectedIndex * itemHeight).clamp(
            0.0,
            scrollController.position.maxScrollExtent,
          );
          scrollController.animateTo(
            targetScroll,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          );
        });
      }
    }
    
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
                      constraints: BoxConstraints(
                        maxHeight: maxHeight,
                      ),
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ListView.builder(
                          controller: scrollController,
                          shrinkWrap: true,
                          padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 0),
                          physics: const BouncingScrollPhysics(),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isSelected = item == value;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  onChanged?.call(item);
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.cardBackground.withOpacity(0.3) : Colors.transparent,
                                    border: Border(
                                      bottom: index != items.length - 1 ? BorderSide(
                                        color: AppColors.borderColor.withOpacity(0.5),
                                        width: 1,
                                      ) : BorderSide.none,
                                    ),
                                  ),
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      color: isSelected 
                                          ? AppColors.accentCyan 
                                          : AppColors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
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
    final String? errorText = showError ? validator?.call(value) : null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        InkWell(
          onTap: () => _showRoleSelector(context),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: errorText != null ? Colors.red : AppColors.borderColor,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? hint,
                    style: TextStyle(
                      color: value == null ? AppColors.textGrey : AppColors.white,
                      fontSize: 16,
                    ),
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
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
} 