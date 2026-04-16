import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epi_shared/epi_shared.dart';
import 'package:epi_core/epi_core.dart';

import '../providers/app_providers.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/forms_screen.dart';
import '../screens/map_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/submission_detail_screen.dart';
import '../screens/form_fill_screen.dart';
import '../screens/forms_status_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/references_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/users_screen.dart';
import '../screens/forms_management_screen.dart';
import '../screens/references_management_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authStateProvider);

  // Minimum role level required per route
  const routeMinRole = {
    '/analytics': 1,       // everyone
    '/ai': 1,              // everyone
    '/references': 1,      // everyone can view references
  };

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(ref.watch(authRepositoryProvider).authStateChanges),
    redirect: (context, state) {
      final isLoginRoute = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';

      if (isSplash) return null;

      // If Supabase is not configured, go to login (it shows the warning)
      if (!SupabaseConfig.isConfigured) {
        if (isLoginRoute) return null;
        return '/login';
      }

      // Get auth state — may be null if stream hasn't emitted yet
      final authState = authAsync.valueOrNull;
      final isAuthenticated = authState?.isAuthenticated ?? false;

      // Not authenticated and not on login page -> redirect to login
      if (!isAuthenticated && !isLoginRoute) return '/login';
      // Authenticated and on login page -> redirect to dashboard
      if (isAuthenticated && isLoginRoute) return '/dashboard';

      // Role-based route guards
      if (isAuthenticated) {
        final userLevel = authState?.role?.hierarchyLevel ?? 0;
        final requiredLevel = routeMinRole[state.matchedLocation];

        if (requiredLevel != null && userLevel < requiredLevel) {
          return '/dashboard'; // Redirect unauthorized users
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/forms',
            builder: (context, state) => const FormsScreen(),
            routes: [
              GoRoute(
                path: 'fill/:formId',
                builder: (context, state) => FormFillScreen(
                  formId: state.pathParameters['formId']!,
                ),
              ),
              GoRoute(
                path: 'status',
                builder: (context, state) => const FormsStatusScreen(),
                routes: [
                  GoRoute(
                    path: 'submission/:id',
                    builder: (context, state) => SubmissionDetailScreen(
                      id: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/map',
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/ai',
            builder: (context, state) => const AiChatScreen(),
          ),
          GoRoute(
            path: '/references',
            builder: (context, state) => const ReferencesScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: '/forms-management',
            builder: (context, state) => const FormsManagementScreen(),
          ),
          GoRoute(
            path: '/references-management',
            builder: (context, state) => const ReferencesManagementScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Reactive connectivity provider — watches ConnectivityUtils stream
/// so the UI rebuilds when connectivity changes.
final connectivityProvider = StreamProvider<bool>((ref) {
  return ConnectivityUtils.onConnectivityChanged;
});

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _isSyncing = false;

  Future<void> _triggerManualSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final syncService = await ref.read(syncServiceProvider.future);
      final result = await syncService.sync();
      if (mounted) {
        final msg = result.synced > 0
            ? 'تمت مزامنة ${result.synced} عنصر ✅'
            : result.failed > 0
                ? 'فشلت مزامنة ${result.failed} عنصر ❌'
                : 'لا توجد عناصر للمزامنة';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Tajawal')),
            duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشلت المزامنة: $e', style: const TextStyle(fontFamily: 'Tajawal')),
            duration: const Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectivityAsync = ref.watch(connectivityProvider);
    final isOnline = connectivityAsync.valueOrNull ?? ConnectivityUtils.isOnline;
    final pendingAsync = ref.watch(syncPendingCountProvider);
    final pendingCount = pendingAsync.valueOrNull ?? 0;

    return Scaffold(
      body: Column(
        children: [
          // Offline/Online status banner
          if (!isOnline || pendingCount > 0)
            ConnectivityBanner(
              isOnline: isOnline,
              pendingCount: pendingCount,
            ),
          Expanded(child: widget.child),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ═══ Sync button (only when pending) ═══
          if (pendingCount > 0) ...[
            FloatingActionButton.small(
              heroTag: 'sync_fab',
              onPressed: _isSyncing ? null : _triggerManualSync,
              backgroundColor: isOnline ? Colors.green : Colors.orange,
              foregroundColor: Colors.white,
              elevation: 4,
              child: _isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Badge(
                      label: Text('$pendingCount', style: const TextStyle(fontSize: 10)),
                      child: const Icon(Icons.cloud_upload_rounded, size: 20),
                    ),
            ),
            const SizedBox(height: 12),
          ],
          // ═══ AI Assistant — always visible, beautiful, interactive ═══
          _AiFab(onTap: () => context.go('/ai')),
        ],
      ),
      bottomNavigationBar: EpiBottomNav(
        currentIndex: _getSelectedIndex(context),
        onTap: (index) => _onItemTapped(context, index),
      ),
      drawer: const AppDrawer(),
    );
  }

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/dashboard')) return 0;
    if (location == '/forms/status') return 2; // حالة الاستمارات
    if (location.startsWith('/forms')) return 1; // النماذج
    if (location.startsWith('/map')) return 3; // الخريطة
    if (location.startsWith('/chat')) return 4; // الشات
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/dashboard'); break;
      case 1: context.go('/forms'); break;
      case 2: context.go('/forms/status'); break;
      case 3: context.go('/map'); break;
      case 4: context.go('/chat'); break;
    }
  }
}

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  bool _isSyncingConfig = false;

  Future<void> _syncConfig() async {
    if (_isSyncingConfig) return;

    // ═══ SAFETY: Don't clear cache if offline — user will lose all data ═══
    if (!ConnectivityUtils.isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن المزامنة بدون إنترنت. اتصلك حالياً غير متاح.', style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() => _isSyncingConfig = true);

    try {
      // 1. مسح كاش النماذج والاستمارات فقط
      final cache = await ref.read(offlineDataCacheProvider.future);
      await cache.forceInvalidate('forms');

      // 2. طلب بيانات جديدة من السيرفر
      ref.invalidate(formsProvider);

      // 3. رفع الإرساليات المحفوظة محلياً
      final syncService = await ref.read(syncServiceProvider.future);
      final result = await syncService.sync();

      if (mounted) {
        final msg = result.synced > 0
            ? 'تم تحديث النماذج ومزامنة ${result.synced} إرسالية ✅'
            : 'تم جلب أحدث النماذج من السيرفر ✅';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشلت المزامنة: $e', style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingConfig = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    final authState = authAsync.valueOrNull;
    final campaign = ref.watch(campaignProvider);
    return EpiDrawer(
      currentRoute: GoRouterState.of(context).matchedLocation,
      userName: authState?.fullName ?? 'مستخدم',
      userRole: authState?.role?.nameAr,
      userRoleLevel: authState?.role?.hierarchyLevel ?? 1,
      onNavigate: (route) => context.go(route),
      onLogout: () async {
        await ref.read(authRepositoryProvider).signOut();
      },
      onSyncConfig: _syncConfig,
      isSyncingConfig: _isSyncingConfig,
      activeCampaign: campaign.value,
      onCampaignChanged: (v) {
        ref.read(campaignProvider.notifier).selectCampaign(CampaignType.fromString(v));
      },
    );
  }
}

/// Makes GoRouter rebuild when a stream emits a new value.
/// FIX: Debounce rapid emissions to prevent redirect loops and visual restarts.
class GoRouterRefreshStream extends ChangeNotifier {
  StreamSubscription? _subscription;
  DateTime? _lastNotify;
  // Minimum 500ms between router rebuilds to prevent flickering/restarts
  static const _debounceMs = 500;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    // Emit once immediately for initial state
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) {
      final now = DateTime.now();
      if (_lastNotify != null &&
          now.difference(_lastNotify!).inMilliseconds < _debounceMs) {
        return; // Skip if too frequent
      }
      _lastNotify = now;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// ═══ AI Assistant Floating Button — always visible, animated, interactive ═══
class _AiFab extends StatefulWidget {
  final VoidCallback onTap;
  const _AiFab({required this.onTap});

  @override
  State<_AiFab> createState() => _AiFabState();
}

class _AiFabState extends State<_AiFab> with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8F00), Color(0xFFFF6D00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF8F00).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}
