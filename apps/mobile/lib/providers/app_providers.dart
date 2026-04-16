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

/// ═══ FIX: Robust offline manager initialization with connectivity bridge ═══
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

  // ═══ FIX: Set initial connectivity from ConnectivityUtils ═══
  // Without this, OfflineManager defaults to isOnline=true which may be wrong
  manager.updateConnectivity(ConnectivityUtils.isOnline);

  // ═══ FIX: Bridge ConnectivityUtils updates to OfflineManager ═══
  // This ensures OfflineManager always has the correct connectivity state.
  StreamSubscription? connSub;
  try {
    connSub = ConnectivityUtils.onConnectivityChanged.listen(
      (online) {
        manager.updateConnectivity(online);
      },
      onError: (e) {
        debugPrint('[offlineManagerProvider] Connectivity bridge error: $e');
      },
    );
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
final offlineDataCacheProvider = FutureProvider<OfflineDataCache>((ref) async {
  final offline = await ref.watch(offlineManagerProvider.future);
  final encryption = ref.read(encryptionServiceProvider);
  return OfflineDataCache(offline, encryption);
});

/// ═══ FIX: Reliable sync service with proper initialization chain ═══
final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  final offline = await ref.watch(offlineManagerProvider.future);
  final service = SyncService(ref.read(apiClientProvider), offline);

  // ═══ Connect data cache for reconnect invalidation ═══
  // When internet returns, SyncService will clear all caches
  // so fresh data is fetched from server
  try {
    final cache = await ref.watch(offlineDataCacheProvider.future);
    service.setDataCache(cache);
  } catch (e) {
    debugPrint('[syncServiceProvider] Could not set data cache: $e');
  }

  // ═══ Start auto-sync immediately ═══
  service.startAutoSync();

  ref.onDispose(service.dispose);
  return service;
});

/// ═══ FIX: Manual sync trigger — used by UI pull-to-refresh and sync button ═══
final manualSyncProvider = Provider<Future<SyncCycleResult> Function()>((ref) {
  return () async {
    final syncService = await ref.read(syncServiceProvider.future);
    return syncService.sync();
  };
});

/// ═══ Force-refresh helper: clears specific cache key then invalidates provider ═══
/// Use for pull-to-refresh to ensure fresh data from server.
final forceRefreshProvider =
    Provider<Future<void> Function(String cacheKey)>((ref) {
  return (String cacheKey) async {
    try {
      final cache = await ref.read(offlineDataCacheProvider.future);
      await cache.forceInvalidate(cacheKey);
    } catch (e) {
      debugPrint(
          '[forceRefreshProvider] Error clearing cache for $cacheKey: $e');
    }
  };
});

