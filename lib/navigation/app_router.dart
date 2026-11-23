import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/motion.dart';
import '../models/category.dart';
import '../providers/auth_provider.dart';
import '../screens/categories_screen.dart';
import '../screens/customize_home_screen.dart';
import '../screens/budget_planner_screen.dart';
import '../screens/goals_screen.dart';
import '../screens/recurring_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/password_reset_screens.dart';
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
/// only cross-fade, quickly, like iOS tab bars (no slide: the content
/// doesn't come from anywhere). Pushed pages (e.g. /goals/new) keep the
/// theme's Cupertino slide.
Page<void> _fadePage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: Motion.medium,
      reverseTransitionDuration: Motion.fast,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (Motion.reduced(context)) return child;
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Motion.standard,
            reverseCurve: Motion.exit,
          ),
          child: child,
        );
      },
    );

/// A single router for the app's lifetime. Auth changes only re-run the
/// redirect (via [refreshListenable]) instead of rebuilding the router, so the
/// current route survives login requests and theme changes.
final routerProvider = Provider<GoRouter>((ref) {
  // null = session not resolved yet (token check on startup).
  final loggedIn = ValueNotifier<bool?>(null);
  // A reset link opened the app: only the new-password page until it's set.
  final recovering = ValueNotifier(false);
  ref.listen(passwordRecoveryProvider, (_, next) {
    recovering.value = next;
  }, fireImmediately: true);
  ref.listen(authControllerProvider, (_, next) {
    // Keep the current route while a login/register request is running.
    if (next.isLoading) return;
    loggedIn.value = next.hasValue && next.value != null;
  }, fireImmediately: true);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: Listenable.merge([loggedIn, recovering]),
    redirect: (context, state) {
      final status = loggedIn.value;
      final path = state.uri.path;
      if (recovering.value) {
        return path == '/reset-password' ? null : '/reset-password';
      }
      if (status == null) return path == '/splash' ? null : '/splash';
      if (!status) {
        return path == '/login' || path == '/forgot-password' ? null : '/login';
      }
      if (const {
        '/login',
        '/splash',
        '/forgot-password',
        '/reset-password',
      }.contains(path)) {
        return '/home';
      }
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
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) =>
            ForgotPasswordScreen(initialEmail: state.extra as String?),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (context, state) =>
            _fadePage(state, const ResetPasswordScreen()),
      ),
      // Full-screen pages above the shell, opened from the tabs' headers.
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
            pageBuilder: (context, state) => _fadePage(
              state,
              BackToHome(
                child: TransactionsScreen(
                  key: ValueKey(state.uri.toString()),
                  initialType: switch (state.uri.queryParameters['type']) {
                    'income' => TransactionType.income,
                    'expense' => TransactionType.expense,
                    _ => null,
                  },
                  initialRange: _historyRange(state.uri),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/goals',
            pageBuilder: (context, state) =>
                _fadePage(state, const BackToHome(child: GoalsScreen())),
            routes: [
              // Full-screen form: shown above the shell, without bottom nav or FAB.
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => NewGoalFullScreen(
                  draft: state.extra is GoalDraft
                      ? state.extra as GoalDraft
                      : null,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/metrics',
            pageBuilder: (context, state) =>
                _fadePage(state, const BackToHome(child: MetricsScreen())),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                _fadePage(state, const BackToHome(child: ProfileScreen())),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    loggedIn.dispose();
    recovering.dispose();
  });
  return router;
});

DateTimeRange? _historyRange(Uri uri) {
  final start = DateTime.tryParse(uri.queryParameters['from'] ?? '');
  final end = DateTime.tryParse(uri.queryParameters['to'] ?? '');
  if (start == null || end == null || start.isAfter(end)) return null;
  return DateTimeRange(start: start, end: end);
}
