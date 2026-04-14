import 'package:flutter/material.dart';
import 'package:epi_core/epi_core.dart';
import 'package:epi_shared/epi_shared.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      await NotificationService.loadFromDB(refresh: true);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final notifications = NotificationService.all;
    final unreadCount = NotificationService.unreadCount;

    return Scaffold(
      appBar: EpiAppBar(
        title: 'الإشعارات',
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: () async {
                await NotificationService.markAllAsRead();
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.done_all, size: 20),
              label: Text(
                'تحديد الكل كمقروء ($unreadCount)',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const EpiLoading.shimmer()
          : notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: notifications.length + (NotificationService.hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      if (index >= notifications.length) {
                        return _buildLoadMoreButton();
                      }
                      return _buildNotificationTile(notifications[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 72, color: AppTheme.textHint.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'لا توجد إشعارات',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'ستظهر هنا الإشعارات الجديدة عند وصولها',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 14, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(AppNotification notification) {
    final icon = _getIconForType(notification.type);
    final color = _getColorForType(notification.type);
    final timeAgo = _formatTimeAgo(notification.createdAt);

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: notification.read ? FontWeight.normal : FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            notification.body,
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppTheme.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  notification.category,
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: color),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeAgo,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.textHint),
              ),
            ],
          ),
        ],
      ),
      trailing: !notification.read
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 6),
                ],
              ),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: () async {
        if (!notification.read) {
          await NotificationService.markAsRead(notification.id);
          if (mounted) setState(() {});
        }
      },
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: () async {
            await NotificationService.loadFromDB();
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.expand_more, size: 18),
          label: const Text('تحميل المزيد', style: TextStyle(fontFamily: 'Tajawal')),
        ),
      ),
    );
  }

  IconData _getIconForType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.success:
        return Icons.check_circle_rounded;
      case AppNotificationType.warning:
        return Icons.warning_rounded;
      case AppNotificationType.error:
        return Icons.error_rounded;
      case AppNotificationType.sync:
        return Icons.sync_rounded;
      case AppNotificationType.info:
        return Icons.info_rounded;
    }
  }

  Color _getColorForType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.success:
        return AppTheme.successColor;
      case AppNotificationType.warning:
        return AppTheme.warningColor;
      case AppNotificationType.error:
        return AppTheme.errorColor;
      case AppNotificationType.sync:
        return AppTheme.primaryColor;
      case AppNotificationType.info:
        return AppTheme.infoColor;
    }
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${date.day}/${date.month}/${date.year}';
  }
}
