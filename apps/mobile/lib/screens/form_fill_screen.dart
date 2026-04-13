import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:epi_shared/epi_shared.dart';
import 'dart:io';
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
  String? _signatureData; // base64 or path of signature image

  // Auto-save timer
  Timer? _autoSaveTimer;

  /// Get or create a TextEditingController for a field key
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
    // Auto-save every 30 seconds if there are changes
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_hasUnsavedChanges && _formData.isNotEmpty) {
        _autoSave(showFeedback: false);
      }
    });
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

      // Load existing draft if available
      await _loadDraft();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) context.showError('فشل تحميل النموذج');
    }
  }

  /// Load saved draft data into the form
  Future<void> _loadDraft() async {
    try {
      final offline = await ref.read(offlineManagerProvider.future);
      final draft = offline.getDraft(widget.formId);
      if (draft != null && draft['data'] != null) {
        final draftData = Map<String, dynamic>.from(draft['data']);
        setState(() {
          _formData.addAll(draftData);
          _hasUnsavedChanges = false;
        });
        // Restore text controller values
        for (final entry in draftData.entries) {
          if (_textControllers.containsKey(entry.key)) {
            _textControllers[entry.key]!.text = entry.value?.toString() ?? '';
          }
        }
        if (mounted) {
          context.showInfo('تم استعادة المسودة السابقة');
        }
      }
    } catch (_) {
      // Draft loading is non-critical — silently ignore errors
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
      _markChanged();

      if (mounted) context.showSuccess('تم تحديد الموقع بنجاح');
    } catch (e) {
      setState(() => _isGettingLocation = false);
      if (mounted) context.showError('فشل الحصول على الموقع: ${e.toString()}');
    }
  }

  /// Sync all text controllers back to _formData before validation/submission
  void _syncControllersToFormData() {
    for (final entry in _textControllers.entries) {
      _formData[entry.key] = entry.value.text;
    }
  }

  Future<void> _submit() async {
    // Sync controllers FIRST — ensures _formData has latest text field values
    _syncControllersToFormData();

    final formState = _formKey.currentState;
    if (formState == null) return;
    if (!formState.validate()) return;

    // Custom validation for non-FormField types
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
        case 'signature':
          if (_signatureData == null || _signatureData?.isEmpty == true) missingFields.add(label);
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
          // Remove draft after successful submission
          try { await offline.removeDraft(widget.formId); } catch (_) {}
          if (mounted) context.showSuccess(AppStrings.formSubmitted);
          if (mounted) context.pop();
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
      final errorMsg = e.toString();
      if (mounted) {
        if (errorMsg.contains('Network') || errorMsg.contains('Socket') || errorMsg.contains('connection')) {
          context.showError('لا يوجد اتصال بالإنترنت. تم حفظ البيانات محلياً.');
          // Auto-save as draft on network error
          try {
            final offline = await ref.read(offlineManagerProvider.future);
            await offline.saveDraft(widget.formId, Map<String, dynamic>.from(_formData));
            if (mounted) context.showInfo('تم حفظ المسودة تلقائياً');
          } catch (_) {}
        } else if (errorMsg.contains('Unauthorized') || errorMsg.contains('401')) {
          // Save draft BEFORE showing session expired message — preserve user data!
          try {
            final offline = await ref.read(offlineManagerProvider.future);
            await offline.saveDraft(widget.formId, Map<String, dynamic>.from(_formData));
          } catch (_) {}
          if (mounted) {
            context.showError('انتهت الجلسة. تم حفظ بياناتك كمسودة. يرجى تسجيل الدخول وإعادة الإرسال.');
          }
        } else {
          // On any error, try to save as draft
          try {
            final offline = await ref.read(offlineManagerProvider.future);
            await offline.saveDraft(widget.formId, Map<String, dynamic>.from(_formData));
          } catch (_) {}
          if (mounted) context.showError('فشل الإرسال: $errorMsg (تم حفظ البيانات كمسودة)');
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDraft() async {
    // Sync controllers first so we save the latest text values
    _syncControllersToFormData();

    if (_formData.isEmpty) {
      context.showWarning('املأ بعض الحقول أولاً قبل الحفظ');
      return;
    }
    setState(() => _isSavingDraft = true);
    try {
      final offline = await ref.read(offlineManagerProvider.future);
      await offline.saveDraft(widget.formId, Map<String, dynamic>.from(_formData));
      _hasUnsavedChanges = false;
      if (mounted) context.showSuccess(AppStrings.draftSaved);
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

  /// Silent auto-save (no UI feedback unless showFeedback is true)
  Future<void> _autoSave({bool showFeedback = false}) async {
    _syncControllersToFormData();
    if (_formData.isEmpty) return;

    try {
      final offline = await ref.read(offlineManagerProvider.future);
      await offline.saveDraft(widget.formId, Map<String, dynamic>.from(_formData));
      _hasUnsavedChanges = false;
      if (showFeedback && mounted) {
        context.showSuccess('تم الحفظ التلقائي');
      }
    } catch (_) {
      // Auto-save failures are silent
    }
  }

  /// Mark that data has changed (triggers auto-save on next cycle)
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
                  onTap: () => setState(() { _formData[key] = false; _markChanged(); }),
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
          onChanged: (v) => setState(() {
            _formData[key] = v;
            // Clear district when governorate changes
            _formData['district_id'] = null;
            _formData['district'] = null;
            _markChanged();
          }),
          isRequired: isRequired,
        );

      case 'district':
        return _DistrictDropdown(
          governorateId: _formData['governorate_id'] as String?,
          value: _formData[key],
          onChanged: (v) => setState(() { _formData[key] = v; _markChanged(); }),
          isRequired: isRequired,
        );

      case 'photo':
        return _PhotoPickerField(
          key: ValueKey('photo_$key'),
          photos: _pickedPhotos,
          maxPhotos: (_formSchema?['max_photos'] as int?) ?? 5,
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

      case 'signature':
        return _SignatureField(
          key: ValueKey('sig_$key'),
          signatureData: _signatureData,
          onSignatureChanged: (data) {
            setState(() {
              _signatureData = data;
              _formData[key] = data;
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

// ─── Photo Picker ──────────────────────────────────────────────────────────

class _PhotoPickerField extends StatelessWidget {
  final List<XFile> photos;
  final int maxPhotos;
  final ValueChanged<List<XFile>> onPhotosChanged;
  final bool isRequired;

  const _PhotoPickerField({
    super.key,
    required this.photos,
    required this.maxPhotos,
    required this.onPhotosChanged,
    required this.isRequired,
  });

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );
      if (picked != null) {
        final updated = List<XFile>.from(photos)..add(picked);
        onPhotosChanged(updated);
      }
    } catch (e) {
      if (context.mounted) context.showError('فشل التقاط الصورة');
    }
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              title: const Text('الكاميرا', style: TextStyle(fontFamily: 'Tajawal')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title: const Text('المعرض', style: TextStyle(fontFamily: 'Tajawal')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo grid
        if (photos.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(photos[index].path),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            final updated = List<XFile>.from(photos)..removeAt(index);
                            onPhotosChanged(updated);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.errorColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (photos.isNotEmpty) const SizedBox(height: 8),
        // Add button
        if (photos.length < maxPhotos)
          InkWell(
            onTap: () => _showPickerOptions(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isRequired && photos.isEmpty
                      ? AppTheme.errorColor
                      : Colors.grey.shade300,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isRequired && photos.isEmpty
                    ? AppTheme.errorColor.withOpacity(0.05)
                    : null,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_a_photo,
                    size: 32,
                    color: isRequired && photos.isEmpty
                        ? AppTheme.errorColor
                        : AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    photos.isEmpty
                        ? 'انقر لإرفاق صورة (${photos.length}/$maxPhotos)'
                        : 'إضافة صورة أخرى (${photos.length}/$maxPhotos)',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: isRequired && photos.isEmpty
                          ? AppTheme.errorColor
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Signature Field ────────────────────────────────────────────────────────

class _SignatureField extends StatelessWidget {
  final String? signatureData;
  final ValueChanged<String?> onSignatureChanged;
  final bool isRequired;

  const _SignatureField({
    super.key,
    this.signatureData,
    required this.onSignatureChanged,
    required this.isRequired,
  });

  @override
  Widget build(BuildContext context) {
    final hasSignature = signatureData != null && signatureData!.isNotEmpty;

    return InkWell(
      onTap: () => _openSignaturePad(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(
            color: isRequired && !hasSignature
                ? AppTheme.errorColor
                : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isRequired && !hasSignature
              ? AppTheme.errorColor.withOpacity(0.05)
              : null,
        ),
        child: hasSignature
            ? Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, size: 32, color: AppTheme.successColor),
                        const SizedBox(height: 8),
                        const Text(
                          'تم التوقيع ✓',
                          style: TextStyle(fontFamily: 'Tajawal', color: AppTheme.successColor),
                        ),
                        TextButton(
                          onPressed: () => _openSignaturePad(context),
                          child: const Text('إعادة التوقيع', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.draw,
                    size: 32,
                    color: isRequired && !hasSignature
                        ? AppTheme.errorColor
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'انقر للتوقيع',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: isRequired && !hasSignature
                          ? AppTheme.errorColor
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _openSignaturePad(BuildContext context) {
    // Simple signature using a dialog with a text field for now
    // A full signature pad would need a custom painter
    final controller = TextEditingController(text: signatureData ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('التوقيع', style: TextStyle(fontFamily: 'Cairo')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'اكتب اسمك كتوقيع (سيتم تحسين هذه الميزة لاحقاً بلوحة رسم)',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'اكتب اسمك هنا',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                onSignatureChanged(text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('تأكيد', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }
}
