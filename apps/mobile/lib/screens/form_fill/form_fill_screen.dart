import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:epi_core/epi_core.dart';
import 'package:epi_shared/epi_shared.dart';
import '../../providers/app_providers.dart';
import 'governorate_dropdown.dart';
import 'district_dropdown.dart';
import 'photo_picker_field.dart';

class FormFillScreen extends ConsumerStatefulWidget {
  final String formId;
  const FormFillScreen({super.key, required this.formId});

  @override
  ConsumerState<FormFillScreen> createState() => _FormFillScreenState();
}

class _FormFillScreenState extends ConsumerState<FormFillScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  final Map<String, TextEditingController> _textControllers = {};
  bool _isLoading = false;
  bool _isSavingDraft = false;
  bool _isGettingLocation = false;
  bool _hasUnsavedChanges = false;
  Map<String, dynamic>? _formSchema;

  // Support both formats: sections (new) and flat fields (old)
  List<dynamic> _sections = [];
  List<dynamic> _flatFields = [];

  double? _gpsLat;
  double? _gpsLng;
  final List<XFile> _pickedPhotos = [];

  // Auto-save timer
  Timer? _autoSaveTimer;

  TextEditingController _getController(String key, {String? initialValue}) {
    if (!_textControllers.containsKey(key)) {
      _textControllers[key] = TextEditingController(text: initialValue ?? '');
    }
    return _textControllers[key]!;
  }

  @override
  void initState() {
    super.initState();
    _loadForm();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_hasUnsavedChanges && _formData.isNotEmpty) {
        _autoSave(showFeedback: false);
      }
    });
  }

  Future<void> _loadForm() async {
    setState(() => _isLoading = true);
    Map<String, dynamic>? form;

    try {
      final cache = await ref.read(offlineDataCacheProvider.future).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('timeout'),
      );
      final cachedForms = cache.getCachedDataList('forms');
      if (cachedForms != null) {
        for (final f in cachedForms) {
          if (f['id'] == widget.formId) {
            form = f;
            break;
          }
        }
      }

      if (form == null) {
        final db = ref.read(databaseServiceProvider);
        form = await db.getForm(widget.formId).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Network timeout'),
        );
        await cache.cacheFormData(widget.formId, form);
      }

      final schema = form['schema'] as Map<String, dynamic>? ?? {};

      setState(() {
        _formSchema = form;
        _sections = (schema['sections'] as List?) ?? [];
        _flatFields = (schema['fields'] as List?) ?? [];
        _isLoading = false;
      });

      await _loadDraft();
    } on TimeoutException {
      setState(() => _isLoading = false);
      if (mounted) context.showError('انتهت مهلة تحميل النموذج — تحقق من الاتصال');
    } catch (e) {
      debugPrint('[FormFillScreen] Load form error: $e');
      setState(() => _isLoading = false);
      if (mounted) context.showError('فشل تحميل النموذج: ${e.toString()}');
    }
  }

  Future<void> _loadDraft() async {
    try {
      final offline = await ref.read(offlineManagerProvider.future).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Offline storage not ready for draft loading');
        },
      );
      final draft = offline.getDraft(widget.formId);
      if (draft != null && draft['data'] != null) {
        final draftData = Map<String, dynamic>.from(draft['data']);
        setState(() {
          _formData.addAll(draftData);
          _hasUnsavedChanges = false;
        });
        for (final entry in draftData.entries) {
          if (_textControllers.containsKey(entry.key)) {
            _textControllers[entry.key]!.text = entry.value?.toString() ?? '';
          }
        }

        // ═══ FIX: Restore GPS coordinates from draft data ═══
        // GPS fields store "lat, lng" as a string in _formData
        // We must restore _gpsLat/_gpsLng so the UI shows "تم تحديد الموقع ✓"
        for (final field in _allFields) {
          if (field['type'] == 'gps') {
            final key = field['key'] as String;
            final gpsStr = _formData[key] as String?;
            if (gpsStr != null && gpsStr.contains(',')) {
              final parts = gpsStr.split(',').map((s) => s.trim()).toList();
              if (parts.length == 2) {
                final lat = double.tryParse(parts[0]);
                final lng = double.tryParse(parts[1]);
                if (lat != null && lng != null) {
                  _gpsLat = lat;
                  _gpsLng = lng;
                }
              }
            }
          }
        }

        if (mounted) {
          context.showInfo('تم استعادة المسودة السابقة');
        }
      }
    } on TimeoutException {
      // Non-critical
    } catch (_) {
      // Non-critical
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
    super.dispose();
  }

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

      for (final field in _allFields) {
        if (field['type'] == 'gps') {
          final key = field['key'] as String;
          _formData[key] = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        }
      }
      _markChanged();

      if (mounted) context.showSuccess('تم تحديد الموقع بنجاح');
    } catch (e) {
      setState(() => _isGettingLocation = false);
      if (mounted) context.showError('فشل الحصول على الموقع: ${e.toString()}');
    }
  }

  void _syncControllersToFormData() {
    for (final entry in _textControllers.entries) {
      _formData[entry.key] = entry.value.text;
    }
  }

  Future<void> _submit() async {
    _syncControllersToFormData();

    final formState = _formKey.currentState;
    if (formState == null) return;
    if (!formState.validate()) return;

    final missingFields = <String>[];
    for (final field in _allFields) {
      final key = field['key'] as String? ?? '';
      final type = field['type'] as String? ?? 'text';
      final label = field['label_ar'] as String? ?? key;
      final isRequired = field['required'] == true;
      if (!isRequired) continue;

      switch (type) {
        case 'multiselect':
          final val = _formData[key] as List?;
          if (val == null || val.isEmpty) missingFields.add(label);
          break;
        case 'yesno':
          if (_formData[key] == null) missingFields.add(label);
          break;
        case 'date':
        case 'time':
          if (_formData[key] == null || (_formData[key] as String?)?.isEmpty == true) missingFields.add(label);
          break;
        case 'gps':
          if (_gpsLat == null) missingFields.add(label);
          break;
        case 'photo':
          if (_pickedPhotos.isEmpty) missingFields.add(label);
          break;
        case 'governorate':
          if (_formData[key] == null) missingFields.add(label);
          break;
        case 'district':
          if (_formData[key] == null) missingFields.add(label);
          break;
      }
    }
    if (missingFields.isNotEmpty) {
      context.showWarning('الحقول التالية مطلوبة: ${missingFields.join("، ")}');
      return;
    }

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

    final OfflineManager offline;
    try {
      offline = await ref.read(offlineManagerProvider.future).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Offline storage not ready');
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showError('التخزين المحلي غير جاهز. حاول إعادة فتح التطبيق.');
      }
      return;
    }

    try {
      final submissionData = {
        'form_id': widget.formId,
        'data': Map<String, dynamic>.from(_formData),
        if (_gpsLat != null) 'gps_lat': _gpsLat,
        if (_gpsLng != null) 'gps_lng': _gpsLng,
        'created_at': DateTime.now().toIso8601String(),
      };

      await offline.addToSyncQueue(submissionData);
      await offline.saveDraft(widget.formId, Map<String, dynamic>.from(_formData));

      if (offline.isOnline) {
        ref.read(syncServiceProvider.future).then((syncService) async {
          try {
            final result = await syncService.sync();
            if (kDebugMode) {
              print('[FormSubmit] Immediate sync: ${result.synced} synced, ${result.failed} failed');
            }
            if (result.synced > 0) {
              try { await offline.removeDraft(widget.formId); } catch (_) {}
            }
          } catch (e) {
            if (kDebugMode) print('[FormSubmit] Immediate sync failed (will retry): $e');
          }
        }).catchError((e) {
          if (kDebugMode) print('[FormSubmit] SyncService not available: $e');
        });
      }

      if (mounted) {
        if (offline.isOnline) {
          context.showSuccess('تم الحفظ والإرسال ✅');
        } else {
          context.showSuccess(AppStrings.formSubmittedOffline);
        }
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        context.showError('فشل حفظ البيانات محلياً: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDraft() async {
    _syncControllersToFormData();

    if (_formData.isEmpty) {
      context.showWarning('املأ بعض الحقول أولاً قبل الحفظ');
      return;
    }
    setState(() => _isSavingDraft = true);
    try {
      final offline = await ref.read(offlineManagerProvider.future).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Offline storage not ready');
        },
      );
      await offline.saveDraft(widget.formId, Map<String, dynamic>.from(_formData));
      _hasUnsavedChanges = false;
      if (mounted) context.showSuccess(AppStrings.draftSaved);
    } on TimeoutException {
      if (mounted) context.showError('التخزين المحلي غير جاهز. حاول مرة أخرى.');
    } catch (e) {
      final errorMsg = e.toString();
      if (mounted) {
        if (errorMsg.contains('LateInitializationError') || errorMsg.contains('Hive')) {
          context.showError('خطأ في التخزين المحلي. حاول إعادة فتح التطبيق.');
        } else {
          context.showError('فشل حفظ المسودة: $errorMsg');
        }
      }
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  Future<void> _autoSave({bool showFeedback = false}) async {
    _syncControllersToFormData();
    if (_formData.isEmpty) return;

    try {
      final offline = await ref.read(offlineManagerProvider.future).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Offline storage not ready for auto-save');
        },
      );
      await offline.saveDraft(widget.formId, Map<String, dynamic>.from(_formData));
      _hasUnsavedChanges = false;
      if (showFeedback && mounted) {
        context.showSuccess('تم الحفظ التلقائي');
      }
    } on TimeoutException {
      // Silent
    } catch (_) {
      // Silent
    }
  }

  void _markChanged() {
    _hasUnsavedChanges = true;
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

    final sortedSections = List.from(_sections);
    sortedSections.sort((a, b) => (a['order'] as int? ?? 0).compareTo(b['order'] as int? ?? 0));

    for (final section in sortedSections) {
      final title = section['title_ar'] as String? ?? '';
      final fields = (section['fields'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12, top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
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
          controller: _getController(key, initialValue: _formData[key]?.toString()),
          hint: hint,
          onChanged: (v) { _formData[key] = v; _markChanged(); },
          validator: isRequired ? (v) => (v == null || v.isEmpty) ? AppStrings.required : null : null,
        );

      case 'phone':
        return EpiTextField(
          controller: _getController(key, initialValue: _formData[key]?.toString()),
          hint: hint ?? '07XXXXXXXXX',
          keyboardType: TextInputType.phone,
          onChanged: (v) { _formData[key] = v; _markChanged(); },
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
          controller: _getController(key, initialValue: _formData[key]?.toString()),
          hint: hint,
          maxLines: 4,
          onChanged: (v) { _formData[key] = v; _markChanged(); },
          validator: isRequired ? (v) => (v == null || v.isEmpty) ? AppStrings.required : null : null,
        );

      case 'number':
        return EpiTextField(
          controller: _getController(key, initialValue: _formData[key]?.toString()),
          hint: hint,
          keyboardType: TextInputType.number,
          onChanged: (v) { _formData[key] = num.tryParse(v); _markChanged(); },
          validator: isRequired ? (v) => (v == null || v.isEmpty) ? AppStrings.required : null : null,
        );

      case 'select':
        final options = (field['options'] as List?)?.cast<String>() ?? [];
        return EpiDropdown<String>(
          hint: hint,
          value: _formData[key],
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontFamily: 'Tajawal')))).toList(),
          onChanged: (v) => setState(() { _formData[key] = v; _markChanged(); }),
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
              selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
              checkmarkColor: AppTheme.primaryColor,
              onSelected: (sel) {
                setState(() {
                  if (sel) {
                    selected.add(o);
                  } else {
                    selected.remove(o);
                  }
                  _formData[key] = selected;
                  _markChanged();
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
                  onTap: () => setState(() { _formData[key] = true; _markChanged(); }),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: currentValue == true ? AppTheme.successColor.withValues(alpha: 0.15) : null,
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
                  onTap: () => setState(() { _formData[key] = false; _markChanged(); }),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: currentValue == false ? AppTheme.errorColor.withValues(alpha: 0.15) : null,
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
              setState(() { _formData[key] = date.toIso8601String().split('T')[0]; _markChanged(); });
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
              setState(() { _formData[key] = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'; _markChanged(); });
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
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
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
        return GovernorateDropdown(
          value: _formData[key],
          onChanged: (v) => setState(() {
            _formData[key] = v;
            _formData['district_id'] = null;
            _formData['district'] = null;
            _markChanged();
          }),
          isRequired: isRequired,
        );

      case 'district':
        return DistrictDropdown(
          governorateId: _formData['governorate_id'] as String?,
          value: _formData[key],
          onChanged: (v) => setState(() { _formData[key] = v; _markChanged(); }),
          isRequired: isRequired,
        );

      case 'photo':
        return PhotoPickerField(
          key: ValueKey('photo_$key'),
          photos: _pickedPhotos,
          maxPhotos: (_formSchema?['max_photos'] as int?) ?? 1,
          onPhotosChanged: (photos) {
            setState(() {
              _pickedPhotos.clear();
              _pickedPhotos.addAll(photos);
              _formData[key] = photos.map((p) => p.path).toList();
              _markChanged();
            });
          },
          isRequired: isRequired,
        );

      default:
        return EpiTextField(
          controller: _getController(key, initialValue: _formData[key]?.toString()),
          hint: hint,
          onChanged: (v) { _formData[key] = v; _markChanged(); },
        );
    }
  }
}
