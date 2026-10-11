import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_gateway.dart';
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
    } catch (error, stackTrace) {
      await _repo.logout();
      state = AsyncError(error, stackTrace);
      state = const AsyncData(null);
    }
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
    await _repo.logout();
    state = const AsyncData(null);
  }
}
