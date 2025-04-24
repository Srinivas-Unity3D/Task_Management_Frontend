import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

class CustomTextField extends StatefulWidget {
  final String label;
  final String hint;
  final bool isPassword;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const CustomTextField({
    Key? key,
    required this.label,
    required this.hint,
    required this.controller,
    this.isPassword = false,
    this.validator,
    this.suffixIcon,
    this.keyboardType,
    this.inputFormatters,
  }) : super(key: key);

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;
  bool _isDirty = false;

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
        TextFormField(
          controller: widget.controller,
          obscureText: widget.isPassword ? _obscureText : false,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
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
            errorStyle: const TextStyle(
              color: Colors.red,
              fontSize: 12,
              height: 0,
            ),
            filled: true,
            fillColor: AppColors.inputBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppColors.borderColor,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
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
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textGrey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : widget.suffixIcon,
          ),
          validator: (value) {
            if (!_isDirty) {
              return widget.validator?.call(value);
            }
            return null;
          },
          onChanged: (value) {
            setState(() {
              _isDirty = true;
            });
          },
        ),
      ],
    );
  }
}