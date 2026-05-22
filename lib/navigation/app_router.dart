import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/goals_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/metrics_screen.dart';
import '../screens/new_goal_full_screen.dart';
import '../screens/profile_screen.dart';
import '../widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authStatus = ref.watch(
    authControllerProvider.select((auth) {
      if (auth.isLoading) return null;
      return auth.hasValue && auth.value != null;
    }),
  );
  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      if (authStatus == null) return null;
      final loggedIn = authStatus;
      final loggingIn = state.uri.path == '/login';
      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn && loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/goals',
            builder: (context, state) => const GoalsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const NewGoalFullScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/metrics',
            builder: (context, state) => const MetricsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});
