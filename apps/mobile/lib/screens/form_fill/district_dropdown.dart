import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epi_shared/epi_shared.dart';
import '../../providers/app_providers.dart';

/// District dropdown — depends on selected governorate.
/// Shows placeholder if no governorate is selected.
class DistrictDropdown extends ConsumerWidget {
  final String? governorateId;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool isRequired;

  const DistrictDropdown({
    super.key,
    required this.governorateId,
    required this.value,
    required this.onChanged,
    required this.isRequired,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (governorateId == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'اختر المحافظة أولاً',
          style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500),
        ),
      );
    }

    final districtsAsync = ref.watch(districtsProvider(governorateId));

    return districtsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('خطأ: $e', style: const TextStyle(color: Colors.red)),
      data: (districts) {
        return EpiDropdown<String>(
          hint: 'اختر المديرية',
          value: value,
          items: districts.map((d) {
            return DropdownMenuItem(
              value: d['id'] as String,
              child: Text(d['name_ar'] as String, style: const TextStyle(fontFamily: 'Tajawal')),
            );
          }).toList(),
          onChanged: onChanged,
          validator: isRequired ? (v) => v == null ? AppStrings.required : null : null,
        );
      },
    );
  }
}
