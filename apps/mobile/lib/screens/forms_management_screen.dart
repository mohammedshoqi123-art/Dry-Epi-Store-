import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:epi_shared/epi_shared.dart';

/// إدارة النماذج — Forms Management (Add + Edit + Toggle)
class FormsManagementScreen extends ConsumerStatefulWidget {
  const FormsManagementScreen({super.key});

  @override
  ConsumerState<FormsManagementScreen> createState() => _FormsManagementScreenState();
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
    setState(() { _isLoading = true; _error = null; });
    try {
      final client = Supabase.instance.client;
      final forms = await client.from('forms').select('*').order('created_at', ascending: false);
      _forms = (forms as List<dynamic>).cast<Map<String, dynamic>>();

      final Map<String, Map<String, int>> stats = {};
      for (final f in _forms) {
        final fid = f['id'] as String;
        final subs = await client.from('form_submissions').select('id, status').eq('form_id', fid);
        final subList = subs as List<dynamic>;
        final counts = <String, int>{'total': subList.length};
        for (final s in subList) {
          final st = s['status'] ?? 'draft';
          counts[st] = (counts[st] ?? 0) + 1;
        }
        stats[fid] = counts;
      }

      setState(() { _stats = stats; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ═══════════════════════════════════════
  // ADD FORM
  // ═══════════════════════════════════════
  Future<void> _addForm() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => const _FormEditSheet(title: 'إضافة نموذج جديد'),
    );
    if (result == null) return;

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      await client.from('forms').insert({
        'title_ar': result['title_ar'],
        'title_en': result['title_en'] ?? result['title_ar'],
        'description_ar': result['description_ar'],
        'schema': result['schema'] ?? {},
        'requires_gps': result['requires_gps'] ?? false,
        'requires_photo': result['requires_photo'] ?? false,
        'max_photos': result['max_photos'] ?? 5,
        'allowed_roles': result['allowed_roles'] ?? ['data_entry', 'district', 'governorate', 'central', 'admin'],
        'is_active': true,
        'created_by': user?.id,
      });
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إضافة النموذج ✅', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإضافة: $e', style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  // ═══════════════════════════════════════
  // EDIT FORM
  // ═══════════════════════════════════════
  Future<void> _editForm(Map<String, dynamic> form) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _FormEditSheet(title: 'تعديل النموذج', existingForm: form),
    );
    if (result == null) return;

    try {
      final client = Supabase.instance.client;
      await client.from('forms').update({
        'title_ar': result['title_ar'],
        'title_en': result['title_en'] ?? result['title_ar'],
        'description_ar': result['description_ar'],
        'requires_gps': result['requires_gps'],
        'requires_photo': result['requires_photo'],
        'max_photos': result['max_photos'],
        'version': (form['version'] as int? ?? 1) + 1,
      }).eq('id', form['id']);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث النموذج ✅', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التحديث: $e', style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  // ═══════════════════════════════════════
  // DELETE FORM
  // ═══════════════════════════════════════
  Future<void> _deleteForm(Map<String, dynamic> form) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor), SizedBox(width: 8), Text('حذف النموذج', style: TextStyle(fontFamily: 'Cairo', fontSize: 18))]),
          content: Text('هل أنت متأكد من حذف "${form['title_ar']}"؟\nسيتم حذفه نهائياً (حذف ناعم).', style: const TextStyle(fontFamily: 'Tajawal')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal'))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor), child: const Text('حذف', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white))),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      final client = Supabase.instance.client;
      await client.from('forms').update({'deleted_at': DateTime.now().toIso8601String(), 'is_active': false}).eq('id', form['id']);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف النموذج ✅', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف: $e', style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _toggleFormActive(Map<String, dynamic> form) async {
    try {
      final client = Supabase.instance.client;
      final newStatus = !(form['is_active'] as bool? ?? true);
      await client.from('forms').update({'is_active': newStatus}).eq('id', form['id']);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newStatus ? 'تم تفعيل النموذج ✅' : 'تم تعطيل النموذج ⚠️', style: const TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة النماذج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addForm,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('نموذج جديد', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // Stats summary
          if (_forms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _summaryStat('الكل', _forms.length, AppTheme.primaryColor),
                  _summaryStat('مفعل', _forms.where((f) => f['is_active'] == true).length, AppTheme.successColor),
                  _summaryStat('معطل', _forms.where((f) => f['is_active'] != true).length, AppTheme.errorColor),
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
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: EpiLoading.shimmer());
    if (_error != null) return Center(child: EpiErrorWidget(message: _error!, onRetry: _loadData));
    if (_forms.isEmpty) return Center(child: EpiEmptyState(
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
                    decoration: BoxDecoration(color: isActive ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.assignment_rounded, color: isActive ? AppTheme.primaryColor : Colors.grey, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(form['title_ar'] ?? '—', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700, color: isActive ? null : Colors.grey)),
                        if (form['description_ar'] != null)
                          Text(form['description_ar'], style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Switch(value: isActive, onChanged: (_) => _toggleFormActive(form), activeColor: AppTheme.successColor),
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
                  if (form['requires_gps'] == true) _tagChip('📍 GPS', AppTheme.infoColor),
                  if (form['requires_photo'] == true) _tagChip('📷 صورة', AppTheme.warningColor),
                  const Spacer(),
                  Text('v${form['version'] ?? 1}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppTheme.textHint)),
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _tagChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Text(label, style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: color)),
    );
  }

  void _showFormActions(Map<String, dynamic> form) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Icon(Icons.assignment_rounded, size: 48, color: AppTheme.primaryColor),
            const SizedBox(height: 8),
            Text(form['title_ar'] ?? '—', style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Divider(),
            _actionTile(Icons.edit_rounded, 'تعديل النموذج', AppTheme.primaryColor, () { Navigator.pop(ctx); _editForm(form); }),
            _actionTile(Icons.toggle_on_rounded, (form['is_active'] as bool? ?? true) ? 'تعطيل' : 'تفعيل', AppTheme.warningColor, () { Navigator.pop(ctx); _toggleFormActive(form); }),
            _actionTile(Icons.delete_forever_rounded, 'حذف النموذج', AppTheme.errorColor, () { Navigator.pop(ctx); _deleteForm(form); }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
      title: Text(title, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w500, color: color)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// FORM EDIT SHEET — Add/Edit
// ═══════════════════════════════════════════════════════════
class _FormEditSheet extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? existingForm;

  const _FormEditSheet({required this.title, this.existingForm});

  @override
  State<_FormEditSheet> createState() => _FormEditSheetState();
}

class _FormEditSheetState extends State<_FormEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleArController = TextEditingController();
  final _titleEnController = TextEditingController();
  final _descArController = TextEditingController();
  bool _requiresGps = false;
  bool _requiresPhoto = false;
  int _maxPhotos = 5;

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
    }
  }

  @override
  void dispose() {
    _titleArController.dispose();
    _titleEnController.dispose();
    _descArController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'title_ar': _titleArController.text.trim(),
      'title_en': _titleEnController.text.trim(),
      'description_ar': _descArController.text.trim(),
      'requires_gps': _requiresGps,
      'requires_photo': _requiresPhoto,
      'max_photos': _maxPhotos,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(widget.title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),

                // Title Arabic
                TextFormField(
                  controller: _titleArController,
                  decoration: _inputDecoration('العنوان (عربي)', Icons.title_rounded),
                  validator: (v) => (v == null || v.trim().length < 2) ? 'العنوان مطلوب' : null,
                  style: const TextStyle(fontFamily: 'Tajawal'),
                ),
                const SizedBox(height: 14),

                // Title English
                TextFormField(
                  controller: _titleEnController,
                  decoration: _inputDecoration('العنوان (إنجليزي)', Icons.title_rounded),
                  style: const TextStyle(fontFamily: 'Tajawal'),
                ),
                const SizedBox(height: 14),

                // Description
                TextFormField(
                  controller: _descArController,
                  maxLines: 3,
                  decoration: _inputDecoration('الوصف', Icons.description_rounded),
                  style: const TextStyle(fontFamily: 'Tajawal'),
                ),
                const SizedBox(height: 14),

                // GPS toggle
                SwitchListTile(
                  title: const Text('📍 يتطلب GPS', style: TextStyle(fontFamily: 'Tajawal')),
                  subtitle: const Text('يجب تحديد الموقع عند الإرسال', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                  value: _requiresGps,
                  onChanged: (v) => setState(() => _requiresGps = v),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                ),
                const SizedBox(height: 8),

                // Photo toggle
                SwitchListTile(
                  title: const Text('📷 يتطلب صورة', style: TextStyle(fontFamily: 'Tajawal')),
                  subtitle: Text('حد أقصى $_maxPhotos صور', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                  value: _requiresPhoto,
                  onChanged: (v) => setState(() => _requiresPhoto = v),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                ),
                const SizedBox(height: 8),

                // Max photos
                if (_requiresPhoto)
                  Row(
                    children: [
                      const Text('عدد الصور الأقصى:', style: TextStyle(fontFamily: 'Tajawal')),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: _maxPhotos,
                        items: [1, 2, 3, 5, 10].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
                        onChanged: (v) => setState(() => _maxPhotos = v ?? 5),
                      ),
                    ],
                  ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _submit,
                    icon: Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded, color: Colors.white),
                    label: Text(_isEditing ? 'حفظ التعديلات' : 'إضافة النموذج', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600, color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
