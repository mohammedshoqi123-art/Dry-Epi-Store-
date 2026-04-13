import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epi_core/epi_core.dart';

// ─── Core Services ────────────────────────────────────────────────────────────
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final encryptionServiceProvider =
    Provider<EncryptionService>((ref) => EncryptionService());

final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => DatabaseService(ref.read(apiClientProvider)),
);

final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(ref.read(apiClientProvider)),
);

final geminiServiceProvider = Provider<GeminiService>(
  (ref) => GeminiService(ref.read(apiClientProvider)),
);

// ─── Offline / Sync ───────────────────────────────────────────────────────────
final offlineManagerProvider = FutureProvider<OfflineManager>((ref) async {
  final manager = OfflineManager(ref.read(encryptionServiceProvider));
  try {
    // Add timeout to prevent infinite hang if Hive initialization fails
    await manager.init().timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        debugPrint('[offlineManagerProvider] Hive init timed out after 15s');
        throw TimeoutException('Offline storage initialization timed out');
      },
    );
  } catch (e) {
    debugPrint('[offlineManagerProvider] Init failed: $e');
    rethrow;
  }

  // Bridge: push ConnectivityUtils updates to OfflineManager
  // This avoids duplicate connectivity listeners across the app
  StreamSubscription? connSub;
  try {
    connSub = ConnectivityUtils.onConnectivityChanged.listen((online) {
      manager.updateConnectivity(online);
    });
  } catch (e) {
    debugPrint('[offlineManagerProvider] Connectivity bridge failed: $e');
  }

  ref.onDispose(() {
    connSub?.cancel();
    manager.dispose();
  });
  return manager;
});

/// Offline-first data cache — stores Supabase query results locally.
/// This is the KEY component that allows the app to work without internet.
final offlineDataCacheProvider = FutureProvider<OfflineDataCache>((ref) async {
  final offline = await ref.watch(offlineManagerProvider.future);
  final encryption = ref.read(encryptionServiceProvider);
  return OfflineDataCache(offline, encryption);
});

final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  final offline = await ref.watch(offlineManagerProvider.future);
  final service = SyncService(ref.read(apiClientProvider), offline);
  service.startAutoSync();
  ref.onDispose(service.dispose);
  return service;
});

/// Pending items count for UI badges and banners.
final syncPendingCountProvider = StreamProvider<int>((ref) async* {
  final offline = await ref.watch(offlineManagerProvider.future);
  // Emit current count immediately
  yield offline.pendingCount;
  // Then poll every 30 seconds for updates
  yield* Stream.periodic(const Duration(seconds: 30), (_) => offline.pendingCount);
});

// ─── Auth ─────────────────────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repo = AuthRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// ─── Submissions Filter ───────────────────────────────────────────────────────

/// Immutable filter for submissions queries — fixes Riverpod equality issues.
class SubmissionsFilter {
  final String? status;
  final String? formId;
  final String? governorateId;
  final String? districtId;
  final int limit;
  final int offset;

  const SubmissionsFilter({
    this.status,
    this.formId,
    this.governorateId,
    this.districtId,
    this.limit = 20,
    this.offset = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubmissionsFilter &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          formId == other.formId &&
          governorateId == other.governorateId &&
          districtId == other.districtId &&
          limit == other.limit &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(status, formId, governorateId, districtId, limit, offset);

  /// Generate a cache key from filter parameters
  String get cacheKey {
    final parts = <String>['submissions'];
    if (formId != null) parts.add('form_$formId');
    if (status != null) parts.add('status_$status');
    if (governorateId != null) parts.add('gov_$governorateId');
    if (districtId != null) parts.add('dist_$districtId');
    parts.add('limit_$limit');
    parts.add('off_$offset');
    return parts.join('_');
  }
}

// ─── Data Providers (Offline-First) ───────────────────────────────────────────
//
// Strategy:
//   1. Return cached data immediately (if available)
//   2. Fetch from Supabase in background
//   3. Update cache and UI when fresh data arrives
//   4. If offline: return cached data (even stale)
//   5. If offline + no cache: show empty with retry option

final governoratesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final cache = await ref.watch(offlineDataCacheProvider.future);
  return cache.getList(
    'governorates',
    () => ref.read(databaseServiceProvider).getGovernorates(),
    maxAge: const Duration(hours: 24), // Governorates rarely change
  );
});

final districtsProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>(
  (ref, governorateId) async {
    final cache = await ref.watch(offlineDataCacheProvider.future);
    final cacheKey = governorateId != null ? 'districts_$governorateId' : 'districts_all';
    return cache.getList(
      cacheKey,
      () => ref.read(databaseServiceProvider).getDistricts(governorateId: governorateId),
      maxAge: const Duration(hours: 24),
    );
  },
);

final formsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final cache = await ref.watch(offlineDataCacheProvider.future);
  return cache.getList(
    'forms',
    () => ref.read(databaseServiceProvider).getForms(),
    maxAge: const Duration(hours: 1), // Forms can be updated by admins
  );
});

final submissionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, SubmissionsFilter>(
  (ref, filter) async {
    final cache = await ref.watch(offlineDataCacheProvider.future);
    return cache.getList(
      filter.cacheKey,
      () => ref.read(databaseServiceProvider).getSubmissions(
            formId: filter.formId,
            status: filter.status,
            governorateId: filter.governorateId,
            districtId: filter.districtId,
            limit: filter.limit,
            offset: filter.offset,
          ),
      maxAge: const Duration(minutes: 15), // Submissions change frequently
    );
  },
);

final dashboardAnalyticsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final cache = await ref.watch(offlineDataCacheProvider.future);
  return cache.getMap(
    'dashboard_analytics',
    () => ref.read(analyticsServiceProvider).getAnalytics(),
    maxAge: const Duration(minutes: 30),
  );
});

final shortagesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final cache = await ref.watch(offlineDataCacheProvider.future);
  return cache.getList(
    'shortages',
    () => ref.read(databaseServiceProvider).getShortages(),
    maxAge: const Duration(minutes: 30),
  );
});

final submissionTrendProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, days) async {
  final cache = await ref.watch(offlineDataCacheProvider.future);
  return cache.getList(
    'submission_trend_$days',
    () => ref.read(analyticsServiceProvider).getSubmissionTrend(days: days),
    maxAge: const Duration(hours: 1),
  );
});

final governorateRankingProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final cache = await ref.watch(offlineDataCacheProvider.future);
  return cache.getList(
    'governorate_ranking',
    () => ref.read(analyticsServiceProvider).getGovernorateRanking(),
    maxAge: const Duration(hours: 1),
  );
});
