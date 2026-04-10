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
  await manager.init();
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

final submissionsProvider = FutureProvider.family<List<Map<String, dynamic>>,
    Map<String, dynamic>>((ref, params) {
  return ref.read(databaseServiceProvider).getSubmissions(
        formId: params['form_id'],
        status: params['status'],
        governorateId: params['governorate_id'],
        districtId: params['district_id'],
        limit: params['limit'] ?? 20,
        offset: params['offset'] ?? 0,
      );
});

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
