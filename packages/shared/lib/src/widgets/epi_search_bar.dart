import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EpiSearchBar extends StatelessWidget {
  final String? hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final VoidCallback? onClear;

  const EpiSearchBar({
    super.key,
    this.hint,
    this.onChanged,
    this.controller,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        hintText: hint ?? 'بحث...',
        prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
        suffixIcon: controller?.text.isNotEmpty == true
            ? IconButton(
                icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                onPressed: () {
                  controller?.clear();
                  onChanged?.call('');
                  onClear?.call();
                },
              )
            : null,
      ),
    );
  }
}
