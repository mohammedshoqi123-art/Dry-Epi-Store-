import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows a banner when offline or when there are pending sync items.
/// Automatically hides when online with no pending items.
class ConnectivityBanner extends ConsumerWidget {
  final bool isOnline;
  final int pendingCount;

  const ConnectivityBanner({
    super.key,
    required this.isOnline,
    this.pendingCount = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isOnline && pendingCount == 0) return const SizedBox.shrink();

    return Container(
      color: isOnline ? Colors.green.shade700 : Colors.red.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            isOnline
                ? 'متصل - جاري مزامنة $pendingCount عنصر...'
                : 'غير متصل - $pendingCount عنصر في الانتظار',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Tajawal',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
