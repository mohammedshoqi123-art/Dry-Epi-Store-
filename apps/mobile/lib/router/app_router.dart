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
import '../screens/submissions_screen.dart';
import '../screens/map_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/submission_detail_screen.dart';
import '../screens/form_fill_screen.dart';
import '../screens/forms_status_screen.dart';
import '../screens/notifications_screen.dart';
import 'package:epi_features/epi_features.dart';
import '../screens/references_screen.dart';
import '../screens/chat_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authStateProvider);

  // Minimum role level required per route
  const routeMinRole = {
    '/admin': 5,           // admin only
    '/admin/dashboard': 5, // admin only
    '/admin/users': 5,     // admin only for user management
    '/admin/audit': 4,     // central+
    '/admin/forms': 4,     // central+ for form management
    '/admin/references': 5,// admin only for reference management
    '/admin/pages': 5,    // admin only for page management
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
              ),
            ],
          ),
          GoRoute(
            path: '/submissions',
            builder: (context, state) => const SubmissionsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => SubmissionDetailScreen(
                  id: state.pathParameters['id']!,
                ),
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
            path: '/admin',
            builder: (context, state) => const AdminDashboard(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const UserManagementScreen(),
          ),
          GoRoute(
            path: '/admin/forms',
            builder: (context, state) => const FormsManagementScreen(),
          ),
          GoRoute(
            path: '/admin/audit',
            builder: (context, state) => const AuditLogScreen(),
          ),
          GoRoute(
            path: '/admin/references',
            builder: (context, state) => const ReferencesManagementScreen(),
          ),
          GoRoute(
            path: '/admin/pages',
            builder: (context, state) => const PagesManagementScreen(),
          ),
          GoRoute(
            path: '/admin/chat',
            builder: (context, state) => const InternalChatScreen(),
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
      floatingActionButton: pendingCount > 0
          ? FloatingActionButton.extended(
              onPressed: _isSyncing ? null : _triggerManualSync,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync, size: 20),
              label: Text(
                _isSyncing ? 'جاري المزامنة...' : 'مزامنة ($pendingCount)',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
              ),
              backgroundColor: isOnline ? Colors.green : Colors.orange,
            )
          : null,
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
    if (location.startsWith('/forms')) return 1;
    if (location.startsWith('/map')) return 2;
    if (location.startsWith('/analytics')) return 3;
    if (location.startsWith('/ai')) return 4;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/dashboard'); break;
      case 1: context.go('/forms'); break;
      case 2: context.go('/map'); break;
      case 3: context.go('/analytics'); break;
      case 4: context.go('/ai'); break;
    }
  }
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final authState = authAsync.valueOrNull;
    return EpiDrawer(
      currentRoute: GoRouterState.of(context).matchedLocation,
      userName: authState?.fullName ?? 'مستخدم',
      userRole: authState?.role?.nameAr,
      userRoleLevel: authState?.role?.hierarchyLevel ?? 1,
      onNavigate: (route) => context.go(route),
      onLogout: () async {
        await ref.read(authRepositoryProvider).signOut();
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
