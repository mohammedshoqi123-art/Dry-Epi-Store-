import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:dry_shared/dry_shared.dart';

// ══════════════════════════════════════════════════════════════════════════════
// إدارة المراجع والكتب — References Management Screen
// كتب، أدلة، مراجع التطعيم
// ══════════════════════════════════════════════════════════════════════════════

final referencesListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  try {
    final response = await client
        .from('doc_references')
        .select('*')
        .order('created_at', ascending: false);
    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
});

class ReferencesManagementScreen extends ConsumerStatefulWidget {
  const ReferencesManagementScreen({super.key});

  @override
  ConsumerState<ReferencesManagementScreen> createState() =>
      _ReferencesManagementScreenState();
}

class _ReferencesManagementScreenState
    extends ConsumerState<ReferencesManagementScreen> {
  String _searchQuery = '';
  String? _selectedCategory;

  static const categories = {
    'manual': 'دليل إجرائي',
    'guide': 'مرشد',
    'protocol': 'بروتوكول',
    'report': 'تقرير',
    'policy': 'سياسة',
    'training': 'تدريب',
    'other': 'أخرى',
  };

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          title: const Text('إدارة المراجع',
              style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _showReferenceDialog(),
              tooltip: 'إضافة مرجع',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildFilters(),
            Expanded(child: _buildReferencesList(isWide)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          // Search
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'بحث في المراجع...',
                prefixIcon:
                    const Icon(Icons.search, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.backgroundLight,
                border: OutlineInputBorder(
                  borderRadius: AppTheme.radiusMedium,
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Category filter
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String?>(
              value: _selectedCategory,
              onChanged: (v) => setState(() => _selectedCategory = v),
              decoration: InputDecoration(
                hintText: 'التصنيف',
                filled: true,
                fillColor: AppTheme.backgroundLight,
                border: OutlineInputBorder(
                  borderRadius: AppTheme.radiusMedium,
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('كل التصنيفات')),
                ...categories.entries.map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferencesList(bool isWide) {
    return Consumer(
      builder: (context, ref, _) {
        final refsAsync = ref.watch(referencesListProvider);

        return refsAsync.when(
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 5,
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: AppTheme.radiusMedium,
                ),
              ),
            ),
          ),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppTheme.errorColor),
                const SizedBox(height: 16),
                const Text('فشل تحميل المراجع',
                    style: TextStyle(fontFamily: 'Tajawal')),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(referencesListProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
          data: (refs) {
            // Filter
            var filtered = refs;
            if (_searchQuery.isNotEmpty) {
              filtered = filtered.where((r) {
                final title = (r['title_ar'] ?? r['title'] ?? '')
                    .toString()
                    .toLowerCase();
                return title.contains(_searchQuery.toLowerCase());
              }).toList();
            }
            if (_selectedCategory != null) {
              filtered = filtered
                  .where((r) => r['category'] == _selectedCategory)
                  .toList();
            }

            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_outlined,
                        size: 64, color: AppTheme.textHint),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty && _selectedCategory == null
                          ? 'لا توجد مراجع بعد'
                          : 'لا توجد نتائج',
                      style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 16,
                          color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showReferenceDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة مرجع',
                          style: TextStyle(fontFamily: 'Tajawal')),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${filtered.length} مرجع',
                        style: AppTheme.bodyM
                            .copyWith(color: AppTheme.textSecondary),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showReferenceDialog(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('مرجع جديد',
                            style: TextStyle(fontFamily: 'Tajawal')),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final ref = filtered[index];
                      return _buildReferenceCard(ref);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReferenceCard(Map<String, dynamic> ref) {
    final category = ref['category'] ?? 'other';
    final catLabel = categories[category] ?? 'أخرى';
    final catColor = _categoryColor(category);
    final isActive = ref['is_active'] ?? true;
    final createdAt = ref['created_at'] != null
        ? DateFormat('d/M/yyyy').format(DateTime.parse(ref['created_at']))
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMedium),
      color: isActive ? Colors.white : Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _categoryIcon(category),
                color: catColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ref['title_ar'] ?? ref['title'] ?? 'بدون عنوان',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? AppTheme.textPrimary
                                : AppTheme.textHint,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          catLabel,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: catColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (ref['description'] != null)
                    Text(
                      ref['description'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          color: AppTheme.textSecondary),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    children: [
                      if (ref['author'] != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline,
                                size: 14, color: AppTheme.textHint),
                            const SizedBox(width: 4),
                            Text(ref['author'],
                                style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                          ],
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 14, color: AppTheme.textHint),
                          const SizedBox(width: 4),
                          Text(createdAt,
                              style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                      if (ref['file_url'] != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.attach_file,
                                size: 14, color: AppTheme.successColor),
                            const SizedBox(width: 4),
                            const Text('مرفق',
                                style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 12,
                                    color: AppTheme.successColor)),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Actions
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 20, color: AppTheme.infoColor),
                  onPressed: () => _showReferenceDialog(ref: ref),
                  tooltip: 'تعديل',
                ),
                IconButton(
                  icon: Icon(
                    isActive ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: isActive
                        ? AppTheme.warningColor
                        : AppTheme.successColor,
                  ),
                  onPressed: () => _toggleReference(ref['id'], !isActive),
                  tooltip: isActive ? 'إخفاء' : 'إظهار',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: AppTheme.errorColor),
                  onPressed: () => _deleteReference(ref['id']),
                  tooltip: 'حذف',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'manual':
        return AppTheme.primaryColor;
      case 'guide':
        return AppTheme.secondaryColor;
      case 'protocol':
        return AppTheme.infoColor;
      case 'report':
        return AppTheme.warningColor;
      case 'policy':
        return AppTheme.errorColor;
      case 'training':
        return AppTheme.successColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'manual':
        return Icons.menu_book_outlined;
      case 'guide':
        return Icons.explore_outlined;
      case 'protocol':
        return Icons.science_outlined;
      case 'report':
        return Icons.assessment_outlined;
      case 'policy':
        return Icons.gavel_outlined;
      case 'training':
        return Icons.school_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────

  void _showReferenceDialog({Map<String, dynamic>? ref}) {
    final isEdit = ref != null;
    final titleController =
        TextEditingController(text: ref?['title_ar'] ?? ref?['title'] ?? '');
    final descController =
        TextEditingController(text: ref?['description'] ?? '');
    final authorController = TextEditingController(text: ref?['author'] ?? '');
    final urlController = TextEditingController(text: ref?['file_url'] ?? '');
    String selectedCategory = ref?['category'] ?? 'other';
    bool isActive = ref?['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLarge),
              title: Text(
                isEdit ? 'تعديل المرجع' : 'إضافة مرجع جديد',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'عنوان المرجع',
                          prefixIcon: Icon(Icons.title),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        onChanged: (v) =>
                            setDialogState(() => selectedCategory = v!),
                        decoration: const InputDecoration(
                          labelText: 'التصنيف',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: categories.entries
                            .map((e) => DropdownMenuItem(
                                value: e.key, child: Text(e.value)))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'وصف المرجع',
                          prefixIcon: Icon(Icons.description_outlined),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: authorController,
                        decoration: const InputDecoration(
                          labelText: 'المؤلف',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlController,
                        decoration: const InputDecoration(
                          labelText: 'رابط الملف (اختياري)',
                          prefixIcon: Icon(Icons.link),
                          hintText: 'https://...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('المرجع نشط',
                            style: TextStyle(fontFamily: 'Tajawal')),
                        value: isActive,
                        activeColor: AppTheme.primaryColor,
                        onChanged: (v) => setDialogState(() => isActive = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _saveReference(
                    ctx,
                    ref?['id'],
                    titleController.text,
                    selectedCategory,
                    descController.text,
                    authorController.text,
                    urlController.text,
                    isActive,
                  ),
                  icon: Icon(isEdit ? Icons.save : Icons.add, size: 18),
                  label: Text(isEdit ? 'حفظ' : 'إضافة'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveReference(
    BuildContext ctx,
    String? refId,
    String title,
    String category,
    String description,
    String author,
    String url,
    bool isActive,
  ) async {
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('العنوان مطلوب', style: TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    try {
      final client = Supabase.instance.client;
      final data = {
        'title_ar': title,
        'title': title,
        'category': category,
        'description': description.isNotEmpty ? description : null,
        'author': author.isNotEmpty ? author : null,
        'file_url': url.isNotEmpty ? url : null,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (refId != null) {
        await client.from('doc_references').update(data).eq('id', refId);
      } else {
        data['created_at'] = DateTime.now().toIso8601String();
        await client.from('doc_references').insert(data);
      }

      if (ctx.mounted) {
        Navigator.pop(ctx);
        ref.invalidate(referencesListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(refId != null ? 'تم تحديث المرجع' : 'تمت الإضافة',
                style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('فشل: $e', style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _toggleReference(String id, bool active) async {
    try {
      await Supabase.instance.client.from('doc_references').update({
        'is_active': active,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      ref.invalidate(referencesListProvider);
    } catch (_) {}
  }

  Future<void> _deleteReference(String id) async {
    final confirmed = await EpiDialog.show(
      context,
      title: 'حذف المرجع',
      content: 'هل أنت متأكد من حذف هذا المرجع؟',
      confirmText: 'حذف',
      isDanger: true,
    );
    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('doc_references')
          .delete()
          .eq('id', id);
      ref.invalidate(referencesListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('تم حذف المرجع', style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (_) {}
  }
}