/// Pending items count for UI badges and banners.
/// ═══ FIX: Use stream-based polling with longer interval to reduce PBKDF2 overhead ═══
final syncPendingCountProvider = StreamProvider<int>((ref) async* {
  final offline = await ref.watch(offlineManagerProvider.future);
  // Emit current count immediately
  yield offline.pendingCount;
  // ═══ FIX: Poll every 60s instead of 30s — reduces PBKDF2 decrypt overhead ═══
  // The count is not time-critical; 60s is responsive enough for UI badges
  yield* Stream.periodic(
      const Duration(seconds: 60), (_) => offline.pendingCount);
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
  final String? campaignType;
  final int limit;
  final int offset;

  const SubmissionsFilter({
    this.status,
    this.formId,
    this.governorateId,
    this.districtId,
    this.campaignType,
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
          campaignType == other.campaignType &&
          limit == other.limit &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(
      status, formId, governorateId, districtId, campaignType, limit, offset);

  String get cacheKey {
    final parts = <String>['submissions'];
    if (campaignType != null) parts.add('camp_$campaignType');
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

final governoratesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final cache = await ref.watch(offlineDataCacheProvider.future);
  return cache.getList(
    'governorates',
    () => ref.read(databaseServiceProvider).getGovernorates(),
    maxAge: const Duration(hours: 24),
  );
});

final districtsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String?>(
  (ref, governorateId) async {
    final cache = await ref.watch(offlineDataCacheProvider.future);
    final cacheKey =
        governorateId != null ? 'districts_$governorateId' : 'districts_all';
    return cache.getList(
      cacheKey,
      () => ref
          .read(databaseServiceProvider)
          .getDistricts(governorateId: governorateId),
      maxAge: const Duration(hours: 24),
    );
  },
);

final healthFacilitiesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String?>(
  (ref, districtId) async {
    if (districtId == null) return [];
    final cache = await ref.watch(offlineDataCacheProvider.future);
    return cache.getList(
      'facilities_$districtId',
      () => ref
          .read(databaseServiceProvider)
          .getHealthFacilities(districtId: districtId),
      maxAge: const Duration(hours: 24),
    );
  },
);

// ─── Campaign / Activity Selection ──────────────────────────────────────────

/// Persisted campaign selection — stored in Supabase profiles table,
/// cached locally in Hive for offline access.
class CampaignNotifier extends StateNotifier<CampaignType> {
  final Ref _ref;

  CampaignNotifier(this._ref) : super(CampaignType.polioCampaign) {
    _load();
  }

  Future<void> _load() async {
    try {
      final cache = await _ref.read(offlineDataCacheProvider.future);
      final cached = await cache.getMap(
        'active_campaign',
        () async {
          final db = _ref.read(databaseServiceProvider);
          final result = await db.getActiveCampaign();
          return {'campaign': result};
        },
        maxAge: const Duration(days: 30),
      );
      state = CampaignType.fromString(
          cached['campaign'] as String? ?? 'polio_campaign');
    } catch (_) {
      // Default to polio campaign if loading fails
    }
  }

  Future<void> selectCampaign(CampaignType campaign) async {
    if (campaign == state) return;
    state = campaign;
    try {
      // Save to Supabase
      final db = _ref.read(databaseServiceProvider);
      await db.setActiveCampaign(campaign.value);
      // Invalidate ALL campaign-dependent caches
      final cache = await _ref.read(offlineDataCacheProvider.future);
      for (final c in CampaignType.values) {
        await cache.invalidate('forms_${c.value}');
      }
      // Invalidate all providers that depend on campaign
      _ref.invalidate(formsProvider);
      _ref.invalidate(dashboardAnalyticsProvider);
      _ref.invalidate(submissionTrendProvider);
      _ref.invalidate(governorateRankingProvider);
      _ref.invalidate(shortagesProvider);
    } catch (e) {
      debugPrint('[CampaignNotifier] Save failed: $e');
    }
  }
}

final campaignProvider = StateNotifierProvider<CampaignNotifier, CampaignType>(
  (ref) => CampaignNotifier(ref),
);

// ─── Forms (filtered by active campaign) ────────────────────────────────────

final formsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final campaign = ref.watch(campaignProvider);
  final cache = await ref.watch(offlineDataCacheProvider.future);
  return cache.getList(
    'forms_${campaign.value}',
    () => ref
        .read(databaseServiceProvider)
        .getForms(campaignType: campaign.value),
    maxAge: const Duration(hours: 24), // Forms change rarely — cache 24h
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
            campaignType: filter.campaignType,
            limit: filter.limit,
            offset: filter.offset,
          ),
      maxAge:
          const Duration(hours: 2), // Submissions cached 2h for offline access
    );
  },
);

/// Analytics filter for passing governorate/district/date/form filters to the provider.
class AnalyticsFilter {
  final String? governorateId;
  final String? districtId;
  final String? formId;
  final String? campaignType;
  final DateTime? startDate;
  final DateTime? endDate;

  const AnalyticsFilter({
    this.governorateId,
    this.districtId,
    this.formId,
    this.campaignType,
    this.startDate,
    this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalyticsFilter &&
          runtimeType == other.runtimeType &&
          governorateId == other.governorateId &&
          districtId == other.districtId &&
          formId == other.formId &&
          campaignType == other.campaignType &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => Object.hash(
      governorateId, districtId, formId, campaignType, startDate, endDate);

  String get cacheKey {
    final parts = ['dashboard_analytics'];
    if (campaignType != null) parts.add('camp_$campaignType');
    if (governorateId != null) parts.add('gov_$governorateId');
    if (districtId != null) parts.add('dist_$districtId');
    if (formId != null) parts.add('form_$formId');
    if (startDate != null) parts.add('from_${startDate!.toIso8601String()}');
    if (endDate != null) parts.add('to_${endDate!.toIso8601String()}');
    return parts.join('_');
  }
}

final dashboardAnalyticsProvider =
    FutureProvider.family<Map<String, dynamic>, AnalyticsFilter>(
  (ref, filter) async {
    final cache = await ref.watch(offlineDataCacheProvider.future);
    return cache.getMap(
      filter.cacheKey,
      () => ref.read(analyticsServiceProvider).getAnalytics(
            governorateId: filter.governorateId,
            districtId: filter.districtId,
            formId: filter.formId,
            campaignType: filter.campaignType,
            startDate: filter.startDate,
            endDate: filter.endDate,
          ),
      maxAge: const Duration(hours: 2), // Analytics cached 2h for offline
    );
  },
);

final shortagesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final cache = await ref.watch(offlineDataCacheProvider.future);
  return cache.getList(
    'shortages',
    () => ref.read(databaseServiceProvider).getShortages(),
    maxAge: const Duration(hours: 2),
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
