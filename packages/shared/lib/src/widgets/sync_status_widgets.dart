import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/src/offline/sync_queue_v2.dart';
import '../../core/src/offline/intelligent_offline_manager.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SYNC STATUS CHIP
// ═══════════════════════════════════════════════════════════════════════════════

/// Compact sync status chip showing connection state and pending count.
/// 🟢 Online, all synced
/// 🟡 Syncing / pending items
/// 🔴 Offline, items waiting
class SyncStatusChip extends StatelessWidget {
  final NetworkSnapshot snapshot;
  final VoidCallback? onTap;
  final VoidCallback? onSyncNow;

  const SyncStatusChip({
    super.key,
    required this.snapshot,
    this.onTap,
    this.onSyncNow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(color),
            const SizedBox(width: 6),
            Text(
              _label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                fontFamily: 'Tajawal',
              ),
            ),
            if (snapshot.hasPending &&
                snapshot.isOnline &&
                onSyncNow != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onSyncNow,
                child: Icon(Icons.sync, size: 14, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color get _statusColor {
    if (!snapshot.isOnline) return Colors.orange;
    if (snapshot.isSyncing) return Colors.blue;
    if (snapshot.hasPending) return Colors.amber;
    if (snapshot.hasFailed) return Colors.red;
    return Colors.green;
  }

  String get _label {
    if (!snapshot.isOnline) {
      return snapshot.hasPending
          ? 'غير متصل (${snapshot.pendingItems})'
          : 'غير متصل';
    }
    if (snapshot.isSyncing) return 'جاري الرفع...';
    if (snapshot.hasPending) return '${snapshot.pendingItems} في الانتظار';
    if (snapshot.hasFailed) return '${snapshot.failedItems} فشل';
    return 'متصل';
  }

  Widget _buildIcon(Color color) {
    if (!snapshot.isOnline) {
      return Icon(Icons.wifi_off, size: 14, color: color);
    }
    if (snapshot.isSyncing) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    }
    if (snapshot.hasFailed) {
      return Icon(Icons.error_outline, size: 14, color: color);
    }
    return Icon(Icons.wifi, size: 14, color: color);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SYNC STATUS BANNER
// ═══════════════════════════════════════════════════════════════════════════════

/// Full-width banner that appears at the top when there's sync activity.
/// Auto-hides when online with no pending items.
class SyncStatusBanner extends StatelessWidget {
  final NetworkSnapshot snapshot;
  final VoidCallback? onSyncNow;
  final VoidCallback? onViewFailed;

  const SyncStatusBanner({
    super.key,
    required this.snapshot,
    this.onSyncNow,
    this.onViewFailed,
  });

  @override
  Widget build(BuildContext context) {
    // Hide when fully synced and online
    if (snapshot.isOnline && !snapshot.hasPending && !snapshot.hasFailed) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _backgroundColor,
      child: Row(
        children: [
          _buildLeadingIcon(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  snapshot.statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (snapshot.offlineDuration != null)
                  Text(
                    'منذ ${_formatDuration(snapshot.offlineDuration!)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontFamily: 'Tajawal',
                    ),
                  ),
              ],
            ),
          ),
          if (snapshot.hasPending && snapshot.isOnline && onSyncNow != null)
            TextButton.icon(
              onPressed: onSyncNow,
              icon:
                  const Icon(Icons.cloud_upload, size: 16, color: Colors.white),
              label: const Text('مزامنة الآن',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          if (snapshot.hasFailed && onViewFailed != null)
            TextButton.icon(
              onPressed: onViewFailed,
              icon: const Icon(Icons.warning, size: 16, color: Colors.white),
              label: const Text('عرض الفاشلة',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
        ],
      ),
    );
  }

  Color get _backgroundColor {
    if (!snapshot.isOnline) return Colors.orange.shade700;
    if (snapshot.hasFailed) return Colors.red.shade700;
    return Colors.blue.shade600;
  }

  Widget _buildLeadingIcon() {
    if (!snapshot.isOnline) {
      return const Icon(Icons.wifi_off, color: Colors.white, size: 20);
    }
    if (snapshot.isSyncing) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    return const Icon(Icons.cloud_upload, color: Colors.white, size: 20);
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return 'لحظات';
    if (d.inMinutes < 60) return '${d.inMinutes} دقيقة';
    if (d.inHours < 24) return '${d.inHours} ساعة';
    return '${d.inDays} يوم';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PENDING COUNT BADGE
// ═══════════════════════════════════════════════════════════════════════════════

/// Small badge showing the count of unsynced records.
/// Designed for the dashboard/home screen.
class PendingCountBadge extends StatelessWidget {
  final int count;
  final bool isOnline;
  final VoidCallback? onTap;

  const PendingCountBadge({
    super.key,
    required this.count,
    required this.isOnline,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0 && isOnline) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isOnline
              ? Colors.amber.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOnline
                ? Colors.amber.withValues(alpha: 0.3)
                : Colors.red.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOnline ? Icons.cloud_upload_outlined : Icons.cloud_off_outlined,
              size: 16,
              color: isOnline ? Colors.amber.shade800 : Colors.red.shade800,
            ),
            const SizedBox(width: 6),
            Text(
              count > 0 ? '$count سجل غير متزامن' : 'كل شيء متزامن',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isOnline ? Colors.amber.shade800 : Colors.red.shade800,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SYNC NOTIFICATION SNACKBAR
// ═══════════════════════════════════════════════════════════════════════════════

/// Utility to show sync-related SnackBars with retry action.
class SyncNotifications {
  /// Show a success notification after sync completes.
  static void showSyncSuccess(BuildContext context, SyncCycleSummary summary) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تمت المزامنة: ${summary.synced} سجل${summary.duplicates > 0 ? ' (${summary.duplicates} مكرر)' : ''}',
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show an error notification with retry button.
  static void showSyncError(
    BuildContext context, {
    required String message,
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'فشلت المزامنة: $message',
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: onRetry != null
            ? SnackBarAction(
                label: 'إعادة المحاولة',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Show a conflict notification.
  static void showConflict(
    BuildContext context, {
    required int count,
    VoidCallback? onView,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم اكتشاف $count تعارض في البيانات',
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: onView != null
            ? SnackBarAction(
                label: 'عرض',
                textColor: Colors.white,
                onPressed: onView,
              )
            : null,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STREAM-BASED SYNC LISTENER WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

/// Wraps a child widget and listens to sync state changes,
/// automatically showing notifications and updating a status chip.
class SyncStateListener extends StatefulWidget {
  final IntelligentOfflineManager manager;
  final Widget child;
  final bool showBanner;
  final bool showSnackBar;

  const SyncStateListener({
    super.key,
    required this.manager,
    required this.child,
    this.showBanner = true,
    this.showSnackBar = true,
  });

  @override
  State<SyncStateListener> createState() => _SyncStateListenerState();
}

class _SyncStateListenerState extends State<SyncStateListener> {
  StreamSubscription<NetworkSnapshot>? _stateSub;
  StreamSubscription<DataConflictV2>? _conflictSub;
  NetworkSnapshot? _lastSnapshot;

  @override
  void initState() {
    super.initState();
    _stateSub = widget.manager.stateStream.listen(_onStateChanged);
    _conflictSub = widget.manager.conflictStream.listen(_onConflict);
  }

  void _onStateChanged(NetworkSnapshot snapshot) {
    final prev = _lastSnapshot;
    _lastSnapshot = snapshot;

    if (!widget.showSnackBar || !mounted) return;

    // Notify on sync completion
    if (prev?.isSyncing == true && !snapshot.isSyncing && snapshot.isOnline) {
      if (snapshot.hasFailed) {
        SyncNotifications.showSyncError(
          context,
          message: '${snapshot.failedItems} سجل فشل',
          onRetry: () => widget.manager.retryAllFailed(),
        );
      } else if (!snapshot.hasPending) {
        SyncNotifications.showSyncSuccess(
          context,
          SyncCycleSummary(synced: 1), // Simplified
        );
      }
    }
  }

  void _onConflict(DataConflictV2 conflict) {
    if (!widget.showSnackBar || !mounted) return;
    SyncNotifications.showConflict(
      context,
      count: 1,
      onView: () {
        // Navigate to conflict resolution screen
      },
    );
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _conflictSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
