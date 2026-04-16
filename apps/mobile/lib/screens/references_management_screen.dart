import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:epi_core/epi_core.dart';
import 'package:epi_shared/epi_shared.dart';

/// إدارة المراجع والكتب — References Management (Add + Edit + Delete)
class ReferencesManagementScreen extends ConsumerStatefulWidget {
  const ReferencesManagementScreen({super.key});

  @override
  ConsumerState<ReferencesManagementScreen> createState() => _ReferencesManagementScreenState();
}

class _ReferencesManagementScreenState extends ConsumerState<ReferencesManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _references = [];
  String _searchQuery = '';

  static const _categories = {
    'manual': 'دليل إجرائي',
    'guide': 'مرشد',
    'protocol': 'بروتوكول',
    'report': 'تقرير',
    'policy': 'سياسة',
    'training': 'تدريب',
    'form': 'استمارة',
    'other': 'أخرى',
  };

  @override
  void initState() {
    super.initState();
    _loadReferences();
  }

  Future<void> _loadReferences() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final data = await client.from('doc_references').select('*').order('created_at', ascending: false);
      setState(() {
        _references = (data as List<dynamic>).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _references;
    return _references.where((r) {
      final title = (r['title_ar'] ?? '').toString().toLowerCase();
      return title.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  // ═══════════════════════════════════════
  // ADD REFERENCE
  // ═══════════════════════════════════════
  Future<void> _addReference() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => const _ReferenceFormSheet(title: 'إضافة مرجع جديد'),
    );
    if (result == null) return;

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      await client.from('doc_references').insert({
        'title_ar': result['title_ar'],
        'title_en': result['title_en'] ?? '',
        'description_ar': result['description_ar'],
        'category': result['category'],
        'file_url': result['file_url'],
        'is_active': true,
        'created_by': user?.id,
      });
      _loadReferences();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إضافة المرجع ✅', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: AppTheme.successColor),
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
  // EDIT REFERENCE
  // ═══════════════════════════════════════
  Future<void> _editReference(Map<String, dynamic> ref) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ReferenceFormSheet(title: 'تعديل المرجع', existingRef: ref),
    );
    if (result == null) return;

    try {
      final client = Supabase.instance.client;
      await client.from('doc_references').update({
        'title_ar': result['title_ar'],
        'title_en': result['title_en'] ?? '',
        'description_ar': result['description_ar'],
        'category': result['category'],
        'file_url': result['file_url'],
      }).eq('id', ref['id']);
      _loadReferences();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث المرجع ✅', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: AppTheme.successColor),
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
  // DELETE REFERENCE
  // ═══════════════════════════════════════
  Future<void> _deleteReference(Map<String, dynamic> ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor), SizedBox(width: 8), Text('حذف المرجع', style: TextStyle(fontFamily: 'Cairo', fontSize: 18))]),
          content: Text('هل أنت متأكد من حذف "${ref['title_ar']}"؟', style: const TextStyle(fontFamily: 'Tajawal')),
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
      await client.from('doc_references').update({'deleted_at': DateTime.now().toIso8601String(), 'is_active': false}).eq('id', ref['id']);
      _loadReferences();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المرجع ✅', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: AppTheme.successColor),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المراجع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadReferences)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReference,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('مرجع جديد', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث في المراجع...',
                hintStyle: const TextStyle(fontFamily: 'Tajawal'),
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [Text('${_filtered.length} مرجع', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade600))],
            ),
          ),
          const SizedBox(height: 8),
          // Content
          Expanded(child: _buildContent()),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: EpiLoading.shimmer());
    if (_filtered.isEmpty) return Center(child: EpiEmptyState(
      icon: Icons.menu_book_outlined,
      title: 'لا توجد مراجع',
      actionText: 'إعادة تحميل',
      onAction: _loadReferences,
    ));

    return RefreshIndicator(
      onRefresh: _loadReferences,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filtered.length,
        itemBuilder: (context, i) => _buildReferenceCard(_filtered[i]),
      ),
    );
  }

  Widget _buildReferenceCard(Map<String, dynamic> ref) {
    final category = ref['category'] as String? ?? 'other';
    final isActive = ref['is_active'] as bool? ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showRefActions(ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: isActive ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                child: Icon(_getCategoryIcon(category), color: isActive ? AppTheme.primaryColor : Colors.grey, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ref['title_ar'] ?? '—', style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700, color: isActive ? null : Colors.grey)),
                    if (ref['description_ar'] != null)
                      Text(ref['description_ar'], style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                          child: Text(_categories[category] ?? category, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.primaryColor)),
                        ),
                        if (ref['file_url'] != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.attach_file_rounded, size: 16, color: AppTheme.textHint),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.more_vert_rounded, color: AppTheme.textHint),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'manual': return Icons.menu_book_rounded;
      case 'guide': return Icons.description_rounded;
      case 'protocol': return Icons.science_rounded;
      case 'report': return Icons.assessment_rounded;
      case 'policy': return Icons.gavel_rounded;
      case 'training': return Icons.school_rounded;
      case 'form': return Icons.assignment_rounded;
      default: return Icons.folder_rounded;
    }
  }

  void _showRefActions(Map<String, dynamic> ref) {
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
            Icon(_getCategoryIcon(ref['category'] ?? 'other'), size: 48, color: AppTheme.primaryColor),
            const SizedBox(height: 8),
            Text(ref['title_ar'] ?? '—', style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Divider(),
            _actionTile(Icons.edit_rounded, 'تعديل', AppTheme.primaryColor, () { Navigator.pop(ctx); _editReference(ref); }),
            _actionTile(Icons.delete_forever_rounded, 'حذف', AppTheme.errorColor, () { Navigator.pop(ctx); _deleteReference(ref); }),
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
// REFERENCE FORM SHEET
// ═══════════════════════════════════════════════════════════
class _ReferenceFormSheet extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? existingRef;

  const _ReferenceFormSheet({required this.title, this.existingRef});

  @override
  State<_ReferenceFormSheet> createState() => _ReferenceFormSheetState();
}

class _ReferenceFormSheetState extends State<_ReferenceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleArController = TextEditingController();
  final _titleEnController = TextEditingController();
  final _descController = TextEditingController();
  final _fileUrlController = TextEditingController();
  String _selectedCategory = 'manual';

  bool get _isEditing => widget.existingRef != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final r = widget.existingRef!;
      _titleArController.text = r['title_ar'] ?? '';
      _titleEnController.text = r['title_en'] ?? '';
      _descController.text = r['description_ar'] ?? '';
      _fileUrlController.text = r['file_url'] ?? '';
      _selectedCategory = r['category'] ?? 'manual';
    }
  }

  @override
  void dispose() {
    _titleArController.dispose();
    _titleEnController.dispose();
    _descController.dispose();
    _fileUrlController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'title_ar': _titleArController.text.trim(),
      'title_en': _titleEnController.text.trim(),
      'description_ar': _descController.text.trim(),
      'category': _selectedCategory,
      'file_url': _fileUrlController.text.trim().isNotEmpty ? _fileUrlController.text.trim() : null,
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

                TextFormField(
                  controller: _titleArController,
                  decoration: _inputDecoration('العنوان (عربي) *', Icons.title_rounded),
                  validator: (v) => (v == null || v.trim().length < 2) ? 'العنوان مطلوب' : null,
                  style: const TextStyle(fontFamily: 'Tajawal'),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _titleEnController,
                  decoration: _inputDecoration('العنوان (إنجليزي)', Icons.title_rounded),
                  style: const TextStyle(fontFamily: 'Tajawal'),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: _inputDecoration('الوصف', Icons.description_rounded),
                  style: const TextStyle(fontFamily: 'Tajawal'),
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: _inputDecoration('التصنيف', Icons.category_rounded),
                  items: _ReferencesManagementScreenState._categories.entries.map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontFamily: 'Tajawal')))
                  ).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v ?? 'manual'),
                  style: const TextStyle(fontFamily: 'Tajawal', color: Colors.black87),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _fileUrlController,
                  decoration: _inputDecoration('رابط الملف (اختياري)', Icons.link_rounded),
                  style: const TextStyle(fontFamily: 'Tajawal'),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _submit,
                    icon: Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded, color: Colors.white),
                    label: Text(_isEditing ? 'حفظ التعديلات' : 'إضافة المرجع', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600, color: Colors.white)),
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
    return InputDecoration(labelText: label, prefixIcon: Icon(icon), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14));
  }
}
