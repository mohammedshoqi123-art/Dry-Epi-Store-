import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

/// Available form field types for the dynamic form builder
enum FormFieldType {
  text,
  number,
  email,
  phone,
  date,
  time,
  dateTime,
  dropdown,
  radio,
  checkbox,
  multiSelect,
  file,
  image,
  location,
  section,
  divider,
  paragraph,
}

/// Extension for Arabic labels
extension FormFieldTypeExt on FormFieldType {
  String get labelAr {
    switch (this) {
      case FormFieldType.text:
        return 'نص';
      case FormFieldType.number:
        return 'رقم';
      case FormFieldType.email:
        return 'بريد إلكتروني';
      case FormFieldType.phone:
        return 'هاتف';
      case FormFieldType.date:
        return 'تاريخ';
      case FormFieldType.time:
        return 'وقت';
      case FormFieldType.dateTime:
        return 'تاريخ ووقت';
      case FormFieldType.dropdown:
        return 'قائمة منسدلة';
      case FormFieldType.radio:
        return 'اختيار واحد';
      case FormFieldType.checkbox:
        return 'مربع اختيار';
      case FormFieldType.multiSelect:
        return 'اختيار متعدد';
      case FormFieldType.file:
        return 'ملف';
      case FormFieldType.image:
        return 'صورة';
      case FormFieldType.location:
        return 'موقع';
      case FormFieldType.section:
        return 'قسم';
      case FormFieldType.divider:
        return 'فاصل';
      case FormFieldType.paragraph:
        return 'فقرة';
    }
  }

  IconData get icon {
    switch (this) {
      case FormFieldType.text:
        return Icons.text_fields;
      case FormFieldType.number:
        return Icons.numbers;
      case FormFieldType.email:
        return Icons.email_outlined;
      case FormFieldType.phone:
        return Icons.phone_outlined;
      case FormFieldType.date:
        return Icons.calendar_today;
      case FormFieldType.time:
        return Icons.access_time;
      case FormFieldType.dateTime:
        return Icons.event;
      case FormFieldType.dropdown:
        return Icons.arrow_drop_down_circle;
      case FormFieldType.radio:
        return Icons.radio_button_checked;
      case FormFieldType.checkbox:
        return Icons.check_box;
      case FormFieldType.multiSelect:
        return Icons.checklist;
      case FormFieldType.file:
        return Icons.attach_file;
      case FormFieldType.image:
        return Icons.image;
      case FormFieldType.location:
        return Icons.location_on;
      case FormFieldType.section:
        return Icons.view_headline;
      case FormFieldType.divider:
        return Icons.horizontal_rule;
      case FormFieldType.paragraph:
        return Icons.notes;
    }
  }
}

/// Definition of a single form field
class FormFieldDefinition {
  final String id;
  final String name;
  final String label;
  final FormFieldType type;
  final bool required;
  final Map<String, dynamic> validation;
  final Map<String, dynamic> options;
  final String? defaultValue;
  final String? helpText;
  final int order;

  FormFieldDefinition({
    required this.id,
    required this.name,
    required this.label,
    required this.type,
    this.required = false,
    this.validation = const {},
    this.options = const {},
    this.defaultValue,
    this.helpText,
    this.order = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'label': label,
        'type': type.name,
        'required': required,
        'validation': validation,
        'options': options,
        'default_value': defaultValue,
        'help_text': helpText,
        'order': order,
      };

  factory FormFieldDefinition.fromJson(Map<String, dynamic> json) {
    return FormFieldDefinition(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      type: FormFieldType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => FormFieldType.text,
      ),
      required: json['required'] ?? false,
      validation: Map<String, dynamic>.from(json['validation'] ?? {}),
      options: Map<String, dynamic>.from(json['options'] ?? {}),
      defaultValue: json['default_value'],
      helpText: json['help_text'],
      order: json['order'] ?? 0,
    );
  }

  FormFieldDefinition copyWith({
    String? id,
    String? name,
    String? label,
    FormFieldType? type,
    bool? required,
    Map<String, dynamic>? validation,
    Map<String, dynamic>? options,
    String? defaultValue,
    String? helpText,
    int? order,
  }) {
    return FormFieldDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      label: label ?? this.label,
      type: type ?? this.type,
      required: required ?? this.required,
      validation: validation ?? this.validation,
      options: options ?? this.options,
      defaultValue: defaultValue ?? this.defaultValue,
      helpText: helpText ?? this.helpText,
      order: order ?? this.order,
    );
  }
}

