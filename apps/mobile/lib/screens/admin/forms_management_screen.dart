import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epi_shared/epi_shared.dart';
import '../../providers/app_providers.dart';

class AdminFormsScreen extends ConsumerStatefulWidget {
  const AdminFormsScreen({super.key});

  @override
  ConsumerState<AdminFormsScreen> createState() => _AdminFormsScreenState();
}

class _AdminFormsScreenState extends ConsumerState<AdminFormsScreen> {
  List<Map<String, dynamic>>? _forms;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadForms();
  }

  Future<void> _loadForms() async {
    setState(() => _isLoading = true);
    try {
      // Load all forms including inactive ones for admin
      final forms = await ref.read(databaseServiceProvider).getForms(activeOnly: false);
      setState(() {
        _forms = forms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) context.showError('فشل تحميل النماذج: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final forms = _forms ?? [];

    return Scaffold(
      appBar: const EpiAppBar(title: 'إدارة النماذج'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormEditor(null),
        icon: const Icon(Icons.add),
        label: const Text('نموذج جديد', style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: _isLoading
          ? const EpiLoading.shimmer()
          : forms.isEmpty
              ? const EpiEmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'لا توجد نماذج',
                  subtitle: 'انقر على + لإنشاء نموذج جديد',
                )
              : RefreshIndicator(
                  onRefresh: _loadForms,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: forms.length,
                    itemBuilder: (context, index) {
                      final form = forms[index];
                      return _FormAdminCard(
                        form: form,
                        onEdit: () => _showFormEditor(form),
                        onToggleActive: () => _toggleFormActive(form),
                        onDelete: () => _confirmDeleteForm(form),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _toggleFormActive(Map<String, dynamic> form) async {
    final isActive = form['is_active'] as bool? ?? true;
    try {
      await ref.read(databaseServiceProvider).updateForm(
        form['id'],
        {'is_active': !isActive},
      );
      _loadForms();
      if (mounted) context.showSuccess(isActive ? 'تم تعطيل النموذج' : 'تم تفعيل النموذج');
    } catch (e) {
      if (mounted) context.showError('فشل: ${e.toString()}');
    }
  }

  Future<void> _confirmDeleteForm(Map<String, dynamic> form) async {
    final confirmed = await context.showConfirmDialog(
      title: 'حذف النموذج',
      message: 'هل أنت متأكد من حذف "${form['title_ar']}"؟',
      confirmText: 'حذف',
    );
    if (confirmed != true) return;

    try {
      await ref.read(apiClientProvider).softDelete('forms', filters: {'id': form['id']});
      _loadForms();
      if (mounted) context.showSuccess('تم حذف النموذج');
    } catch (e) {
      if (mounted) context.showError('فشل الحذف: ${e.toString()}');
    }
  }

  void _showFormEditor(Map<String, dynamic>? existingForm) {
    final isEdit = existingForm != null;
    final titleArController = TextEditingController(text: existingForm?['title_ar'] ?? '');
    final titleEnController = TextEditingController(text: existingForm?['title_en'] ?? '');
    final descArController = TextEditingController(text: existingForm?['description_ar'] ?? '');
    final descEnController = TextEditingController(text: existingForm?['description_en'] ?? '');

    bool requiresGps = existingForm?['requires_gps'] ?? false;
    bool requiresPhoto = existingForm?['requires_photo'] ?? false;
    bool isActive = existingForm?['is_active'] ?? true;

    // Parse existing fields from schema
    final existingSchema = existingForm?['schema'] as Map<String, dynamic>? ?? {};
    final List<Map<String, dynamic>> fields = [];
    if (existingSchema['fields'] != null) {
      fields.addAll((existingSchema['fields'] as List).cast<Map<String, dynamic>>());
    } else if (existingSchema['sections'] != null) {
      for (final section in (existingSchema['sections'] as List)) {
        if (section['fields'] != null) {
          fields.addAll((section['fields'] as List).cast<Map<String, dynamic>>());
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'تعديل النموذج' : 'إنشاء نموذج جديد',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),

                // Basic Info
                EpiTextField(label: 'العنوان (عربي)', controller: titleArController, prefixIcon: Icons.title),
                const SizedBox(height: 12),
                EpiTextField(label: 'Title (English)', controller: titleEnController, prefixIcon: Icons.title),
                const SizedBox(height: 12),
                EpiTextField(label: 'الوصف (عربي)', controller: descArController, maxLines: 2, prefixIcon: Icons.description),
                const SizedBox(height: 12),
                EpiTextField(label: 'Description (English)', controller: descEnController, maxLines: 2, prefixIcon: Icons.description),
                const SizedBox(height: 16),

                // Options
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('GPS مطلوب', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
                        value: requiresGps,
                        onChanged: (v) => setSheetState(() => requiresGps = v),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('صورة مطلوبة', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
                        value: requiresPhoto,
                        onChanged: (v) => setSheetState(() => requiresPhoto = v),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('نشط', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
                  value: isActive,
                  onChanged: (v) => setSheetState(() => isActive = v),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Fields section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('حقول النموذج',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700)),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                      onPressed: () => _addFieldDialog(setSheetState, fields),
                      tooltip: 'إضافة حقل',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (fields.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('لا توجد حقول — انقر + لإضافة',
                          style: TextStyle(fontFamily: 'Tajawal', color: AppTheme.textSecondary)),
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: fields.length,
                    onReorder: (oldIndex, newIndex) {
                      setSheetState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = fields.removeAt(oldIndex);
                        fields.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final field = fields[index];
                      return Card(
                        key: ValueKey('field_$index'),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.drag_handle, color: AppTheme.textHint),
                          title: Text(
                            field['label_ar'] ?? field['key'] ?? '',
                            style: const TextStyle(fontFamily: 'Tajawal'),
                          ),
                          subtitle: Text(
                            '${_fieldTypeLabel(field['type'] ?? 'text')}${field['required'] == true ? ' • مطلوب' : ''}',
                            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _editFieldDialog(setSheetState, fields, index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorColor),
                                onPressed: () => setSheetState(() => fields.removeAt(index)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),

                // Save button
                EpiButton(
                  text: isEdit ? 'حفظ التعديلات' : 'إنشاء النموذج',
                  isLoading: false,
                  onPressed: () async {
                    if (titleArController.text.isEmpty || titleEnController.text.isEmpty) {
                      context.showError('العنوان مطلوب بالعربية والإنجليزية');
                      return;
                    }

                    final schema = <String, dynamic>{
                      'fields': fields,
                      'version': '1.0',
                    };

                    final data = <String, dynamic>{
                      'title_ar': titleArController.text.trim(),
                      'title_en': titleEnController.text.trim(),
                      'description_ar': descArController.text.trim(),
                      'description_en': descEnController.text.trim(),
                      'schema': schema,
                      'requires_gps': requiresGps,
                      'requires_photo': requiresPhoto,
                      'is_active': isActive,
                    };

                    try {
                      if (isEdit) {
                        await ref.read(databaseServiceProvider).updateForm(existingForm['id'], data);
                      } else {
                        await ref.read(databaseServiceProvider).createForm(data);
                      }
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        _loadForms();
                        context.showSuccess(isEdit ? 'تم تحديث النموذج' : 'تم إنشاء النموذج');
                      }
                    } catch (e) {
                      if (ctx.mounted) context.showError('فشل: ${e.toString()}');
                    }
                  },
                  width: double.infinity,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addFieldDialog(StateSetter setSheetState, List<Map<String, dynamic>> fields) {
    _editFieldDialog(setSheetState, fields, -1);
  }

  void _editFieldDialog(StateSetter setSheetState, List<Map<String, dynamic>> fields, int editIndex) {
    final isEdit = editIndex >= 0;
    final existing = isEdit ? fields[editIndex] : <String, dynamic>{};

    final keyController = TextEditingController(text: existing['key'] ?? '');
    final labelArController = TextEditingController(text: existing['label_ar'] ?? '');
    final hintController = TextEditingController(text: existing['hint'] ?? '');
    String fieldType = existing['type'] ?? 'text';
    bool isRequired = existing['required'] ?? false;
    final optionsController = TextEditingController(
      text: (existing['options'] as List?)?.join(', ') ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            isEdit ? 'تعديل الحقل' : 'إضافة حقل',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    labelText: 'المفتاح (key)',
                    hintText: 'e.g. patient_name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelArController,
                  decoration: const InputDecoration(
                    labelText: 'التسمية (عربي)',
                    hintText: 'e.g. اسم المريض',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hintController,
                  decoration: const InputDecoration(
                    labelText: 'التلميح (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: fieldType,
                  decoration: const InputDecoration(labelText: 'نوع الحقل', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'text', child: Text('نص')),
                    DropdownMenuItem(value: 'number', child: Text('رقم')),
                    DropdownMenuItem(value: 'phone', child: Text('هاتف')),
                    DropdownMenuItem(value: 'textarea', child: Text('نص طويل')),
                    DropdownMenuItem(value: 'select', child: Text('قائمة منسدلة')),
                    DropdownMenuItem(value: 'multiselect', child: Text('اختيار متعدد')),
                    DropdownMenuItem(value: 'yesno', child: Text('نعم/لا')),
                    DropdownMenuItem(value: 'date', child: Text('تاريخ')),
                    DropdownMenuItem(value: 'time', child: Text('وقت')),
                    DropdownMenuItem(value: 'gps', child: Text('موقع GPS')),
                    DropdownMenuItem(value: 'photo', child: Text('صورة')),
                    DropdownMenuItem(value: 'governorate', child: Text('محافظة')),
                    DropdownMenuItem(value: 'district', child: Text('مديرية')),
                    DropdownMenuItem(value: 'signature', child: Text('توقيع')),
                  ],
                  onChanged: (v) => setDialogState(() => fieldType = v!),
                ),
                const SizedBox(height: 12),
                if (fieldType == 'select' || fieldType == 'multiselect')
                  TextField(
                    controller: optionsController,
                    decoration: const InputDecoration(
                      labelText: 'الخيارات (مفصولة بفاصلة)',
                      hintText: 'خيار 1, خيار 2, خيار 3',
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (fieldType == 'select' || fieldType == 'multiselect') const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('حقل مطلوب', style: TextStyle(fontFamily: 'Tajawal')),
                  value: isRequired,
                  onChanged: (v) => setDialogState(() => isRequired = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (keyController.text.isEmpty || labelArController.text.isEmpty) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    const SnackBar(content: Text('المفتاح والتسمية مطلوبان')),
                  );
                  return;
                }

                final field = <String, dynamic>{
                  'key': keyController.text.trim(),
                  'label_ar': labelArController.text.trim(),
                  'type': fieldType,
                  'required': isRequired,
                };
                if (hintController.text.isNotEmpty) field['hint'] = hintController.text.trim();
                if ((fieldType == 'select' || fieldType == 'multiselect') && optionsController.text.isNotEmpty) {
                  field['options'] = optionsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                }

                setSheetState(() {
                  if (isEdit) {
                    fields[editIndex] = field;
                  } else {
                    fields.add(field);
                  }
                });
                Navigator.pop(dialogCtx);
              },
              child: Text(isEdit ? 'حفظ' : 'إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  String _fieldTypeLabel(String type) {
    switch (type) {
      case 'text': return 'نص';
      case 'number': return 'رقم';
      case 'phone': return 'هاتف';
      case 'textarea': return 'نص طويل';
      case 'select': return 'قائمة';
      case 'multiselect': return 'اختيار متعدد';
      case 'yesno': return 'نعم/لا';
      case 'date': return 'تاريخ';
      case 'time': return 'وقت';
      case 'gps': return 'GPS';
      case 'photo': return 'صورة';
      case 'governorate': return 'محافظة';
      case 'district': return 'مديرية';
      case 'signature': return 'توقيع';
      default: return type;
    }
  }
}

class _FormAdminCard extends StatelessWidget {
  final Map<String, dynamic> form;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _FormAdminCard({
    required this.form,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = form['is_active'] as bool? ?? true;
    final title = form['title_ar'] ?? 'بدون عنوان';
    final description = form['description_ar'];
    final schema = form['schema'] as Map<String, dynamic>? ?? {};
    final fieldsCount = _countFields(schema);

    return EpiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primarySurface : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.assignment,
                  color: isActive ? AppTheme.primaryColor : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700)),
                    if (description != null && description.toString().isNotEmpty)
                      Text(description,
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              EpiStatusChip(
                status: isActive ? 'active' : 'inactive',
                label: isActive ? 'نشط' : 'معطّل',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfo(Icons.layers, '$fieldsCount حقل'),
              if (form['requires_gps'] == true) _buildInfo(Icons.location_on, 'GPS'),
              if (form['requires_photo'] == true) _buildInfo(Icons.camera_alt, 'صور'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('تعديل', style: TextStyle(fontFamily: 'Tajawal')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onToggleActive,
                icon: Icon(isActive ? Icons.block : Icons.check_circle, size: 18),
                label: Text(isActive ? 'تعطيل' : 'تفعيل', style: const TextStyle(fontFamily: 'Tajawal')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isActive ? AppTheme.warningColor : AppTheme.successColor,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                tooltip: 'حذف',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(IconData icon, String text) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.primaryColor)),
        ],
      ),
    );
  }

  int _countFields(Map<String, dynamic> schema) {
    if (schema['fields'] != null) return (schema['fields'] as List).length;
    if (schema['sections'] != null) {
      int count = 0;
      for (final s in (schema['sections'] as List)) {
        count += (s['fields'] as List?)?.length ?? 0;
      }
      return count;
    }
    return 0;
  }
}
