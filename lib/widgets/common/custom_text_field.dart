import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// A standardized, dark-mode themed text input field used for forms.
///
/// Features built-in password toggling, custom formatting, and read-only states.
class CustomTextField extends StatefulWidget {
  final String label;
  final TextEditingController? controller;

  /// If true, obscures the text and adds an eye icon to toggle visibility.
  final bool isPassword;

  final TextInputType keyboardType;
  final VoidCallback? onTap;

  /// If true, prevents the keyboard from popping up (e.g. when acting as a dropdown trigger).
  final bool readOnly;

  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;

  /// Creates a new [CustomTextField] instance.
  const CustomTextField({
    super.key,
    required this.label,
    this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.onTap,
    this.readOnly = false,
    this.suffixIcon,
    this.inputFormatters,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  void _toggleVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      onTap: widget.onTap,
      readOnly: widget.readOnly,
      style: AppTextStyles.bodygrey,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey,
                ),
                onPressed: _toggleVisibility,
              )
            : widget.suffixIcon,
        labelStyle: const TextStyle(color: Colors.grey),
        floatingLabelStyle: const TextStyle(color: AppColors.textPrimary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.textPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
