import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epi_shared/epi_shared.dart';
import '../../providers/app_providers.dart';

/// Governorate dropdown — loads from Supabase with offline cache fallback.
class GovernorateDropdown extends ConsumerWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool isRequired;

  const GovernorateDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    required this.isRequired,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final governoratesAsync = ref.watch(governoratesProvider);

    return governoratesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('خطأ: $e', style: const TextStyle(color: Colors.red)),
      data: (governorates) {
        return EpiDropdown<String>(
          hint: 'اختر المحافظة',
          value: value,
          items: governorates.map((g) {
            return DropdownMenuItem(
              value: g['id'] as String,
              child: Text(g['name_ar'] as String, style: const TextStyle(fontFamily: 'Tajawal')),
            );
          }).toList(),
          onChanged: onChanged,
          validator: isRequired ? (v) => v == null ? AppStrings.required : null : null,
        );
      },
    );
  }
}
