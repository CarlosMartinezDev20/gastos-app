import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_gateway.dart';
import '../services/biometric_auth.dart';
import 'storage_provider.dart';

/// Overridden in tests (no fingerprint there).
final biometricAuthProvider = Provider<BiometricAuth>((ref) {
  final auth = LocalBiometricAuth();
  return auth.supported ? auth : const NoBiometricAuth();
});

const appLockKey = 'app_lock';

/// How long the app may stay in the background before it locks again.
const appLockGrace = Duration(seconds: 60);

/// The Perfil switch "Bloqueo con huella o rostro" (off until turned on;
/// per device).
final appLockEnabledProvider = NotifierProvider<AppLockSetting, bool>(
  AppLockSetting.new,
);

class AppLockSetting extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(biometricAuthProvider).supported &&
      (ref.read(sharedPreferencesProvider).getBool(appLockKey) ?? false);

  /// Turning it on asks for the fingerprint/face first, so nobody locks
  /// themselves out with a lock that doesn't work. Returns the new value.
  Future<bool> set(bool enabled) async {
    if (enabled) {
      final auth = ref.read(biometricAuthProvider);
      enabled =
          await auth.isAvailable() &&
          await auth.authenticate('Confirma para activar el bloqueo');
    }
    state = enabled;
    await ref.read(sharedPreferencesProvider).setBool(appLockKey, enabled);
    return enabled;
  }
}

/// Whether the app is locked now. It starts locked when the lock is on and
/// a session was saved (opening the app); signing in with the password
/// doesn't ask again.
final appLockProvider = NotifierProvider<AppLockController, bool>(
  AppLockController.new,
);

class AppLockController extends Notifier<bool> {
  bool _authenticating = false;

  @override
  bool build() =>
      ref.read(appLockEnabledProvider) &&
      ref.read(authGatewayProvider).accessToken != null;

  /// Whether the system prompt is showing (the app may go to the background
  /// behind it; that must not lock it again).
  bool get authenticating => _authenticating;

  void lock() {
    if (ref.read(appLockEnabledProvider)) state = true;
  }

  Future<void> unlock() async {
    if (!state || _authenticating) return;
    _authenticating = true;
    try {
      final ok = await ref
          .read(biometricAuthProvider)
          .authenticate('Desbloquea Miaunero');
      if (ok) state = false;
    } finally {
      _authenticating = false;
    }
  }

  /// After signing out: the next account starts unlocked.
  void reset() => state = false;
}
