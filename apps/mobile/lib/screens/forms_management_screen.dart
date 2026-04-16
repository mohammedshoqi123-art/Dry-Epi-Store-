import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:epi_shared/epi_shared.dart';

/// إدارة النماذج — Forms Management Screen (Mobile)
/// عرض + إنشاء + تعديل + تفعيل/تعطيل النماذج
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

      // Load stats per form
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
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: EpiLoading.shimmer());
    if (_error != null) return Center(child: EpiErrorWidget(message: _error!, onRetry: _loadData));
    if (_forms.isEmpty) return Center(child: EpiEmptyState(
      icon: Icons.description_outlined,
      message: 'لا توجد نماذج',
      actionLabel: 'إعادة تحميل',
      onAction: _loadData,
    ));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
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
        onTap: () => _showFormDetails(form, stats),
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
                      color: isActive ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                  Switch(
                    value: isActive,
                    onChanged: (_) => _toggleFormActive(form),
                    activeColor: AppTheme.successColor,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Stats row
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
              // Tags
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

  void _showFormDetails(Map<String, dynamic> form, Map<String, int> stats) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(form['title_ar'] ?? '—', style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700)),
            if (form['description_ar'] != null) ...[
              const SizedBox(height: 8),
              Text(form['description_ar'], style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, color: AppTheme.textSecondary)),
            ],
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            // Stats grid
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _miniStat('الكل', stats['total'] ?? 0, AppTheme.primaryColor),
                _miniStat('مسودة', stats['draft'] ?? 0, Colors.grey),
                _miniStat('مرسل', stats['submitted'] ?? 0, AppTheme.infoColor),
                _miniStat('مراجعة', stats['reviewed'] ?? 0, AppTheme.warningColor),
                _miniStat('معتمد', stats['approved'] ?? 0, AppTheme.successColor),
                _miniStat('مرفوض', stats['rejected'] ?? 0, AppTheme.errorColor),
              ],
            ),
            const SizedBox(height: 20),
            // Requirements
            const Text('المتطلبات:', style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (form['requires_gps'] == true)
              const ListTile(dense: true, leading: Icon(Icons.location_on_rounded, color: AppTheme.infoColor), title: Text('إحداثيات GPS مطلوبة', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13))),
            if (form['requires_photo'] == true)
              ListTile(dense: true, leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.warningColor), title: Text('صورة مطلوبة (حد أقصى ${form['max_photos'] ?? 5})', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13))),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, int value, Color color) {
    return Container(
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$value', style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: color)),
        ],
      ),
    );
  }
}
