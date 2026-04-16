import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:epi_shared/epi_shared.dart';

/// إدارة النماذج — Forms Management (Add + Full Edit + Schema Editor + Toggle)
class FormsManagementScreen extends ConsumerStatefulWidget {
  const FormsManagementScreen({super.key});

  @override
  ConsumerState<FormsManagementScreen> createState() =>
      _FormsManagementScreenState();
}

class _FormsManagementScreenState extends ConsumerState<FormsManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _forms = [];
  Map<String, Map<String, int>> _stats = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final forms = await client
          .from('forms')
          .select('*')
          .order('created_at', ascending: false);
      _forms = (forms as List<dynamic>).cast<Map<String, dynamic>>();

      final Map<String, Map<String, int>> stats = {};
      for (final f in _forms) {
        final fid = f['id'] as String;
        final subs = await client
            .from('form_submissions')
            .select('id, status')
            .eq('form_id', fid);
        final subList = subs as List<dynamic>;
        final counts = <String, int>{'total': subList.length};
        for (final s in subList) {
          final st = s['status'] ?? 'draft';
          counts[st] = (counts[st] ?? 0) + 1;
        }
        stats[fid] = counts;
      }

      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addForm() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (ctx) => const FormEditorScreen()),
    );
    if (result == null) return;

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      await client.from('forms').insert({
        'title_ar': result['title_ar'],
        'title_en': result['title_en'] ?? result['title_ar'],
        'description_ar': result['description_ar'],
        'schema': result['schema'] ?? {'fields': [], 'sections': []},
        'requires_gps': result['requires_gps'] ?? false,
        'requires_photo': result['requires_photo'] ?? false,
        'max_photos': result['max_photos'] ?? 5,
        'allowed_roles': result['allowed_roles'] ??
            ['data_entry', 'district', 'governorate', 'central', 'admin'],
        'is_active': true,
        'created_by': user?.id,
      });
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إضافة النموذج ✅',
                  style: TextStyle(fontFamily: 'Tajawal')),
              backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('فشل الإضافة: $e',
                  style: const TextStyle(fontFamily: 'Tajawal')),
              backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _editForm(Map<String, dynamic> form) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (ctx) => FormEditorScreen(existingForm: form)),
    );
    if (result == null) return;

    try {
      final client = Supabase.instance.client;
      await client.from('forms').update({
        'title_ar': result['title_ar'],
        'title_en': result['title_en'] ?? result['title_ar'],
        'description_ar': result['description_ar'],
        'schema': result['schema'],
        'requires_gps': result['requires_gps'],
        'requires_photo': result['requires_photo'],
        'max_photos': result['max_photos'],
        'version': (form['version'] as int? ?? 1) + 1,
      }).eq('id', form['id']);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم تحديث النموذج ✅',
                  style: TextStyle(fontFamily: 'Tajawal')),
              backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('فشل التحديث: $e',
                  style: const TextStyle(fontFamily: 'Tajawal')),
              backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _deleteForm(Map<String, dynamic> form) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('حذف النموذج',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 18))
          ]),
          content: Text('هل أنت متأكد من حذف "${form['title_ar']}"؟',
              style: const TextStyle(fontFamily: 'Tajawal')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء',
                    style: TextStyle(fontFamily: 'Tajawal'))),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor),
                child: const Text('حذف',
                    style:
                        TextStyle(fontFamily: 'Tajawal', color: Colors.white))),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      final client = Supabase.instance.client;
      await client.from('forms').update({
        'deleted_at': DateTime.now().toIso8601String(),
        'is_active': false
      }).eq('id', form['id']);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حذف النموذج ✅',
                  style: TextStyle(fontFamily: 'Tajawal')),
              backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('فشل الحذف: $e',
                  style: const TextStyle(fontFamily: 'Tajawal')),
              backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _toggleFormActive(Map<String, dynamic> form) async {
    try {
      final client = Supabase.instance.client;
      final newStatus = !(form['is_active'] as bool? ?? true);
      await client
          .from('forms')
          .update({'is_active': newStatus}).eq('id', form['id']);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  newStatus ? 'تم تفعيل النموذج ✅' : 'تم تعطيل النموذج ⚠️',
                  style: const TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ: $e',
                  style: const TextStyle(fontFamily: 'Tajawal')),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة النماذج',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _loadData)
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addForm,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('نموذج جديد',
            style: TextStyle(
                fontFamily: 'Tajawal',
                color: Colors.white,
                fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          if (_forms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _summaryStat('الكل', _forms.length, AppTheme.primaryColor),
                  _summaryStat(
                      'مفعل',
                      _forms.where((f) => f['is_active'] == true).length,
                      AppTheme.successColor),
                  _summaryStat(
                      'معطل',
                      _forms.where((f) => f['is_active'] != true).length,
                      AppTheme.errorColor),
                ],
              ),
            ),
          Expanded(child: _buildContent()),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, int count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text('$count',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color)),
          Text(label,
              style:
                  TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: color)),
        ]),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: EpiLoading.shimmer());
    if (_error != null)
      return Center(
          child: EpiErrorWidget(message: _error!, onRetry: _loadData));
    if (_forms.isEmpty)
      return Center(
          child: EpiEmptyState(
        icon: Icons.description_outlined,
        title: 'لا توجد نماذج',
        subtitle: 'اضغط على "نموذج جديد" للبدء',
        actionText: 'إعادة تحميل',
        onAction: _loadData,
      ));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _forms.length,
        itemBuilder: (context, i) => _buildFormCard(_forms[i]),
      ),
    );
  }

  Widget _buildFormCard(Map<String, dynamic> form) {
    final isActive = form['is_active'] as bool? ?? true;
    final fid = form['id'] as String;
    final stats = _stats[fid] ?? {};
    final total = stats['total'] ?? 0;
    final approved = stats['approved'] ?? 0;
    final submitted = stats['submitted'] ?? 0;
    final schema = form['schema'] as Map<String, dynamic>? ?? {};
    final fields = schema['fields'] as List? ?? [];
    final sections = schema['sections'] as List? ?? [];
    final totalFields = sections.isNotEmpty
        ? sections.fold<int>(
            0, (sum, s) => sum + ((s['fields'] as List?)?.length ?? 0))
        : fields.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showFormActions(form),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.primaryColor.withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.assignment_rounded,
                        color: isActive ? AppTheme.primaryColor : Colors.grey,
                        size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(form['title_ar'] ?? '—',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isActive ? null : Colors.grey)),
                        if (form['description_ar'] != null)
                          Text(form['description_ar'],
                              style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 12,
                                  color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Switch(
                      value: isActive,
                      onChanged: (_) => _toggleFormActive(form),
                      activeColor: AppTheme.successColor),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _statChip('$total إرسالية', AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  _statChip('$submitted معلق', AppTheme.warningColor),
                  const SizedBox(width: 8),
                  _statChip('$approved معتمد', AppTheme.successColor),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _statChip('$totalFields حقل', Colors.indigo),
                  const SizedBox(width: 8),
                  if (sections.isNotEmpty)
                    _statChip('${sections.length} أقسام', Colors.teal),
                  const SizedBox(width: 8),
                  if (form['requires_gps'] == true)
                    _tagChip('📍 GPS', AppTheme.infoColor),
                  if (form['requires_photo'] == true)
                    _tagChip('📷 صورة', AppTheme.warningColor),
                  const Spacer(),
                  Text('v${form['version'] ?? 1}',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AppTheme.textHint)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _tagChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Text(label,
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: color)),
    );
  }

  void _showFormActions(Map<String, dynamic> form) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Icon(Icons.assignment_rounded,
                size: 48, color: AppTheme.primaryColor),
            const SizedBox(height: 8),
            Text(form['title_ar'] ?? '—',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Divider(),
            _actionTile(
                Icons.edit_rounded,
                'تعديل شامل (حقول + عناوين + إعدادات)',
                AppTheme.primaryColor, () {
              Navigator.pop(ctx);
              _editForm(form);
            }),
            _actionTile(
                Icons.toggle_on_rounded,
                (form['is_active'] as bool? ?? true) ? 'تعطيل' : 'تفعيل',
                AppTheme.warningColor, () {
              Navigator.pop(ctx);
              _toggleFormActive(form);
            }),
            _actionTile(Icons.delete_forever_rounded, 'حذف النموذج',
                AppTheme.errorColor, () {
              Navigator.pop(ctx);
              _deleteForm(form);
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(
      IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22)),
      title: Text(title,
          style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w500,
              color: color)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FULL FORM EDITOR SCREEN — Schema Editor + Fields + Sections + Settings
// ═══════════════════════════════════════════════════════════════════════════════
class FormEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? existingForm;
  const FormEditorScreen({super.key, this.existingForm});

  @override
  State<FormEditorScreen> createState() => _FormEditorScreenState();
}

class _FormEditorScreenState extends State<FormEditorScreen> {
  final _titleArController = TextEditingController();
  final _titleEnController = TextEditingController();
  final _descArController = TextEditingController();
  bool _requiresGps = false;
  bool _requiresPhoto = false;
  int _maxPhotos = 5;

  // Schema: flat fields OR sections
  List<Map<String, dynamic>> _fields = [];
  List<Map<String, dynamic>> _sections = [];
  bool _useSections = false;

  // Field type definitions
  static const _fieldTypes = {
    'text': {
      'label': 'نص',
      'icon': Icons.text_fields_rounded,
      'color': Colors.blue
    },
    'number': {
      'label': 'رقم',
      'icon': Icons.numbers_rounded,
      'color': Colors.indigo
    },
    'phone': {
      'label': 'جوال',
      'icon': Icons.phone_rounded,
      'color': Colors.green
    },
    'textarea': {
      'label': 'نص طويل',
      'icon': Icons.notes_rounded,
      'color': Colors.teal
    },
    'select': {
      'label': 'قائمة اختيار',
      'icon': Icons.arrow_drop_down_circle_rounded,
      'color': Colors.purple
    },
    'multiselect': {
      'label': 'اختيار متعدد',
      'icon': Icons.checklist_rounded,
      'color': Colors.deepPurple
    },
    'yesno': {
      'label': 'نعم / لا',
      'icon': Icons.toggle_on_rounded,
      'color': Colors.orange
    },
    'date': {
      'label': 'تاريخ',
      'icon': Icons.calendar_today_rounded,
      'color': Colors.cyan
    },
    'gps': {
      'label': 'موقع GPS',
      'icon': Icons.location_on_rounded,
      'color': Colors.red
    },
    'photo': {
      'label': 'صورة',
      'icon': Icons.camera_alt_rounded,
      'color': Colors.amber
    },
  };

  bool get _isEditing => widget.existingForm != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final f = widget.existingForm!;
      _titleArController.text = f['title_ar'] ?? '';
      _titleEnController.text = f['title_en'] ?? '';
      _descArController.text = f['description_ar'] ?? '';
      _requiresGps = f['requires_gps'] ?? false;
      _requiresPhoto = f['requires_photo'] ?? false;
      _maxPhotos = f['max_photos'] ?? 5;

      final schema = f['schema'] as Map<String, dynamic>? ?? {};
      final sections = schema['sections'] as List? ?? [];
      final flatFields = schema['fields'] as List? ?? [];

      if (sections.isNotEmpty) {
        _useSections = true;
        _sections =
            sections.map((s) => Map<String, dynamic>.from(s as Map)).toList();
      } else {
        _useSections = false;
        _fields =
            flatFields.map((f) => Map<String, dynamic>.from(f as Map)).toList();
      }
    }
  }

  @override
  void dispose() {
    _titleArController.dispose();
    _titleEnController.dispose();
    _descArController.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleArController.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('العنوان مطلوب', style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.errorColor),
      );
      return;
    }

    final schema = _useSections
        ? {
            'sections': _sections
                .map((s) => Map<String, dynamic>.from(s)..remove('expanded'))
                .toList()
          }
        : {'fields': _fields};

    Navigator.pop(context, {
      'title_ar': _titleArController.text.trim(),
      'title_en': _titleEnController.text.trim(),
      'description_ar': _descArController.text.trim(),
      'schema': schema,
      'requires_gps': _requiresGps,
      'requires_photo': _requiresPhoto,
      'max_photos': _maxPhotos,
    });
  }

  // ═══════════════════════════════════════
  // FIELD OPERATIONS
  // ═══════════════════════════════════════

  void _addField({int? sectionIndex}) {
    _showFieldEditor(null, sectionIndex: sectionIndex);
  }

  void _editField(int fieldIndex, {int? sectionIndex}) {
    _showFieldEditor(fieldIndex, sectionIndex: sectionIndex);
  }

  void _deleteField(int fieldIndex, {int? sectionIndex}) {
    setState(() {
      if (sectionIndex != null) {
        final fields = (_sections[sectionIndex]['fields'] as List)
            .cast<Map<String, dynamic>>();
        fields.removeAt(fieldIndex);
      } else {
        _fields.removeAt(fieldIndex);
      }
    });
  }

  void _moveField(int oldIndex, int newIndex, {int? sectionIndex}) {
    setState(() {
      if (sectionIndex != null) {
        final fields = (_sections[sectionIndex]['fields'] as List)
            .cast<Map<String, dynamic>>();
        if (newIndex > oldIndex) newIndex--;
        final item = fields.removeAt(oldIndex);
        fields.insert(newIndex, item);
      } else {
        if (newIndex > oldIndex) newIndex--;
        final item = _fields.removeAt(oldIndex);
        _fields.insert(newIndex, item);
      }
    });
  }

  void _showFieldEditor(int? fieldIndex, {int? sectionIndex}) {
    final isEdit = fieldIndex != null;
    Map<String, dynamic>? existingField;
    if (isEdit) {
      if (sectionIndex != null) {
        existingField = (_sections[sectionIndex]['fields'] as List)[fieldIndex]
            as Map<String, dynamic>;
      } else {
        existingField = _fields[fieldIndex];
      }
    }

    final keyController =
        TextEditingController(text: existingField?['key'] ?? '');
    final labelController =
        TextEditingController(text: existingField?['label_ar'] ?? '');
    final hintController =
        TextEditingController(text: existingField?['hint'] ?? '');
    String selectedType = existingField?['type'] ?? 'text';
    bool isRequired = existingField?['required'] ?? false;
    final List<String> options =
        List<String>.from(existingField?['options'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text(isEdit ? 'تعديل الحقل' : 'إضافة حقل جديد',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),

                  // Field Key
                  TextField(
                    controller: keyController,
                    decoration: const InputDecoration(
                        labelText: 'مفتاح الحقل (بالإنجليزي)',
                        prefixIcon: Icon(Icons.vpn_key_rounded),
                        border: OutlineInputBorder(),
                        helperText: 'مثال: patient_name'),
                    style: const TextStyle(fontFamily: 'Tajawal'),
                  ),
                  const SizedBox(height: 14),

                  // Label Arabic
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(
                        labelText: 'التسمية (عربي)',
                        prefixIcon: Icon(Icons.label_rounded),
                        border: OutlineInputBorder()),
                    style: const TextStyle(fontFamily: 'Tajawal'),
                  ),
                  const SizedBox(height: 14),

                  // Hint
                  TextField(
                    controller: hintController,
                    decoration: const InputDecoration(
                        labelText: 'نص المساعدة (اختياري)',
                        prefixIcon: Icon(Icons.help_outline_rounded),
                        border: OutlineInputBorder()),
                    style: const TextStyle(fontFamily: 'Tajawal'),
                  ),
                  const SizedBox(height: 14),

                  // Type selector
                  const Text('نوع الحقل:',
                      style: TextStyle(
                          fontFamily: 'Tajawal', fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _fieldTypes.entries.map((e) {
                      final isSelected = selectedType == e.key;
                      final info = e.value;
                      return InkWell(
                        onTap: () => setModalState(() => selectedType = e.key),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (info['color'] as Color)
                                    .withValues(alpha: 0.15)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isSelected
                                    ? info['color'] as Color
                                    : Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(info['icon'] as IconData,
                                  size: 18,
                                  color: isSelected
                                      ? info['color'] as Color
                                      : Colors.grey),
                              const SizedBox(width: 6),
                              Text(info['label'] as String,
                                  style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 13,
                                      color: isSelected
                                          ? info['color'] as Color
                                          : Colors.grey.shade700,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Required toggle
                  SwitchListTile(
                    title: const Text('حقل مطلوب',
                        style: TextStyle(fontFamily: 'Tajawal')),
                    subtitle: const Text('يجب ملء هذا الحقل عند الإرسال',
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                    value: isRequired,
                    onChanged: (v) => setModalState(() => isRequired = v),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300)),
                  ),
                  const SizedBox(height: 8),

                  // Options (for select/multiselect)
                  if (selectedType == 'select' ||
                      selectedType == 'multiselect') ...[
                    const Text('الخيارات:',
                        style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...options.asMap().entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller:
                                      TextEditingController(text: entry.value),
                                  decoration: InputDecoration(
                                      labelText: 'خيار ${entry.key + 1}',
                                      border: const OutlineInputBorder(),
                                      isDense: true),
                                  style: const TextStyle(fontFamily: 'Tajawal'),
                                  onChanged: (v) => options[entry.key] = v,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: AppTheme.errorColor),
                                onPressed: () => setModalState(
                                    () => options.removeAt(entry.key)),
                              ),
                            ],
                          ),
                        )),
                    OutlinedButton.icon(
                      onPressed: () => setModalState(() => options.add('')),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('إضافة خيار',
                          style: TextStyle(fontFamily: 'Tajawal')),
                    ),
                    const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (keyController.text.trim().isEmpty ||
                            labelController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('المفتاح والتسمية مطلوبان',
                                    style: TextStyle(fontFamily: 'Tajawal')),
                                backgroundColor: AppTheme.errorColor),
                          );
                          return;
                        }

                        final field = <String, dynamic>{
                          'key': keyController.text.trim(),
                          'type': selectedType,
                          'label_ar': labelController.text.trim(),
                          'required': isRequired,
                        };
                        if (hintController.text.trim().isNotEmpty)
                          field['hint'] = hintController.text.trim();
                        if (selectedType == 'select' ||
                            selectedType == 'multiselect') {
                          field['options'] = options
                              .where((o) => o.trim().isNotEmpty)
                              .toList();
                        }

                        setState(() {
                          if (sectionIndex != null) {
                            final fields =
                                (_sections[sectionIndex]['fields'] as List)
                                    .cast<Map<String, dynamic>>();
                            if (isEdit) {
                              fields[fieldIndex!] = field;
                            } else {
                              fields.add(field);
                            }
                          } else {
                            if (isEdit) {
                              _fields[fieldIndex!] = field;
                            } else {
                              _fields.add(field);
                            }
                          }
                        });
                        Navigator.pop(ctx);
                      },
                      icon: Icon(
                          isEdit ? Icons.save_rounded : Icons.add_rounded,
                          color: Colors.white),
                      label: Text(isEdit ? 'حفظ التعديل' : 'إضافة الحقل',
                          style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // SECTION OPERATIONS
  // ═══════════════════════════════════════

  void _addSection() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('قسم جديد', style: TextStyle(fontFamily: 'Cairo')),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
                labelText: 'عنوان القسم', border: OutlineInputBorder()),
            style: const TextStyle(fontFamily: 'Tajawal'),
            autofocus: true,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(fontFamily: 'Tajawal'))),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _sections.add({
                      'title': controller.text.trim(),
                      'fields': <Map<String, dynamic>>[],
                      'expanded': true,
                    });
                  });
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor),
              child: const Text('إضافة',
                  style: TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _editSectionTitle(int index) {
    final controller =
        TextEditingController(text: _sections[index]['title'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تعديل عنوان القسم',
              style: TextStyle(fontFamily: 'Cairo')),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
                labelText: 'عنوان القسم', border: OutlineInputBorder()),
            style: const TextStyle(fontFamily: 'Tajawal'),
            autofocus: true,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(fontFamily: 'Tajawal'))),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _sections[index]['title'] = controller.text.trim();
                  });
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor),
              child: const Text('حفظ',
                  style: TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteSection(int index) {
    setState(() {
      _sections.removeAt(index);
    });
  }

  // ═══════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل النموذج' : 'نموذج جديد',
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded, color: AppTheme.primaryColor),
            label: const Text('حفظ',
                style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══ Basic Info ═══
            _sectionTitle('📋 المعلومات الأساسية'),
            const SizedBox(height: 12),
            TextField(
              controller: _titleArController,
              decoration: const InputDecoration(
                  labelText: 'العنوان (عربي) *',
                  prefixIcon: Icon(Icons.title_rounded),
                  border: OutlineInputBorder()),
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleEnController,
              decoration: const InputDecoration(
                  labelText: 'العنوان (إنجليزي)',
                  prefixIcon: Icon(Icons.title_rounded),
                  border: OutlineInputBorder()),
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descArController,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'الوصف',
                  prefixIcon: Icon(Icons.description_rounded),
                  border: OutlineInputBorder()),
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
            const SizedBox(height: 16),

            // ═══ Settings ═══
            _sectionTitle('⚙️ الإعدادات'),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('📍 يتطلب GPS',
                  style: TextStyle(fontFamily: 'Tajawal')),
              value: _requiresGps,
              onChanged: (v) => setState(() => _requiresGps = v),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300)),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              title: const Text('📷 يتطلب صورة',
                  style: TextStyle(fontFamily: 'Tajawal')),
              subtitle: _requiresPhoto
                  ? Text('حد أقصى $_maxPhotos صور',
                      style:
                          const TextStyle(fontFamily: 'Tajawal', fontSize: 12))
                  : null,
              value: _requiresPhoto,
              onChanged: (v) => setState(() => _requiresPhoto = v),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300)),
            ),
            if (_requiresPhoto) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('عدد الصور الأقصى:',
                      style: TextStyle(fontFamily: 'Tajawal')),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _maxPhotos,
                    items: [1, 2, 3, 5, 10]
                        .map((n) =>
                            DropdownMenuItem(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (v) => setState(() => _maxPhotos = v ?? 5),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // ═══ Schema Structure Toggle ═══
            _sectionTitle('🏗️ هيكل الحقول'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _useSections = false),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_useSections
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('حقول مباشرة',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.w600,
                                color: !_useSections
                                    ? Colors.white
                                    : Colors.grey)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _useSections = true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _useSections
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(' مقسم بأقسام',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.w600,
                                color:
                                    _useSections ? Colors.white : Colors.grey)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ═══ Fields / Sections Editor ═══
            if (!_useSections) ...[
              _sectionTitle('📝 الحقول (${_fields.length})'),
              const SizedBox(height: 8),
              _buildFieldsList(_fields),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _addField(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة حقل',
                    style: TextStyle(fontFamily: 'Tajawal')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ] else ...[
              _sectionTitle('📂 الأقسام (${_sections.length})'),
              const SizedBox(height: 8),
              ..._sections
                  .asMap()
                  .entries
                  .map((entry) => _buildSectionCard(entry.key, entry.value)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _addSection,
                icon: const Icon(Icons.create_new_folder_rounded),
                label: const Text('إضافة قسم',
                    style: TextStyle(fontFamily: 'Tajawal')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildFieldsList(List<Map<String, dynamic>> fields,
      {int? sectionIndex}) {
    if (fields.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: AppTheme.textHint),
            SizedBox(height: 8),
            Text('لا توجد حقول بعد',
                style:
                    TextStyle(fontFamily: 'Tajawal', color: AppTheme.textHint)),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: fields.length,
      onReorder: (oldIndex, newIndex) =>
          _moveField(oldIndex, newIndex, sectionIndex: sectionIndex),
      itemBuilder: (context, i) =>
          _buildFieldTile(fields[i], i, sectionIndex: sectionIndex),
    );
  }

  Widget _buildFieldTile(Map<String, dynamic> field, int index,
      {int? sectionIndex}) {
    final type = field['type'] as String? ?? 'text';
    final typeInfo = _fieldTypes[type] ?? _fieldTypes['text']!;
    final isRequired = field['required'] == true;
    final options = field['options'] as List?;

    return Card(
      key: ValueKey('field_$index'),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (typeInfo['color'] as Color).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(typeInfo['icon'] as IconData,
              color: typeInfo['color'] as Color, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(field['label_ar'] ?? field['key'] ?? '—',
                  style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ),
            if (isRequired)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('مطلوب',
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10,
                        color: AppTheme.errorColor)),
              ),
          ],
        ),
        subtitle: Text(
          '${typeInfo['label']}${options != null ? ' (${options.length} خيارات)' : ''}${field['key'] != null ? ' — ${field['key']}' : ''}',
          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded,
                  size: 20, color: AppTheme.primaryColor),
              onPressed: () => _editField(index, sectionIndex: sectionIndex),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 20, color: AppTheme.errorColor),
              onPressed: () => _deleteField(index, sectionIndex: sectionIndex),
            ),
            const Icon(Icons.drag_handle_rounded, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(int sectionIndex, Map<String, dynamic> section) {
    final isExpanded = section['expanded'] == true;
    final fields =
        (section['fields'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(
                top: const Radius.circular(16),
                bottom: isExpanded ? Radius.zero : const Radius.circular(16)),
            onTap: () => setState(
                () => _sections[sectionIndex]['expanded'] = !isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.folder_rounded,
                        color: Colors.teal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(section['title'] ?? '—',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        Text('${fields.length} حقل',
                            style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.edit_rounded,
                          size: 20, color: AppTheme.primaryColor),
                      onPressed: () => _editSectionTitle(sectionIndex)),
                  IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 20, color: AppTheme.errorColor),
                      onPressed: () => _deleteSection(sectionIndex)),
                  Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppTheme.textHint),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildFieldsList(fields, sectionIndex: sectionIndex),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _addField(sectionIndex: sectionIndex),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('إضافة حقل لهذا القسم',
                        style: TextStyle(fontFamily: 'Tajawal')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal),
                      minimumSize: const Size(double.infinity, 40),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
