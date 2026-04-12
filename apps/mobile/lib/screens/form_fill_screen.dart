import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:epi_shared/epi_shared.dart';
import '../providers/app_providers.dart';

class FormFillScreen extends ConsumerStatefulWidget {
  final String formId;
  const FormFillScreen({super.key, required this.formId});

  @override
  ConsumerState<FormFillScreen> createState() => _FormFillScreenState();
}

class _FormFillScreenState extends ConsumerState<FormFillScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  bool _isLoading = false;
  bool _isSavingDraft = false;
  bool _isGettingLocation = false;
  Map<String, dynamic>? _formSchema;
  
  // Support both formats: sections (new) and flat fields (old)
  List<dynamic> _sections = [];
  List<dynamic> _flatFields = [];
  
  double? _gpsLat;
  double? _gpsLng;

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  Future<void> _loadForm() async {
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseServiceProvider);
      final form = await db.getForm(widget.formId);
      final schema = form['schema'] as Map<String, dynamic>? ?? {};
      
      setState(() {
        _formSchema = form;
        _sections = (schema['sections'] as List?) ?? [];
        _flatFields = (schema['fields'] as List?) ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) context.showError('فشل تحميل النموذج');
    }
  }

  /// Get all fields (flattened) for GPS and validation
  List<Map<String, dynamic>> get _allFields {
    if (_sections.isNotEmpty) {
      return _sections
          .expand((s) => (s['fields'] as List? ?? []))
          .cast<Map<String, dynamic>>()
          .toList();
    }
    return _flatFields.cast<Map<String, dynamic>>().toList();
  }

  Future<void> _getLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) context.showError('خدمة الموقع غير مفعّلة');
        setState(() => _isGettingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) context.showError('تم رفض إذن الموقع');
          setState(() => _isGettingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) context.showError('تم رفض إذن الموقع نهائياً. يرجى تفعيله من الإعدادات');
        setState(() => _isGettingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      setState(() {
        _gpsLat = position.latitude;
        _gpsLng = position.longitude;
        _isGettingLocation = false;
      });

      // Update GPS fields
      for (final field in _allFields) {
        if (field['type'] == 'gps') {
          final key = field['key'] as String;
          _formData[key] = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        }
      }

      if (mounted) context.showSuccess('تم تحديد الموقع بنجاح');
    } catch (e) {
      setState(() => _isGettingLocation = false);
      if (mounted) context.showError('فشل الحصول على الموقع: ${e.toString()}');
    }
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null) return;
    if (!formState.validate()) return;

    // Check GPS
    final requiresGps = _formSchema?['requires_gps'] == true;
    if (requiresGps && _gpsLat == null) {
      final shouldGetLocation = await context.showConfirmDialog(
        title: 'موقع GPS مطلوب',
        message: 'هذا النموذج يتطلب تحديد الموقع. هل تريد تحديده الآن؟',
        confirmText: 'تحديد الموقع',
      );
      if (shouldGetLocation == true) {
        await _getLocation();
        if (_gpsLat == null) return;
      } else {
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final submissionData = {
        'form_id': widget.formId,
        'data': Map<String, dynamic>.from(_formData),
        if (_gpsLat != null) 'gps_lat': _gpsLat,
        if (_gpsLng != null) 'gps_lng': _gpsLng,
      };

      final offline = await ref.read(offlineManagerProvider.future);

      if (offline.isOnline) {
        final db = ref.read(databaseServiceProvider);
        await db.submitForm(submissionData);
        if (mounted) {
          context.showSuccess(AppStrings.formSubmitted);
          context.pop();
        }
      } else {
        await offline.addToSyncQueue({
          ...submissionData,
          'created_at': DateTime.now().toIso8601String(),
        });
        if (mounted) {
          context.showSuccess(AppStrings.formSubmittedOffline);
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) context.showError('فشل الإرسال: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDraft() async {
    if (_formData.isEmpty) {
      context.showWarning('املأ بعض الحقول أولاً قبل الحفظ');
      return;
    }
    setState(() => _isSavingDraft = true);
    try {
      final offline = await ref.read(offlineManagerProvider.future);
      await offline.saveDraft(widget.formId, Map<String, dynamic>.from(_formData));
      if (mounted) context.showSuccess(AppStrings.draftSaved);
    } catch (e) {
      if (mounted) context.showError('فشل حفظ المسودة: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EpiAppBar(
        title: _formSchema?['title_ar'] ?? 'تعبئة النموذج',
        actions: [
          TextButton.icon(
            onPressed: _isSavingDraft ? null : _saveDraft,
            icon: _isSavingDraft
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, color: Colors.white, size: 20),
            label: const Text('حفظ', style: TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
          ),
        ],
      ),
      body: _isLoading && _formSchema == null
          ? const EpiLoading()
          : _allFields.isEmpty
              ? const EpiEmptyState(icon: Icons.description, title: 'لا توجد حقول في النموذج')
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_formSchema?['description_ar'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _formSchema!['description_ar'],
                            style: const TextStyle(fontFamily: 'Tajawal', color: AppTheme.textSecondary),
                          ),
                        ),
                      // Build sections or flat fields
                      if (_sections.isNotEmpty)
                        ..._buildSections()
                      else
                        ..._flatFields.map((field) => _buildField(field as Map<String, dynamic>)),
                      const SizedBox(height: 24),
                      EpiButton(
                        text: AppStrings.submit,
                        isLoading: _isLoading,
                        onPressed: _submit,
                        width: double.infinity,
                        icon: Icons.send,
                      ),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _buildSections() {
    final widgets = <Widget>[];
    
    // Sort sections by order
    final sortedSections = List.from(_sections);
    sortedSections.sort((a, b) => (a['order'] as int? ?? 0).compareTo(b['order'] as int? ?? 0));
    
    for (final section in sortedSections) {
      final title = section['title_ar'] as String? ?? '';
      final fields = (section['fields'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      // Section header
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12, top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      
      // Section fields
      for (final field in fields) {
        widgets.add(_buildField(field));
      }
      
      widgets.add(const SizedBox(height: 8));
    }
    
    return widgets;
  }

  Widget _buildField(Map<String, dynamic> field) {
    final key = field['key'] as String? ?? '';
    final type = field['type'] as String? ?? 'text';
    final label = field['label_ar'] as String? ?? key;
    final isRequired = field['required'] == true;
    final hint = field['hint'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600),
                ),
              ),
              if (isRequired) const Text(' *', style: TextStyle(color: AppTheme.errorColor)),
            ],
          ),
          const SizedBox(height: 8),
          _buildFieldInput(field, key, type, hint, isRequired),
        ],
      ),
    );
  }

  Widget _buildFieldInput(Map<String, dynamic> field, String key, String type, String? hint, bool isRequired) {
    switch (type) {
      case 'text':
        return EpiTextField(
          hint: hint,
          onChanged: (v) => _formData[key] = v,
          validator: isRequired ? (v) => (v == null || v.isEmpty) ? AppStrings.required : null : null,
        );

      case 'phone':
        return EpiTextField(
          hint: hint ?? '07XXXXXXXXX',
          keyboardType: TextInputType.phone,
          onChanged: (v) => _formData[key] = v,
          validator: isRequired
              ? (v) {
                  if (v == null || v.isEmpty) return AppStrings.required;
                  if (!RegExp(r'^07\d{9}$').hasMatch(v)) return 'رقم الجوال غير صحيح';
                  return null;
                }
              : null,
        );

      case 'textarea':
        return EpiTextField(
          hint: hint,
          maxLines: 4,
          onChanged: (v) => _formData[key] = v,
          validator: isRequired ? (v) => (v == null || v.isEmpty) ? AppStrings.required : null : null,
        );

      case 'number':
        return EpiTextField(
          hint: hint,
          keyboardType: TextInputType.number,
          onChanged: (v) => _formData[key] = num.tryParse(v),
          validator: isRequired ? (v) => (v == null || v.isEmpty) ? AppStrings.required : null : null,
        );

      case 'select':
        final options = (field['options'] as List?)?.cast<String>() ?? [];
        return EpiDropdown<String>(
          hint: hint,
          value: _formData[key],
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontFamily: 'Tajawal')))).toList(),
          onChanged: (v) => setState(() => _formData[key] = v),
          validator: isRequired ? (v) => v == null ? AppStrings.required : null : null,
        );

      case 'multiselect':
        final options = (field['options'] as List?)?.cast<String>() ?? [];
        final selected = (_formData[key] as List?)?.cast<String>() ?? [];
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: options.map((o) {
            final isSelected = selected.contains(o);
            return FilterChip(
              label: Text(o, style: const TextStyle(fontFamily: 'Tajawal')),
              selected: isSelected,
              selectedColor: AppTheme.primaryColor.withOpacity(0.2),
              checkmarkColor: AppTheme.primaryColor,
              onSelected: (sel) {
                setState(() {
                  if (sel) {
                    selected.add(o);
                  } else {
                    selected.remove(o);
                  }
                  _formData[key] = selected;
                });
              },
            );
          }).toList(),
        );

      case 'yesno':
        final currentValue = _formData[key] as bool?;
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _formData[key] = true),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: currentValue == true ? AppTheme.successColor.withOpacity(0.15) : null,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(11)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          currentValue == true ? Icons.check_circle : Icons.circle_outlined,
                          color: currentValue == true ? AppTheme.successColor : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'نعم',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: currentValue == true ? FontWeight.bold : FontWeight.normal,
                            color: currentValue == true ? AppTheme.successColor : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade300),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _formData[key] = false),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: currentValue == false ? AppTheme.errorColor.withOpacity(0.15) : null,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          currentValue == false ? Icons.cancel : Icons.circle_outlined,
                          color: currentValue == false ? AppTheme.errorColor : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'لا',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: currentValue == false ? FontWeight.bold : FontWeight.normal,
                            color: currentValue == false ? AppTheme.errorColor : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case 'date':
        final dateValue = _formData[key] as String?;
        return InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              locale: const Locale('ar'),
            );
            if (date != null) {
              setState(() => _formData[key] = date.toIso8601String().split('T')[0]);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: hint ?? 'اختر التاريخ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: const Icon(Icons.calendar_today, size: 20),
            ),
            child: Text(
              dateValue ?? hint ?? 'اختر التاريخ',
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: dateValue != null ? Colors.black : Colors.grey,
              ),
            ),
          ),
        );

      case 'time':
        final timeValue = _formData[key] as String?;
        return InkWell(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (time != null) {
              setState(() => _formData[key] = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: hint ?? 'اختر الوقت',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: const Icon(Icons.access_time, size: 20),
            ),
            child: Text(
              timeValue ?? hint ?? 'اختر الوقت',
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: timeValue != null ? Colors.black : Colors.grey,
              ),
            ),
          ),
        );

      case 'gps':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _gpsLat != null ? 'تم تحديد الموقع ✓' : 'انقر لتحديد الموقع',
                      style: const TextStyle(fontFamily: 'Tajawal'),
                    ),
                    if (_gpsLat != null)
                      Text(
                        '${_gpsLat!.toStringAsFixed(6)}, ${_gpsLng!.toStringAsFixed(6)}',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
              _isGettingLocation
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                    )
                  : IconButton(
                      icon: const Icon(Icons.my_location, color: AppTheme.primaryColor),
                      onPressed: _getLocation,
                      tooltip: 'تحديد الموقع',
                    ),
            ],
          ),
        );

      case 'governorate':
        return _GovernorateDropdown(
          value: _formData[key],
          onChanged: (v) => setState(() => _formData[key] = v),
          isRequired: isRequired,
        );

      case 'district':
        return _DistrictDropdown(
          governorateId: _formData['governorate_id'] as String?,
          value: _formData[key],
          onChanged: (v) => setState(() => _formData[key] = v),
          isRequired: isRequired,
        );

      case 'photo':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Icon(Icons.camera_alt, size: 40, color: AppTheme.primaryColor),
              const SizedBox(height: 8),
              Text(
                'انقر لإرفاق صورة',
                style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade600),
              ),
            ],
          ),
        );

      case 'signature':
        return Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.draw, size: 32, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'انقر للتوقيع',
                  style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        );

      default:
        return EpiTextField(
          hint: hint,
          onChanged: (v) => _formData[key] = v,
        );
    }
  }
}

// ─── Governorate Dropdown ───────────────────────────────────────────────────

class _GovernorateDropdown extends ConsumerWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool isRequired;

  const _GovernorateDropdown({
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

// ─── District Dropdown ──────────────────────────────────────────────────────

class _DistrictDropdown extends ConsumerWidget {
  final String? governorateId;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool isRequired;

  const _DistrictDropdown({
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
