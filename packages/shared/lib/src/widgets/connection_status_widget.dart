import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../offline/enhanced_sync_service.dart';

/// Animated connection status widget with quality indicator and pending count.
/// Shows real-time connection state with smooth transitions.
class ConnectionStatusWidget extends ConsumerWidget {
  final ConnectionState state;
  final VoidCallback? onTap;
  final VoidCallback? onSyncNow;

  const ConnectionStatusWidget({
    super.key,
    required this.state,
    this.onTap,
    this.onSyncNow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isOnline = state.isOnline;
    final hasPending = state.pendingItems > 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _backgroundColor(isOnline, hasPending, theme),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _borderColor(isOnline, hasPending),
            width: 1.5,
          ),
          boxShadow: [
            if (hasPending && isOnline)
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Connection icon with pulse animation
            _buildConnectionIcon(isOnline, hasPending),
            const SizedBox(width: 8),

            // Status text
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _statusText(isOnline, hasPending),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textColor(isOnline, hasPending),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (state.offlineDuration != null && !isOnline)
                    Text(
                      _formatDuration(state.offlineDuration!),
                      style: TextStyle(
                        fontSize: 10,
                        color: _textColor(isOnline, hasPending).withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),

            // Sync button when pending
            if (hasPending && isOnline && onSyncNow != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onSyncNow,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sync,
                    size: 14,
                    color: Colors.green,
                  ),
                ),
              ),
            ],

            // Quality indicator
            if (isOnline) ...[
              const SizedBox(width: 6),
              _buildQualityIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionIcon(bool isOnline, bool hasPending) {
    if (!isOnline) {
      return const Icon(Icons.wifi_off, size: 16, color: Colors.orange);
    }
    if (hasPending) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
        ),
      );
    }
    return Icon(Icons.wifi, size: 16, color: Colors.green.shade700);
  }

  Widget _buildQualityIndicator() {
    Color color;
    int bars;
    switch (state.quality) {
      case ConnectionQuality.excellent:
        color = Colors.green;
        bars = 4;
      case ConnectionQuality.good:
        color = Colors.green;
        bars = 3;
      case ConnectionQuality.poor:
        color = Colors.orange;
        bars = 1;
      case ConnectionQuality.offline:
        color = Colors.grey;
        bars = 0;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        return Container(
          width: 3,
          height: 4.0 + (i * 2),
          margin: const EdgeInsets.only(left: 1),
          decoration: BoxDecoration(
            color: i < bars ? color : color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  Color _backgroundColor(bool isOnline, bool hasPending, ThemeData theme) {
    if (!isOnline) return Colors.orange.withOpacity(0.1);
    if (hasPending) return Colors.green.withOpacity(0.1);
    return Colors.green.withOpacity(0.05);
  }

  Color _borderColor(bool isOnline, bool hasPending) {
    if (!isOnline) return Colors.orange.withOpacity(0.5);
    if (hasPending) return Colors.green.withOpacity(0.5);
    return Colors.green.withOpacity(0.3);
  }

  Color _textColor(bool isOnline, bool hasPending) {
    if (!isOnline) return Colors.orange.shade800;
    if (hasPending) return Colors.green.shade800;
    return Colors.green.shade700;
  }

  String _statusText(bool isOnline, bool hasPending) {
    if (!isOnline) {
      return hasPending
          ? 'غير متصل - ${state.pendingItems} عنصر معلق'
          : 'غير متصل';
    }
    if (hasPending) return 'مزامنة ${state.pendingItems} عنصر...';
    return 'متصل (${state.qualityText})';
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return 'منذ لحظات';
    if (d.inMinutes < 60) return 'منذ ${d.inMinutes} دقيقة';
    if (d.inHours < 24) return 'منذ ${d.inHours} ساعة';
    return 'منذ ${d.inDays} يوم';
  }
}

/// Compact floating connection indicator for use in app bars
class FloatingConnectionIndicator extends StatelessWidget {
  final ConnectionState state;
  final VoidCallback? onTap;

  const FloatingConnectionIndicator({
    super.key,
    required this.state,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isOnline && state.pendingItems == 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 4,
      right: 8,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: ConnectionStatusWidget(
          state: state,
          onTap: onTap,
        ),
      ),
    );
  }
}
