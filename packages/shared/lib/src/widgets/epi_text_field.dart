import 'package:flutter/material.dart';

class EpiTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final int? maxLines;
  final int? maxLength;
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextDirection? textDirection;

  const EpiTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffix,
    this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      maxLength: maxLength,
      textDirection: textDirection ?? TextDirection.rtl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffix,
      ),
    );
  }
}
