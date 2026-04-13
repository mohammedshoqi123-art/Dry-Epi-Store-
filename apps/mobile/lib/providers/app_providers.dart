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
    // Re-throw so the provider properly reflects the error state
    // instead of hanging forever
    rethrow;
  }
  ref.onDispose(manager.dispose);
  return manager;
});

final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  final offline = await ref.watch(offlineManagerProvider.future);
  final service = SyncService(ref.read(apiClientProvider), offline);
  service.startAutoSync();
  ref.onDispose(service.dispose);
  return service;
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
}

// ─── Data Providers ───────────────────────────────────────────────────────────
final governoratesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(databaseServiceProvider).getGovernorates();
});

final districtsProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>(
  (ref, governorateId) {
    return ref
        .read(databaseServiceProvider)
        .getDistricts(governorateId: governorateId);
  },
);

final formsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(databaseServiceProvider).getForms();
});

final submissionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, SubmissionsFilter>(
  (ref, filter) {
    return ref.read(databaseServiceProvider).getSubmissions(
          formId: filter.formId,
          status: filter.status,
          governorateId: filter.governorateId,
          districtId: filter.districtId,
          limit: filter.limit,
          offset: filter.offset,
        );
  },
);

final dashboardAnalyticsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(analyticsServiceProvider).getAnalytics();
});

final shortagesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(databaseServiceProvider).getShortages();
});

final submissionTrendProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, days) {
  return ref.read(analyticsServiceProvider).getSubmissionTrend(days: days);
});

final governorateRankingProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(analyticsServiceProvider).getGovernorateRanking();
});
