import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ═══════════════════════════════════════════════════════════════════
///  مركز الإشعارات — Notification Center
/// ═══════════════════════════════════════════════════════════════════

final notificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  final response = await client.functions.invoke('manage-notifications', body: {
    'action': 'list',
    'limit': 100,
  });
  if (response.status != 200) throw Exception('فشل تحميل الإشعارات');
  return List<Map<String, dynamic>>.from(response.data['notifications'] ?? []);
});

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notificationsProvider);

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: notifsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('خطأ: $err')),
            data: (notifs) => _buildNotificationsList(notifs),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Row(
        children: [
          // Filter chips
          ...['all', 'unread', 'info', 'success', 'error'].map((f) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: FilterChip(
              label: Text(_filterLabel(f)),
              selected: _filter == f,
              onSelected: (_) => setState(() => _filter = f),
              selectedColor: const Color(0xFF00897B).withOpacity(0.15),
              checkmarkColor: const Color(0xFF00897B),
            ),
          )),
          const Spacer(),
          // Mark all read
          OutlinedButton.icon(
            onPressed: () => _markAllRead(),
            icon: const Icon(Icons.done_all_rounded),
            label: const Text('تعيين الكل كمقروء'),
          ),
          const SizedBox(width: 12),
          // Send notification
          ElevatedButton.icon(
            onPressed: () => _showSendDialog(),
            icon: const Icon(Icons.send_rounded),
            label: const Text('إرسال إشعار'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(List<Map<String, dynamic>> notifs) {
    var filtered = notifs.where((n) {
      if (_filter == 'unread') return n['is_read'] != true;
      if (_filter == 'all') return true;
      return n['type'] == _filter;
    }).toList();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: filtered.isEmpty
          ? const Center(child: Text('لا توجد إشعارات'))
          : ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) => _buildNotifTile(filtered[index]),
            ),
    );
  }

  Widget _buildNotifTile(Map<String, dynamic> notif) {
    final isRead = notif['is_read'] as bool? ?? false;
    final type = notif['type'] as String? ?? 'info';

    IconData icon;
    Color color;
    switch (type) {
      case 'success': icon = Icons.check_circle_rounded; color = const Color(0xFF43A047); break;
      case 'error': icon = Icons.error_rounded; color = const Color(0xFFE53935); break;
      case 'warning': icon = Icons.warning_rounded; color = const Color(0xFFFB8C00); break;
      default: icon = Icons.info_rounded; color = const Color(0xFF1E88E5);
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        notif['title'] ?? '',
        style: TextStyle(
          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          fontFamily: 'Tajawal',
        ),
      ),
      subtitle: Text(
        notif['body'] ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: Colors.grey[600], fontFamily: 'Tajawal'),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatDate(notif['created_at']),
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
          if (!isRead)
            IconButton(
              icon: const Icon(Icons.mark_email_read_rounded, size: 18),
              onPressed: () => _markRead([notif['id']]),
            ),
          IconButton(
            icon: Icon(Icons.delete_rounded, size: 18, color: Colors.red[300]),
            onPressed: () => _deleteNotif(notif['id']),
          ),
        ],
      ),
      onTap: () {
        if (!isRead) _markRead([notif['id']]);
      },
    );
  }

  String _filterLabel(String f) {
    switch (f) {
      case 'all': return 'الكل';
      case 'unread': return 'غير مقروء';
      case 'info': return 'معلومات';
      case 'success': return 'نجاح';
      case 'error': return 'خطأ';
      default: return f;
    }
  }

  String _formatDate(String? date) {
    if (date == null) return '';
    final d = DateTime.tryParse(date);
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes} د';
    if (diff.inHours < 24) return '${diff.inHours} س';
    return '${diff.inDays} ي';
  }

  void _markRead(List<String> ids) async {
    try {
      await Supabase.instance.client.functions.invoke('manage-notifications', body: {
        'action': 'mark_read',
        'notification_ids': ids,
      });
      ref.invalidate(notificationsProvider);
    } catch (_) {}
  }

  void _markAllRead() async {
    try {
      await Supabase.instance.client.functions.invoke('manage-notifications', body: {
        'action': 'mark_all_read',
      });
      ref.invalidate(notificationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تعيين الكل كمقروء')),
        );
      }
    } catch (_) {}
  }

  void _deleteNotif(String id) async {
    try {
      await Supabase.instance.client.functions.invoke('manage-notifications', body: {
        'action': 'delete',
        'notification_ids': [id],
      });
      ref.invalidate(notificationsProvider);
    } catch (_) {}
  }

  void _showSendDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String targetType = 'all';
    String notifType = 'info';
    String? govId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إرسال إشعار'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الإشعار',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'نص الإشعار',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: notifType,
                        decoration: const InputDecoration(labelText: 'النوع', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'info', child: Text('معلومات')),
                          DropdownMenuItem(value: 'success', child: Text('نجاح')),
                          DropdownMenuItem(value: 'warning', child: Text('تحذير')),
                          DropdownMenuItem(value: 'error', child: Text('خطأ')),
                        ],
                        onChanged: (v) => setDialogState(() => notifType = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: targetType,
                        decoration: const InputDecoration(labelText: 'إلى', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('الجميع')),
                          DropdownMenuItem(value: 'admin', child: Text('المسؤولين')),
                          DropdownMenuItem(value: 'central', child: Text('المركزيين')),
                          DropdownMenuItem(value: 'governorate', child: Text('المحافظات')),
                          DropdownMenuItem(value: 'district', child: Text('المديريات')),
                          DropdownMenuItem(value: 'data_entry', child: Text('إدخال البيانات')),
                        ],
                        onChanged: (v) => setDialogState(() => targetType = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) return;
                try {
                  final target = targetType == 'all' ? <String, dynamic>{} : {'role': targetType};
                  await Supabase.instance.client.functions.invoke('manage-notifications', body: {
                    'action': 'send',
                    'title': titleCtrl.text,
                    'body': bodyCtrl.text,
                    'type': notifType,
                    'target': target,
                  });
                  Navigator.pop(ctx);
                  ref.invalidate(notificationsProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إرسال الإشعار بنجاح')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                  }
                }
              },
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }
}
