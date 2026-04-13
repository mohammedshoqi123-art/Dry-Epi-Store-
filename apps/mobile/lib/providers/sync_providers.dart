import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epi_core/epi_core.dart';
import 'sync_queue_v2.dart' as v2;
import 'intelligent_offline_manager.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PROVIDERS for the new v2 sync system
// ═══════════════════════════════════════════════════════════════════════════════

/// The production sync queue (v2) with priority ordering and dead-letter box.
final productionSyncQueueProvider = FutureProvider<v2.ProductionSyncQueue>((ref) async {
  final encryption = ref.read(encryptionServiceProvider);
  final queue = v2.ProductionSyncQueue(encryption);
  await queue.init();
  ref.onDispose(queue.dispose);
  return queue;
});

/// The intelligent offline manager — the single entry point for all offline operations.
final intelligentOfflineManagerProvider =
    FutureProvider<IntelligentOfflineManager>((ref) async {
  final queue = await ref.watch(productionSyncQueueProvider.future);
  final connectivity = Connectivity();

  final manager = IntelligentOfflineManager(
    queue,
    connectivity,
    defaultConflictStrategy: ConflictStrategy.smartMerge,
  );

  // Wire up the server submission callback
  final api = ref.read(apiClientProvider);
  manager.onSubmitBatch = (items) async {
    try {
      final response = await api.callFunction(
        SupabaseConfig.fnSyncOffline,
        {
          'items': items.map((item) => {
            ...item.payload,
            'offline_id': item.id,
            'entity_type': item.type,
          }).toList(),
        },
      );

      final results = (response['results'] as List?) ?? [];
      final serverErrors = (response['errors'] as List?) ?? [];

      final itemResults = <v2.SyncItemResult>[];
      for (int i = 0; i < items.length; i++) {
        final item = items[i];

        // Find matching result by offline_id
        final match = results.cast<Map<String, dynamic>>().firstWhere(
          (r) => r['offline_id'] == item.id,
          orElse: () => <String, dynamic>{},
        );

        if (match.isNotEmpty) {
          final status = match['status'] as String? ?? 'error';
          switch (status) {
            case 'synced':
              itemResults.add(v2.SyncItemResult.ok(item.id, match));
            case 'duplicate':
              itemResults.add(v2.SyncItemResult.duplicate(item.id, match));
            case 'conflict':
              itemResults.add(v2.SyncItemResult.conflict(
                item.id,
                Map<String, dynamic>.from(match['server_data'] ?? {}),
              ));
            default:
              itemResults.add(v2.SyncItemResult.error(item.id, match['error'] ?? 'Unknown'));
          }
        } else {
          // Check if there's an error for this item
          final errMatch = serverErrors.cast<Map<String, dynamic>>().firstWhere(
            (e) => e['offline_id'] == item.id,
            orElse: () => <String, dynamic>{},
          );
          itemResults.add(v2.SyncItemResult.error(
            item.id,
            errMatch['error'] ?? 'No response for item',
          ));
        }
      }
      return itemResults;
    } catch (e) {
      // Batch-level failure: return error for all items
      return items.map((item) => v2.SyncItemResult.error(item.id, e.toString())).toList();
    }
  };

  await manager.init();
  ref.onDispose(manager.dispose);
  return manager;
});

/// Stream provider for reactive UI updates on network state.
final networkSnapshotProvider = StreamProvider<NetworkSnapshot>((ref) async* {
  final manager = await ref.watch(intelligentOfflineManagerProvider.future);
  yield manager.currentSnapshot;
  yield* manager.stateStream;
});

/// Stream provider for the pending queue count (for dashboard badges).
final pendingCountProvider = StreamProvider<int>((ref) async* {
  final manager = await ref.watch(intelligentOfflineManagerProvider.future);
  yield manager.counts.total;
  yield* manager.countsStream.map((c) => c.total);
});

/// Stream provider for detected conflicts (for conflict resolution UI).
final conflictsProvider = StreamProvider<DataConflictV2>((ref) async* {
  final manager = await ref.watch(intelligentOfflineManagerProvider.future);
  yield* manager.conflictStream;
});
