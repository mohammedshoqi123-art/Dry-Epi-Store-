import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dry_shared/dry_shared.dart';
import 'package:dry_core/dry_core.dart';

import '../providers/app_providers.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/stock_screen.dart';
import '../screens/movements_screen.dart';
import '../screens/warehouses_screen.dart';
import '../screens/alerts_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/notifications_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(ref.watch(authRepositoryProvider).authStateChanges),
    redirect: (context, state) {
      final isLoginRoute = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';
      if (isSplash) return null;
      if (!SupabaseConfig.isConfigured) { if (isLoginRoute) return null; return '/login'; }
      final authState = authAsync.valueOrNull;
      final isAuthenticated = authState?.isAuthenticated ?? false;
      if (!isAuthenticated && !isLoginRoute) return '/login';
      if (isAuthenticated && isLoginRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/stock', builder: (context, state) => const StockScreen()),
          GoRoute(path: '/movements', builder: (context, state) => const MovementsScreen()),
          GoRoute(path: '/warehouses', builder: (context, state) => const WarehousesScreen()),
          GoRoute(path: '/alerts', builder: (context, state) => const AlertsScreen()),
          GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
          GoRoute(path: '/ai', builder: (context, state) => const AiChatScreen()),
          GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
          GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ],
      ),
    ],
  );
});

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _getSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(context, index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.inventory_2_rounded), label: 'المخزون'),
          NavigationDestination(icon: Icon(Icons.swap_horiz_rounded), label: 'الحركات'),
          NavigationDestination(icon: Icon(Icons.notifications_rounded), label: 'التنبيهات'),
          NavigationDestination(icon: Icon(Icons.analytics_rounded), label: 'التقارير'),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => context.go('/ai'),
        backgroundColor: const Color(0xFFFF8F00), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white)),
    );
  }

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/stock')) return 1;
    if (location.startsWith('/movements')) return 2;
    if (location.startsWith('/alerts')) return 3;
    if (location.startsWith('/reports')) return 4;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/dashboard'); break;
      case 1: context.go('/stock'); break;
      case 2: context.go('/movements'); break;
      case 3: context.go('/alerts'); break;
      case 4: context.go('/reports'); break;
    }
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  StreamSubscription? _subscription;
  DateTime? _lastNotify;
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) {
      final now = DateTime.now();
      if (_lastNotify != null && now.difference(_lastNotify!).inMilliseconds < 500) return;
      _lastNotify = now;
      notifyListeners();
    });
  }
  @override
  void dispose() { _subscription?.cancel(); super.dispose(); }
}
