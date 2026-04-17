import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:dry_shared/epi_shared.dart';

// ══════════════════════════════════════════════════════════════════════════════
// إدارة الصفحات — Pages Management Screen
// إنشاء وتعديل صفحات ديناميكية بدون كود
// ══════════════════════════════════════════════════════════════════════════════

final pagesListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  try {
    final response = await client
        .from('pages')
        .select('*')
        .order('sort_order', ascending: true);
    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
});

class PagesManagementScreen extends ConsumerStatefulWidget {
  const PagesManagementScreen({super.key});

  @override
  ConsumerState<PagesManagementScreen> createState() =>
      _PagesManagementScreenState();
}

class _PagesManagementScreenState extends ConsumerState<PagesManagementScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          title: const Text('إدارة الصفحات',
              style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _showPageDialog(),
              tooltip: 'إضافة صفحة',
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'بحث في الصفحات...',
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
            // Pages list
            Expanded(child: _buildPagesList(isWide)),
          ],
        ),
      ),
    );
  }

  Widget _buildPagesList(bool isWide) {
    return Consumer(
      builder: (context, ref, _) {
        final pagesAsync = ref.watch(pagesListProvider);

        return pagesAsync.when(
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 5,
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                height: 80,
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
                const Text('فشل تحميل الصفحات',
                    style: TextStyle(fontFamily: 'Tajawal')),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(pagesListProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
          data: (pages) {
            final filtered = _searchQuery.isEmpty
                ? pages
                : pages.where((p) {
                    final title =
                        (p['title_ar'] ?? '').toString().toLowerCase();
                    return title.contains(_searchQuery.toLowerCase());
                  }).toList();

            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.web_outlined,
                        size: 64, color: AppTheme.textHint),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty
                          ? 'لا توجد صفحات بعد'
                          : 'لا توجد نتائج',
                      style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 16,
                          color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showPageDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إنشاء صفحة جديدة',
                          style: TextStyle(fontFamily: 'Tajawal')),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Summary
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${filtered.length} صفحة',
                        style: AppTheme.bodyM
                            .copyWith(color: AppTheme.textSecondary),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showPageDialog(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('صفحة جديدة',
                            style: TextStyle(fontFamily: 'Tajawal')),
                      ),
                    ],
                  ),
                ),
                // List
                Expanded(
                  child: isWide
                      ? _buildDataTable(filtered)
                      : _buildCardsList(filtered),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDataTable(List<Map<String, dynamic>> pages) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingRowColor: WidgetStateProperty.all(AppTheme.primarySurface),
        columns: const [
          DataColumn(
              label: Text('الترتيب',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w600))),
          DataColumn(
              label: Text('العنوان',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w600))),
          DataColumn(
              label: Text('المسار',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w600))),
          DataColumn(
              label: Text('الحالة',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w600))),
          DataColumn(
              label: Text('آخر تحديث',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w600))),
          DataColumn(
              label: Text('إجراءات',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w600))),
        ],
        rows: pages.map((page) {
          final isActive = page['is_active'] ?? true;
          final updatedAt = page['updated_at'] != null
              ? DateFormat('d/M/yyyy')
                  .format(DateTime.parse(page['updated_at']))
              : '—';

          return DataRow(cells: [
            DataCell(Text('${page['sort_order'] ?? 0}',
                style: const TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.w600))),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getPageIcon(page['icon_name']),
                    size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(page['title_ar'] ?? '',
                    style: const TextStyle(fontFamily: 'Tajawal')),
              ],
            )),
            DataCell(Text('/${page['slug'] ?? ''}',
                style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    color: AppTheme.textSecondary))),
            DataCell(_buildStatusChip(isActive)),
            DataCell(Text(updatedAt,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: AppTheme.infoColor),
                  onPressed: () => _showPageDialog(page: page),
                  tooltip: 'تعديل',
                ),
                IconButton(
                  icon: Icon(
                    isActive ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: isActive
                        ? AppTheme.warningColor
                        : AppTheme.successColor,
                  ),
                  onPressed: () => _togglePageActive(page['id'], !isActive),
                  tooltip: isActive ? 'إخفاء' : 'إظهار',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppTheme.errorColor),
                  onPressed: () => _deletePage(page['id']),
                  tooltip: 'حذف',
                ),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildCardsList(List<Map<String, dynamic>> pages) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pages.length,
      onReorder: (oldIndex, newIndex) =>
          _reorderPages(pages, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final page = pages[index];
        final isActive = page['is_active'] ?? true;

        return Card(
          key: ValueKey(page['id']),
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMedium),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getPageIcon(page['icon_name']),
                  color: AppTheme.primaryColor, size: 22),
            ),
            title: Text(page['title_ar'] ?? '',
                style: const TextStyle(
                    fontFamily: 'Tajawal', fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('/${page['slug'] ?? ''}',
                    style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        color: AppTheme.textHint)),
                const SizedBox(height: 4),
                _buildStatusChip(isActive),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 20, color: AppTheme.infoColor),
                  onPressed: () => _showPageDialog(page: page),
                ),
                const Icon(Icons.drag_handle,
                    color: AppTheme.textHint, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isActive ? AppTheme.successColor : AppTheme.textHint)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'نشط' : 'مخفي',
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? AppTheme.successColor : AppTheme.textHint,
        ),
      ),
    );
  }

  IconData _getPageIcon(String? iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home_rounded;
      case 'description':
        return Icons.description_rounded;
      case 'analytics':
        return Icons.analytics_rounded;
      case 'map':
        return Icons.map_rounded;
      case 'settings':
        return Icons.settings_rounded;
      case 'people':
        return Icons.people_rounded;
      case 'notifications':
        return Icons.notifications_rounded;
      case 'info':
        return Icons.info_outline;
      case 'help':
        return Icons.help_outline;
      case 'book':
        return Icons.book_outlined;
      default:
        return Icons.web_outlined;
    }
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────

  void _showPageDialog({Map<String, dynamic>? page}) {
    final isEdit = page != null;
    final titleController =
        TextEditingController(text: page?['title_ar'] ?? '');
    final slugController = TextEditingController(text: page?['slug'] ?? '');
    final contentController =
        TextEditingController(text: page?['content'] ?? '');
    final iconController =
        TextEditingController(text: page?['icon_name'] ?? 'web');
    bool isActive = page?['is_active'] ?? true;
    String selectedIcon = page?['icon_name'] ?? 'web';

    final iconOptions = {
      'web': Icons.web_outlined,
      'home': Icons.home_rounded,
      'description': Icons.description_rounded,
      'analytics': Icons.analytics_rounded,
      'map': Icons.map_rounded,
      'settings': Icons.settings_rounded,
      'people': Icons.people_rounded,
      'notifications': Icons.notifications_rounded,
      'info': Icons.info_outline,
      'help': Icons.help_outline,
      'book': Icons.book_outlined,
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLarge),
              title: Text(
                isEdit ? 'تعديل الصفحة' : 'إنشاء صفحة جديدة',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'عنوان الصفحة (عربي)',
                          prefixIcon: Icon(Icons.title),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: slugController,
                        decoration: const InputDecoration(
                          labelText: 'المسار (slug)',
                          prefixIcon: Icon(Icons.link),
                          hintText: 'مثال: about-us',
                        ),
                        style: const TextStyle(fontFamily: 'Tajawal'),
                      ),
                      const SizedBox(height: 12),
                      // Icon picker
                      const Text('أيقونة الصفحة:',
                          style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: iconOptions.entries.map((entry) {
                          return InkWell(
                            onTap: () => setDialogState(() {
                              selectedIcon = entry.key;
                            }),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: selectedIcon == entry.key
                                    ? AppTheme.primaryColor
                                        .withValues(alpha: 0.15)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selectedIcon == entry.key
                                      ? AppTheme.primaryColor
                                      : Colors.transparent,
                                ),
                              ),
                              child: Icon(entry.value,
                                  color: selectedIcon == entry.key
                                      ? AppTheme.primaryColor
                                      : AppTheme.textSecondary,
                                  size: 22),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contentController,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'محتوى الصفحة (HTML/Markdown)',
                          prefixIcon: Icon(Icons.code),
                          alignLabelWithHint: true,
                        ),
                        style: const TextStyle(fontFamily: 'Tajawal'),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('الصفحة نشطة',
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
                  onPressed: () => _savePage(
                    ctx,
                    page?['id'],
                    titleController.text,
                    slugController.text,
                    contentController.text,
                    selectedIcon,
                    isActive,
                  ),
                  icon: Icon(isEdit ? Icons.save : Icons.add, size: 18),
                  label: Text(isEdit ? 'حفظ' : 'إنشاء'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _savePage(
    BuildContext ctx,
    String? pageId,
    String title,
    String slug,
    String content,
    String icon,
    bool isActive,
  ) async {
    if (title.isEmpty || slug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('العنوان والمسار مطلوبان',
              style: TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    try {
      final client = Supabase.instance.client;
      final data = {
        'title_ar': title,
        'slug': slug,
        'content': content,
        'icon_name': icon,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (pageId != null) {
        await client.from('pages').update(data).eq('id', pageId);
      } else {
        data['created_at'] = DateTime.now().toIso8601String();
        data['sort_order'] = 999;
        await client.from('pages').insert(data);
      }

      if (ctx.mounted) {
        Navigator.pop(ctx);
        ref.invalidate(pagesListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                pageId != null ? 'تم تحديث الصفحة' : 'تم إنشاء الصفحة',
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

  Future<void> _togglePageActive(String id, bool active) async {
    try {
      await Supabase.instance.client.from('pages').update({
        'is_active': active,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      ref.invalidate(pagesListProvider);
    } catch (_) {}
  }

  Future<void> _deletePage(String id) async {
    final confirmed = await EpiDialog.show(
      context,
      title: 'حذف الصفحة',
      content: 'هل أنت متأكد من حذف هذه الصفحة؟',
      confirmText: 'حذف',
      isDanger: true,
    );
    if (confirmed != true) return;

    try {
      await Supabase.instance.client.from('pages').delete().eq('id', id);
      ref.invalidate(pagesListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('تم حذف الصفحة', style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _reorderPages(
      List<Map<String, dynamic>> pages, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    try {
      final reordered = List.of(pages);
      final item = reordered.removeAt(oldIndex);
      reordered.insert(newIndex, item);

      for (int i = 0; i < reordered.length; i++) {
        await Supabase.instance.client.from('pages').update({
          'sort_order': i,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', reordered[i]['id']);
      }
      ref.invalidate(pagesListProvider);
    } catch (_) {}
  }
}
