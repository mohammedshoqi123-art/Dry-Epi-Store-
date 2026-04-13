import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epi_shared/epi_shared.dart';
import '../../providers/app_providers.dart';

/// Admin page to manage references (books, guides, manuals).
class AdminReferencesScreen extends ConsumerStatefulWidget {
  const AdminReferencesScreen({super.key});

  @override
  ConsumerState<AdminReferencesScreen> createState() => _AdminReferencesScreenState();
}

class _AdminReferencesScreenState extends ConsumerState<AdminReferencesScreen> {
  List<Map<String, dynamic>> _references = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReferences();
  }

  Future<void> _loadReferences() async {
    try {
      final db = ref.read(databaseServiceProvider);
      final data = await db.getReferences(includeInactive: true);
      if (mounted) {
        setState(() {
          _references = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEditDialog([Map<String, dynamic>? existing]) {
    final titleCtrl = TextEditingController(text: existing?['title_ar'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description_ar'] ?? '');
    final urlCtrl = TextEditingController(text: existing?['file_url'] ?? '');
    String selectedCategory = existing?['category'] ?? 'guide';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'إضافة مرجع جديد' : 'تعديل المرجع',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EpiTextField(controller: titleCtrl, label: 'العنوان', required: true),
                const SizedBox(height: 12),
                EpiTextField(controller: descCtrl, label: 'الوصف', maxLines: 3),
                const SizedBox(height: 12),
                EpiTextField(controller: urlCtrl, label: 'رابط الملف (URL)'),
                const SizedBox(height: 12),
                EpiDropdown<String>(
                  value: selectedCategory,
                  label: 'التصنيف',
                  items: const [
                    DropdownMenuItem(value: 'guide', child: Text('دليل')),
                    DropdownMenuItem(value: 'manual', child: Text('كتيب')),
                    DropdownMenuItem(value: 'form', child: Text('استمارة')),
                    DropdownMenuItem(value: 'training', child: Text('تدريب')),
                    DropdownMenuItem(value: 'general', child: Text('عام')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedCategory = v ?? 'guide'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                try {
                  final db = ref.read(databaseServiceProvider);
                  final data = {
                    'title_ar': titleCtrl.text.trim(),
                    'description_ar': descCtrl.text.trim(),
                    'file_url': urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
                    'category': selectedCategory,
                    'is_active': true,
                  };

                  if (existing != null) {
                    await db.updateReference(existing['id'], data);
                  } else {
                    await db.createReference(data);
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadReferences();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم الحفظ بنجاح')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('خطأ: $e')),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المراجع', style: TextStyle(fontFamily: 'Cairo')),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة مرجع', style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: _isLoading
          ? const EpiLoading()
          : _references.isEmpty
              ? const EpiEmptyState(
                  icon: Icons.menu_book_outlined,
                  message: 'لا توجد مراجع — اضغط + للإضافة',
                )
              : RefreshIndicator(
                  onRefresh: _loadReferences,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _references.length,
                    itemBuilder: (context, index) {
                      final ref = _references[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            ref['is_active'] == true
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: ref['is_active'] == true
                                ? Colors.green
                                : Colors.grey,
                          ),
                          title: Text(
                            ref['title_ar'] ?? '',
                            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${ref['category'] ?? 'عام'} — ${ref['description_ar'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Tajawal'),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showAddEditDialog(ref),
                              ),
                              IconButton(
                                icon: Icon(
                                  ref['is_active'] == true
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  final db = ref.read(databaseServiceProvider);
                                  await db.updateReference(ref['id'], {
                                    'is_active': !(ref['is_active'] == true),
                                  });
                                  _loadReferences();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
