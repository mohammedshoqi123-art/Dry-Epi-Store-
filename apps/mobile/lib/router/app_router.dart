import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epi_shared/epi_shared.dart';

import '../providers/app_providers.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/forms_screen.dart';
import '../screens/submissions_screen.dart';
import '../screens/map_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/admin/users_screen.dart';
import '../screens/admin/audit_screen.dart';
import '../screens/admin/forms_management_screen.dart';
import '../screens/submission_detail_screen.dart';
import '../screens/form_fill_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authStateProvider);

  // Minimum role level required per route
  const routeMinRole = {
    '/admin/users': 4,   // central+
    '/admin/audit': 4,   // central+
    '/admin/forms': 4,   // central+ (admin only for modifications)
    '/analytics': 3,     // governorate+
    '/ai': 3,            // governorate+
  };

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoginRoute = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';

      if (isSplash) return null;

      final authState = authAsync.valueOrNull;
      final isAuthenticated = authState?.isAuthenticated ?? false;

      if (!isAuthenticated && !isLoginRoute) return '/login';
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
            path: '/admin/users',
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: '/admin/forms',
            builder: (context, state) => const AdminFormsScreen(),
          ),
          GoRoute(
            path: '/admin/audit',
            builder: (context, state) => const AuditScreen(),
          ),
        ],
      ),
    ],
  );
});

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
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
    );
  }
}
