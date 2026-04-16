import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:epi_shared/epi_shared.dart';

// ══════════════════════════════════════════════════════════════════════════════
// إدارة النماذج — Forms Management Screen
// قائمة النماذج + إنشاء/تعديل/حذف + إحصائيات
// ══════════════════════════════════════════════════════════════════════════════

final formsListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  try {
    final response = await client
        .from('forms')
        .select('*')
        .order('created_at', ascending: false);
    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
});

final formsStatsProvider =
    FutureProvider<Map<String, Map<String, int>>>((ref) async {
  final client = Supabase.instance.client;
  try {
    final forms = await client.from('forms').select('id');
    final formIds =
        (forms as List<dynamic>).map((f) => f['id'] as String).toList();

    final Map<String, Map<String, int>> stats = {};
    for (final fid in formIds) {
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
    return stats;
  } catch (_) {
    return {};
  }
});

class FormsManagementScreen extends ConsumerStatefulWidget {
  const FormsManagementScreen({super.key});

  @override
  ConsumerState<FormsManagementScreen> createState() =>
      _FormsManagementScreenState();
}

class _FormsManagementScreenState extends ConsumerState<FormsManagementScreen> {
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
          title: const Text('إدارة النماذج',
              style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _showFormDialog(),
              tooltip: 'إنشاء نموذج',
            ),
          ],
        ),
        body: Column(
          children: [
            // Search
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'بحث في النماذج...',
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
            Expanded(child: _buildFormsList(isWide)),
          ],
        ),
      ),
    );
  }

  Widget _buildFormsList(bool isWide) {
    return Consumer(
      builder: (context, ref, _) {
        final formsAsync = ref.watch(formsListProvider);
        final statsAsync = ref.watch(formsStatsProvider);

        return formsAsync.when(
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
                const Text('فشل تحميل النماذج',
                    style: TextStyle(fontFamily: 'Tajawal')),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(formsListProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
          data: (forms) {
            final filtered = _searchQuery.isEmpty
                ? forms
                : forms.where((f) {
                    final name = (f['name_ar'] ?? f['name'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(_searchQuery.toLowerCase());
                  }).toList();

            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.description_outlined,
                        size: 64, color: AppTheme.textHint),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty
                          ? 'لا توجد نماذج بعد'
                          : 'لا توجد نتائج',
                      style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 16,
                          color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showFormDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إنشاء نموذج جديد',
                          style: TextStyle(fontFamily: 'Tajawal')),
                    ),
                  ],
                ),
              );
            }

            final stats = statsAsync.valueOrNull ?? {};

            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${filtered.length} نموذج',
                        style: AppTheme.bodyM
                            .copyWith(color: AppTheme.textSecondary),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showFormDialog(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('نموذج جديد',
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
                      final form = filtered[index];
                      final formStats = stats[form['id']] ?? {'total': 0};
                      final isActive = form['is_active'] ?? true;
                      final fields =
                          (form['fields'] as List<dynamic>?)?.length ?? 0;
                      final schema = form['schema'] as Map<String, dynamic>?;
                      final schemaFields =
                          (schema?['fields'] as List<dynamic>?)?.length ?? 0;
                      final totalFields = fields > 0 ? fields : schemaFields;
                      final createdAt = form['created_at'] != null
                          ? DateFormat('d/M/yyyy')
                              .format(DateTime.parse(form['created_at']))
                          : '—';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.radiusMedium),
                        child: InkWell(
                          borderRadius: AppTheme.radiusMedium,
                          onTap: () => context.go('/admin/forms/${form['id']}'),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: isWide
                                ? _buildWideFormCard(form, formStats, isActive,
                                    totalFields, createdAt)
                                : _buildCompactFormCard(form, formStats,
                                    isActive, totalFields, createdAt),
                          ),
                        ),
                      );
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

  Widget _buildWideFormCard(
    Map<String, dynamic> form,
    Map<String, int> stats,
    bool isActive,
    int totalFields,
    String createdAt,
  ) {
    return Row(
      children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.description_rounded,
              color: AppTheme.primaryColor, size: 28),
        ),
        const SizedBox(width: 16),
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      form['name_ar'] ?? form['name'] ?? 'بدون عنوان',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  _buildStatusChip(isActive),
                ],
              ),
              const SizedBox(height: 6),
              if (form['description'] != null)
                Text(
                  form['description'],
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
                  _buildInfoChip(Icons.layers_outlined, '$totalFields حقل'),
                  _buildInfoChip(
                      Icons.upload_file, '${stats['total'] ?? 0} إرسالية'),
                  if ((stats['submitted'] ?? 0) > 0)
                    _buildInfoChip(Icons.pending_actions,
                        '${stats['submitted']} قيد المراجعة',
                        color: AppTheme.warningColor),
                  _buildInfoChip(Icons.calendar_today_outlined, createdAt),
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
              icon: const Icon(Icons.edit_outlined, color: AppTheme.infoColor),
              onPressed: () => _showFormDialog(form: form),
              tooltip: 'تعديل',
            ),
            IconButton(
              icon: const Icon(Icons.play_circle_outline,
                  color: AppTheme.primaryColor),
              onPressed: () => context.go('/admin/forms/${form['id']}'),
              tooltip: 'فتح المُصمم',
            ),
            IconButton(
              icon:
                  const Icon(Icons.delete_outline, color: AppTheme.errorColor),
              onPressed: () => _deleteForm(form['id']),
              tooltip: 'حذف',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactFormCard(
    Map<String, dynamic> form,
    Map<String, int> stats,
    bool isActive,
    int totalFields,
    String createdAt,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description_rounded,
                  color: AppTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    form['name_ar'] ?? form['name'] ?? 'بدون عنوان',
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  _buildStatusChip(isActive),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (action) {
                switch (action) {
                  case 'edit':
                    _showFormDialog(form: form);
                    break;
                  case 'open':
                    context.go('/admin/forms/${form['id']}');
                    break;
                  case 'delete':
                    _deleteForm(form['id']);
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 18, color: AppTheme.infoColor),
                        SizedBox(width: 8),
                        Text('تعديل', style: TextStyle(fontFamily: 'Tajawal')),
                      ],
                    )),
                const PopupMenuItem(
                    value: 'open',
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_outline,
                            size: 18, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Text('فتح المُصمم',
                            style: TextStyle(fontFamily: 'Tajawal')),
                      ],
                    )),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: AppTheme.errorColor),
                        SizedBox(width: 8),
                        Text('حذف', style: TextStyle(fontFamily: 'Tajawal')),
                      ],
                    )),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: [
            _buildInfoChip(Icons.layers_outlined, '$totalFields حقل'),
            _buildInfoChip(Icons.upload_file, '${stats['total'] ?? 0} إرسالية'),
            _buildInfoChip(Icons.calendar_today_outlined, createdAt),
          ],
        ),
      ],
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
        isActive ? 'نشط' : 'معطل',
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? AppTheme.successColor : AppTheme.textHint,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? AppTheme.textHint),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12,
            color: color ?? AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────

  void _showFormDialog({Map<String, dynamic>? form}) {
    final isEdit = form != null;
    final nameController =
        TextEditingController(text: form?['name_ar'] ?? form?['name'] ?? '');
    final descController =
        TextEditingController(text: form?['description'] ?? '');
    bool isActive = form?['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLarge),
              title: Text(
                isEdit ? 'تعديل النموذج' : 'إنشاء نموذج جديد',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم النموذج (عربي)',
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'وصف النموذج',
                        prefixIcon: Icon(Icons.description_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('النموذج نشط',
                          style: TextStyle(fontFamily: 'Tajawal')),
                      value: isActive,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (v) => setDialogState(() => isActive = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _saveForm(
                    ctx,
                    form?['id'],
                    nameController.text,
                    descController.text,
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

  Future<void> _saveForm(
    BuildContext ctx,
    String? formId,
    String name,
    String description,
    bool isActive,
  ) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اسم النموذج مطلوب',
              style: TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    try {
      final client = Supabase.instance.client;
      final data = {
        'name_ar': name,
        'name': name,
        'description': description.isNotEmpty ? description : null,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (formId != null) {
        await client.from('forms').update(data).eq('id', formId);
      } else {
        data['created_at'] = DateTime.now().toIso8601String();
        data['schema'] = {'fields': []};
        await client.from('forms').insert(data);
      }

      if (ctx.mounted) {
        Navigator.pop(ctx);
        ref.invalidate(formsListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                formId != null
                    ? 'تم تحديث النموذج'
                    : 'تم إنشاء النموذج — افتح المُصمم لإضافة الحقول',
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

  Future<void> _deleteForm(String id) async {
    final confirmed = await EpiDialog.show(
      context,
      title: 'حذف النموذج',
      content: 'سيتم حذف النموذج وجميع إرسالياته. هل أنت متأكد؟',
      confirmText: 'حذف',
      isDanger: true,
    );
    if (confirmed != true) return;

    try {
      await Supabase.instance.client.from('forms').delete().eq('id', id);
      ref.invalidate(formsListProvider);
      ref.invalidate(formsStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('تم حذف النموذج', style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل: $e', style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