/// Form template model
class FormTemplate {
  final String id;
  final String name;
  final String description;
  final List<FormFieldDefinition> fields;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  FormTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.fields,
    DateTime? createdAt,
    this.updatedAt,
    this.isActive = true,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'fields': fields.map((f) => f.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'is_active': isActive,
      };
}

/// Dynamic form builder screen for creating and editing forms.
class FormBuilderScreen extends StatefulWidget {
  final FormTemplate? existingForm;

  const FormBuilderScreen({super.key, this.existingForm});

  @override
  State<FormBuilderScreen> createState() => _FormBuilderScreenState();
}

class _FormBuilderScreenState extends State<FormBuilderScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final List<FormFieldDefinition> _fields = [];
  String _formName = '';
  String _formDescription = '';
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingForm != null) {
      _loadExistingForm(widget.existingForm!);
    }
  }

  void _loadExistingForm(FormTemplate form) {
    setState(() {
      _formName = form.name;
      _formDescription = form.description;
      _fields.addAll(form.fields);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingForm == null
            ? 'إنشاء استمارة جديدة'
            : 'تعديل الاستمارة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.preview),
            onPressed: _previewForm,
            tooltip: 'معاينة',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveForm,
            tooltip: 'حفظ',
          ),
        ],
      ),
      body: Row(
        children: [
          // Field type palette
          if (MediaQuery.of(context).size.width > 900)
            _buildFieldPalette(),

          // Form editor
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormMetadata(),
                  const SizedBox(height: 24),
                  _buildFieldsList(),
                  const SizedBox(height: 16),
                  _buildAddFieldButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldPalette() {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'عناصر الاستمارة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: FormFieldType.values.length,
              itemBuilder: (context, index) {
                final type = FormFieldType.values[index];
                return _buildDraggableFieldType(type);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableFieldType(FormFieldType type) {
    return Draggable<FormFieldType>(
      data: type,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(type.icon, size: 18, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(type.labelAr),
            ],
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          dense: true,
          leading: Icon(type.icon, size: 20, color: Colors.grey[600]),
          title: Text(type.labelAr, style: const TextStyle(fontSize: 13)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          onTap: () => _addField(type),
        ),
      ),
    );
  }

  Widget _buildFormMetadata() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معلومات الاستمارة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _formName,
              decoration: const InputDecoration(
                labelText: 'اسم الاستمارة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              onChanged: (value) => _formName = value,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _formDescription,
              decoration: const InputDecoration(
                labelText: 'وصف الاستمارة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 3,
              onChanged: (value) => _formDescription = value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldsList() {
    if (_fields.isEmpty) {
      return DragTarget<FormFieldType>(
        builder: (context, candidateData, rejectedData) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(
                color: candidateData.isNotEmpty
                    ? Theme.of(context).primaryColor
                    : Colors.grey[300]!,
                style: BorderStyle.solid,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
              color: candidateData.isNotEmpty
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
                  : null,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'اسحب العناصر هنا أو اضغط + لإضافة حقل',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        },
        onAccept: (type) => _addField(type),
      );
    }

    return DragTarget<FormFieldType>(
      builder: (context, candidateData, rejectedData) {
        return ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _fields.length,
          onReorder: _reorderFields,
          itemBuilder: (context, index) {
            return _buildFieldCard(_fields[index], index);
          },
        );
      },
      onAccept: (type) => _addField(type),
    );
  }

  Widget _buildFieldCard(FormFieldDefinition field, int index) {
    return Card(
      key: ValueKey(field.id),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.drag_handle, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(field.type.icon,
                  size: 18, color: Theme.of(context).primaryColor),
            ),
          ],
        ),
        title: Text(
          field.label.isEmpty ? field.type.labelAr : field.label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${field.type.labelAr}${field.required ? ' • مطلوب' : ''}',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (field.required)
              const Icon(Icons.star, size: 16, color: Colors.amber),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _editField(index),
            ),
            IconButton(
              icon: Icon(Icons.delete, size: 18, color: Colors.red[300]),
              onPressed: () => _removeField(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFieldButton() {
    return OutlinedButton.icon(
      onPressed: _showAddFieldDialog,
      icon: const Icon(Icons.add),
      label: const Text('إضافة حقل جديد'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _addField(FormFieldType type) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _fields.add(FormFieldDefinition(
        id: id,
        name: 'field_$id',
        label: '',
        type: type,
        order: _fields.length,
      ));
    });
    _editField(_fields.length - 1);
  }

  void _editField(int index) {
    // Show field editing dialog
    showDialog(
      context: context,
      builder: (context) => _FieldEditDialog(
        field: _fields[index],
        onSave: (updated) {
          setState(() => _fields[index] = updated);
        },
      ),
    );
  }

  void _removeField(int index) {
    setState(() => _fields.removeAt(index));
  }

  void _reorderFields(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _fields.removeAt(oldIndex);
      _fields.insert(newIndex, item);
    });
  }

  void _showAddFieldDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختر نوع الحقل',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FormFieldType.values.map((type) {
                return ActionChip(
                  avatar: Icon(type.icon, size: 18),
                  label: Text(type.labelAr),
                  onPressed: () {
                    Navigator.pop(context);
                    _addField(type);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _previewForm() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formName.isEmpty ? 'استمارة بدون اسم' : _formName,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              if (_formDescription.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_formDescription, style: TextStyle(color: Colors.grey[600])),
              ],
              const Divider(),
              const SizedBox(height: 16),
              Text('${_fields.length} حقل'),
              const SizedBox(height: 16),
              ..._fields.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(f.type.icon, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(f.label.isEmpty ? f.type.labelAr : f.label),
                        if (f.required)
                          const Text(' *', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveForm() {
    if (_formName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم الاستمارة')),
      );
      return;
    }

    final template = FormTemplate(
      id: widget.existingForm?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _formName,
      description: _formDescription,
      fields: _fields,
    );

    // TODO: Save to Supabase
    if (kDebugMode) print('Saving form: ${template.toJson()}');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الاستمارة بنجاح')),
    );
  }
}

/// Dialog for editing a single field
class _FieldEditDialog extends StatefulWidget {
  final FormFieldDefinition field;
  final Function(FormFieldDefinition) onSave;

  const _FieldEditDialog({required this.field, required this.onSave});

  @override
  State<_FieldEditDialog> createState() => _FieldEditDialogState();
}

class _FieldEditDialogState extends State<_FieldEditDialog> {
  late TextEditingController _labelController;
  late TextEditingController _nameController;
  late TextEditingController _helpController;
  late bool _required;
  final List<String> _options = [];

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.field.label);
    _nameController = TextEditingController(text: widget.field.name);
    _helpController = TextEditingController(text: widget.field.helpText ?? '');
    _required = widget.field.required;
    final opts = widget.field.options['items'];
    if (opts is List) _options.addAll(opts.cast<String>());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(widget.field.type.icon, size: 22),
          const SizedBox(width: 8),
          Text('تعديل: ${widget.field.type.labelAr}'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'التسمية',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الحقل (بالإنجليزية)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _helpController,
                decoration: const InputDecoration(
                  labelText: 'نص المساعدة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('حقل مطلوب'),
                value: _required,
                onChanged: (v) => setState(() => _required = v),
              ),
              // Options for dropdown/radio/checkbox
              if (widget.field.type == FormFieldType.dropdown ||
                  widget.field.type == FormFieldType.radio ||
                  widget.field.type == FormFieldType.multiSelect) ...[
                const Divider(),
                const Text('الخيارات:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._options.asMap().entries.map((e) => ListTile(
                      dense: true,
                      title: Text(e.value),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, size: 18),
                        onPressed: () =>
                            setState(() => _options.removeAt(e.key)),
                      ),
                    )),
                TextButton.icon(
                  onPressed: () {
                    final controller = TextEditingController();
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('إضافة خيار'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: 'أدخل الخيار',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('إلغاء'),
                          ),
                          FilledButton(
                            onPressed: () {
                              if (controller.text.isNotEmpty) {
                                setState(() => _options.add(controller.text));
                              }
                              Navigator.pop(ctx);
                            },
                            child: const Text('إضافة'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة خيار'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(widget.field.copyWith(
              label: _labelController.text,
              name: _nameController.text,
              helpText: _helpController.text.isEmpty ? null : _helpController.text,
              required: _required,
              options: _options.isNotEmpty ? {'items': _options} : {},
            ));
            Navigator.pop(context);
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _nameController.dispose();
    _helpController.dispose();
    super.dispose();
  }
}


