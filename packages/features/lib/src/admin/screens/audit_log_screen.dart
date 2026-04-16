import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ═══════════════════════════════════════════════════════════════════
///  سجل التدقيق — Audit Log Screen
/// ═══════════════════════════════════════════════════════════════════

final auditLogsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client.functions
      .invoke('get-advanced-reports', body: {
    'report_type': 'audit',
    'limit': 100,
  });
  if (response.status != 200) throw Exception('فشل تحميل السجل');
  return List<Map<String, dynamic>>.from(response.data['logs'] ?? []);
});

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _actionFilter = 'all';
  String _tableFilter = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogsProvider);

    return Column(
      children: [
        _buildFilters(),
        const SizedBox(height: 16),
        Expanded(
          child: logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('خطأ: $err')),
            data: (logs) => _buildLogsTable(logs),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث...',
                prefixIcon: const Icon(Icons.search_rounded),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _actionFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('جميع العمليات')),
                  DropdownMenuItem(value: 'create', child: Text('إنشاء')),
                  DropdownMenuItem(value: 'update', child: Text('تعديل')),
                  DropdownMenuItem(value: 'delete', child: Text('حذف')),
                  DropdownMenuItem(value: 'login', child: Text('تسجيل دخول')),
                ],
                onChanged: (v) => setState(() => _actionFilter = v!),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _tableFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('جميع الجداول')),
                  DropdownMenuItem(
                      value: 'profiles', child: Text('المستخدمين')),
                  DropdownMenuItem(
                      value: 'form_submissions', child: Text('الإرساليات')),
                  DropdownMenuItem(value: 'forms', child: Text('النماذج')),
                  DropdownMenuItem(
                      value: 'supply_shortages', child: Text('النواقص')),
                ],
                onChanged: (v) => setState(() => _tableFilter = v!),
              ),
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(auditLogsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('تحديث'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTable(List<Map<String, dynamic>> logs) {
    var filtered = logs.where((l) {
      if (_actionFilter != 'all' && l['action'] != _actionFilter) return false;
      if (_tableFilter != 'all' && l['table_name'] != _tableFilter)
        return false;
      if (_searchQuery.isNotEmpty) {
        final name =
            (l['profiles']?['full_name'] as String? ?? '').toLowerCase();
        if (!name.contains(_searchQuery.toLowerCase())) return false;
      }
      return true;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text('السجلات: ${filtered.length}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('لا توجد سجلات'))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _buildLogTile(filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log) {
    final action = log['action'] as String? ?? '';
    final table = log['table_name'] as String? ?? '';
    final userName = log['profiles']?['full_name'] as String? ?? 'النظام';
    final createdAt = log['created_at'] as String? ?? '';

    IconData icon;
    Color color;
    switch (action) {
      case 'create':
        icon = Icons.add_circle_rounded;
        color = const Color(0xFF43A047);
        break;
      case 'update':
        icon = Icons.edit_rounded;
        color = const Color(0xFF1E88E5);
        break;
      case 'delete':
        icon = Icons.delete_rounded;
        color = const Color(0xFFE53935);
        break;
      case 'login':
        icon = Icons.login_rounded;
        color = const Color(0xFF8E24AA);
        break;
      default:
        icon = Icons.info_rounded;
        color = Colors.grey;
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text('$userName • ${_actionLabel(action)}',
          style: const TextStyle(fontSize: 14, fontFamily: 'Tajawal')),
      subtitle: Text(_tableLabel(table),
          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      trailing: Text(
        _formatDate(createdAt),
        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
      ),
      onTap: () => _showLogDetails(log),
    );
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'create':
        return 'إنشاء';
      case 'update':
        return 'تعديل';
      case 'delete':
        return 'حذف';
      case 'login':
        return 'تسجيل دخول';
      case 'logout':
        return 'تسجيل خروج';
      case 'submit':
        return 'إرسال';
      case 'approve':
        return 'موافقة';
      case 'reject':
        return 'رفض';
      default:
        return action;
    }
  }

  String _tableLabel(String table) {
    switch (table) {
      case 'profiles':
        return 'جدول المستخدمين';
      case 'form_submissions':
        return 'جدول الإرساليات';
      case 'forms':
        return 'جدول النماذج';
      case 'supply_shortages':
        return 'جدول النواقص';
      case 'governorates':
        return 'جدول المحافظات';
      case 'districts':
        return 'جدول المديريات';
      default:
        return table;
    }
  }

  String _formatDate(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return '${diff.inHours} ساعة';
    return '${d.day}/${d.month}/${d.year}';
  }

  void _showLogDetails(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تفاصيل السجل'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('العملية', _actionLabel(log['action'] ?? '')),
                _detailRow('الجدول', _tableLabel(log['table_name'] ?? '')),
                _detailRow(
                    'المستخدم', log['profiles']?['full_name'] ?? 'النظام'),
                _detailRow('التاريخ', log['created_at'] ?? ''),
                if (log['old_data'] != null) ...[
                  const SizedBox(height: 12),
                  const Text('البيانات القديمة:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(log['old_data'].toString(),
                        style: const TextStyle(
                            fontSize: 12, fontFamily: 'monospace')),
                  ),
                ],
                if (log['new_data'] != null) ...[
                  const SizedBox(height: 12),
                  const Text('البيانات الجديدة:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(log['new_data'].toString(),
                        style: const TextStyle(
                            fontSize: 12, fontFamily: 'monospace')),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
