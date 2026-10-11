import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_gateway.dart';
import '../core/errors/api_exception.dart';
import '../core/network/api_client.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';
import 'theme_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(authGatewayProvider),
  );
});

/// Id of the signed-in user. Data providers watch it so cached data from a
/// previous session is discarded on logout or when another account signs in.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider.select((auth) => auth.value?.id));
});

/// Why the saved session couldn't be opened at startup (no connection, the
/// server waking up or failing). The session is kept: the splash offers to
/// retry instead of sending the user back to the login.
final sessionRestoreErrorProvider =
    NotifierProvider<SessionRestoreError, ApiException?>(
      SessionRestoreError.new,
    );

class SessionRestoreError extends Notifier<ApiException?> {
  @override
  ApiException? build() => null;

  void set(ApiException? error) => state = error;
}

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<UserProfile?>>(
      AuthController.new,
    );

class AuthController extends Notifier<AsyncValue<UserProfile?>> {
  late final AuthRepository _repo = ref.read(authRepositoryProvider);

  @override
  AsyncValue<UserProfile?> build() {
    ref.read(apiClientProvider).onUnauthorized = () {
      if (state.value != null) state = const AsyncData(null);
    };
    Future.microtask(load);
    return const AsyncLoading();
  }

  Future<void> load() async {
    // Supabase restored any saved session before the app started.
    final api = ref.read(apiClientProvider);
    if (api.token == null) {
      state = const AsyncData(null);
      return;
    }
    try {
      final user = await _repo.profile();
      state = AsyncData(user);
      await ref
          .read(themeControllerProvider.notifier)
          .syncFromProfile(user.darkMode);
    } catch (error) {
      if (error is ApiException && error.statusCode != 401) {
        // Still loading (the splash), now with the reason and a retry.
        ref.read(sessionRestoreErrorProvider.notifier).set(error);
        return;
      }
      await _repo.logout();
      state = const AsyncData(null);
    }
  }

  /// Tries the saved session again from the splash.
  Future<void> retryRestore() async {
    ref.read(sessionRestoreErrorProvider.notifier).set(null);
    await load();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final session = await _repo.login(email: email, password: password);
      state = AsyncData(session.user);
      await ref
          .read(themeControllerProvider.notifier)
          .syncFromProfile(session.user.darkMode);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = const AsyncLoading();
    try {
      final session = await _repo.register(
        name: name,
        email: email,
        password: password,
      );
      state = AsyncData(session.user);
      await ref
          .read(themeControllerProvider.notifier)
          .syncFromProfile(session.user.darkMode);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> updateName(String name) async {
    final user = await _repo.updateProfile(name: name);
    state = AsyncData(user);
  }

  Future<void> changePassword(String current, String next) =>
      _repo.changePassword(current: current, next: next);

  Future<void> logout() async {
    ref.read(sessionRestoreErrorProvider.notifier).set(null);
    await _repo.logout();
    state = const AsyncData(null);
  }
}
