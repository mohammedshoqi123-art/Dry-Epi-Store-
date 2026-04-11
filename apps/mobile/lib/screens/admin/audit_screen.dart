import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epi_shared/epi_shared.dart';
import '../../providers/app_providers.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  String? _actionFilter;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EpiAppBar(
        title: 'سجل العمليات',
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_actionFilter != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Chip(label: Text(_actionFilter!, style: const TextStyle(fontFamily: 'Tajawal'))),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _actionFilter = null),
                    child: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: ref.read(databaseServiceProvider).getAuditLogs(
                    action: _actionFilter,
                    limit: 50,
                    offset: _page * 50,
                  ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return EpiLoading.shimmer();
                }
                if (snapshot.hasError) {
                  return EpiErrorWidget(message: snapshot.error.toString());
                }
                final logs = snapshot.data ?? [];
                if (logs.isEmpty) {
                  return const EpiEmptyState(
                    icon: Icons.history,
                    title: 'لا توجد سجلات',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _AuditTile(
                      action: log['action'] ?? '',
                      tableName: log['table_name'] ?? '',
                      userName: log['profiles']?['full_name'] ?? 'غير معروف',
                      date: log['created_at'],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('تصفية حسب الإجراء',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: ['create', 'update', 'delete', 'login', 'submit', 'approve', 'reject']
                  .map((a) => ChoiceChip(
                        label: Text(_actionLabel(a), style: const TextStyle(fontFamily: 'Tajawal')),
                        selected: _actionFilter == a,
                        onSelected: (s) {
                          setState(() => _actionFilter = s ? a : null);
                          Navigator.pop(context);
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'create': return 'إنشاء';
      case 'update': return 'تحديث';
      case 'delete': return 'حذف';
      case 'login': return 'دخول';
      case 'submit': return 'إرسال';
      case 'approve': return 'اعتماد';
      case 'reject': return 'رفض';
      default: return action;
    }
  }
}

class _AuditTile extends StatelessWidget {
  final String action;
  final String tableName;
  final String userName;
  final String? date;

  const _AuditTile({
    required this.action,
    required this.tableName,
    required this.userName,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _actionIcon(action);
    final color = _actionColor(action);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 13)),
                Text('$tableName - ${_actionLabelAr(action)}',
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          if (date != null)
            Text(_formatDate(date!), style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppTheme.textHint)),
        ],
      ),
    );
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'create': return Icons.add_circle;
      case 'update': return Icons.edit;
      case 'delete': return Icons.delete;
      case 'login': return Icons.login;
      case 'submit': return Icons.send;
      case 'approve': return Icons.check_circle;
      case 'reject': return Icons.cancel;
      default: return Icons.info;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'create': return AppTheme.successColor;
      case 'update': return AppTheme.infoColor;
      case 'delete': return AppTheme.errorColor;
      case 'login': return AppTheme.primaryColor;
      case 'submit': return AppTheme.warningColor;
      case 'approve': return AppTheme.successColor;
      case 'reject': return AppTheme.errorColor;
      default: return Colors.grey;
    }
  }

  String _actionLabelAr(String action) {
    switch (action) {
      case 'create': return 'إنشاء';
      case 'update': return 'تحديث';
      case 'delete': return 'حذف';
      case 'login': return 'دخول';
      case 'submit': return 'إرسال';
      case 'approve': return 'اعتماد';
      case 'reject': return 'رفض';
      default: return action;
    }
  }

  String _formatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return '${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}
