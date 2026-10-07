import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/motion.dart';
import '../providers/auth_provider.dart';
import '../screens/categories_screen.dart';
import '../screens/customize_home_screen.dart';
import '../screens/budget_planner_screen.dart';
import '../screens/goals_screen.dart';
import '../screens/recurring_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/metrics_screen.dart';
import '../screens/new_goal_full_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/subscriptions_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/wallet_screen.dart';
import '../widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Tabs and auth screens replace each other instead of stacking, so they
/// fade (like native tab bars) rather than slide in like a pushed page.
/// Pushed pages (e.g. /goals/new) keep the theme's Cupertino slide.
Page<void> _fadePage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: Motion.medium,
      reverseTransitionDuration: Motion.fast,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (Motion.reduced(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Motion.standard,
          reverseCurve: Motion.exit,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, .015),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

/// A single router for the app's lifetime. Auth changes only re-run the
/// redirect (via [refreshListenable]) instead of rebuilding the router, so the
/// current route survives login requests and theme changes.
final routerProvider = Provider<GoRouter>((ref) {
  // null = session not resolved yet (token check on startup).
  final loggedIn = ValueNotifier<bool?>(null);
  ref.listen(authControllerProvider, (_, next) {
    // Keep the current route while a login/register request is running.
    if (next.isLoading) return;
    loggedIn.value = next.hasValue && next.value != null;
  }, fireImmediately: true);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: loggedIn,
    redirect: (context, state) {
      final status = loggedIn.value;
      final path = state.uri.path;
      if (status == null) return path == '/splash' ? null : '/splash';
      if (!status) return path == '/login' ? null : '/login';
      if (path == '/login' || path == '/splash') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => _fadePage(state, const SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fadePage(state, const LoginScreen()),
      ),
      // Full-screen, above the shell (opened from Perfil).
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/customize-home',
        builder: (context, state) => const CustomizeHomeScreen(),
      ),
      GoRoute(
        path: '/recurring',
        builder: (context, state) => const RecurringScreen(),
      ),
      GoRoute(
        path: '/budget-planner',
        builder: (context, state) => const BudgetPlannerScreen(),
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/subscriptions',
        builder: (context, state) => const SubscriptionsScreen(),
      ),
      ShellRoute(
        pageBuilder: (context, state, child) =>
            _fadePage(state, AppShell(child: child)),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                _fadePage(state, const HomeScreen()),
          ),
          GoRoute(
            path: '/transactions',
            pageBuilder: (context, state) =>
                _fadePage(state, const TransactionsScreen()),
          ),
          GoRoute(
            path: '/goals',
            pageBuilder: (context, state) =>
                _fadePage(state, const GoalsScreen()),
            routes: [
              // Full-screen form: shown above the shell, without bottom nav or FAB.
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const NewGoalFullScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/metrics',
            pageBuilder: (context, state) =>
                _fadePage(state, const MetricsScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                _fadePage(state, const ProfileScreen()),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    loggedIn.dispose();
  });
  return router;
});
