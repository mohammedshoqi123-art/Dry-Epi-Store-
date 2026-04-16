import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epi_shared/epi_shared.dart';
import '../../providers/app_providers.dart';

/// المرفق الصحي dropdown — depends on selected district.
/// Shows placeholder if no district is selected.
class HealthFacilityDropdown extends ConsumerWidget {
  final String? districtId;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool isRequired;

  const HealthFacilityDropdown({
    super.key,
    required this.districtId,
    required this.value,
    required this.onChanged,
    required this.isRequired,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (districtId == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'اختر المديرية أولاً',
          style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500),
        ),
      );
    }

    final facilitiesAsync = ref.watch(healthFacilitiesProvider(districtId));

    return facilitiesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) =>
          Text('خطأ: $e', style: const TextStyle(color: Colors.red)),
      data: (facilities) {
        if (facilities.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'لا توجد مرافق صحية لهذه المديرية',
              style:
                  TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500),
            ),
          );
        }
        return EpiDropdown<String>(
          hint: 'اختر المرفق الصحي',
          value: value,
          items: facilities.map((f) {
            final typeIcon = f['type'] == 'hospital' ? '🏥' : '🏩';
            return DropdownMenuItem(
              value: f['id'] as String,
              child: Text('$typeIcon ${f['name_ar']}',
                  style: const TextStyle(fontFamily: 'Tajawal')),
            );
          }).toList(),
          onChanged: onChanged,
          validator:
              isRequired ? (v) => v == null ? AppStrings.required : null : null,
        );
      },
    );
  }
}
