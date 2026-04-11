import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  Map<String, dynamic>? _formSchema;
  List<dynamic> _fields = [];

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
      setState(() {
        _formSchema = form;
        _fields = (form['schema']?['fields'] as List?) ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) context.showError('فشل تحميل النموذج');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseServiceProvider);
      await db.submitForm({
        'form_id': widget.formId,
        'data': _formData,
      });
      if (mounted) {
        context.showSuccess(AppStrings.submitSuccess);
        context.pop();
      }
    } catch (e) {
      if (mounted) context.showError('فشل الإرسال: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _isSavingDraft = true);
    try {
      final offline = await ref.read(offlineManagerProvider.future);
      await offline.saveDraft(widget.formId, _formData);
      if (mounted) context.showSuccess(AppStrings.draftSaved);
    } catch (e) {
      if (mounted) context.showError('فشل حفظ المسودة');
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
          : _fields.isEmpty
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
                      ..._fields.map((field) => _buildField(field)),
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
              Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600)),
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
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) => setState(() => _formData[key] = v),
          validator: isRequired ? (v) => v == null ? AppStrings.required : null : null,
        );
      case 'date':
        return EpiTextField(
          hint: hint ?? 'اختر التاريخ',
          prefixIcon: Icons.calendar_today,
          readOnly: true,
          controller: TextEditingController(text: _formData[key]?.toString() ?? ''),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (date != null) {
              setState(() => _formData[key] = date.toIso8601String().split('T')[0]);
            }
          },
        );
      case 'gps':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_formData[key] != null ? 'تم تحديد الموقع' : 'انقر لتحديد الموقع',
                        style: const TextStyle(fontFamily: 'Tajawal')),
                    if (_formData[key] != null)
                      Text(_formData[key].toString(),
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.my_location, color: AppTheme.primaryColor),
                onPressed: () {
                  // Would use geolocator here
                  setState(() => _formData[key] = '33.3152, 44.3661');
                },
              ),
            ],
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
