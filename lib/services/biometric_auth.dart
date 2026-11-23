import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Unlocks the app with the phone's fingerprint or face (or, failing that,
/// its PIN/pattern/passcode).
abstract interface class BiometricAuth {
  /// Whether this platform can do it at all (Android and iOS).
  bool get supported;

  /// Whether the phone has a fingerprint, face or screen lock set up.
  Future<bool> isAvailable();

  /// Asks for the fingerprint/face; true when the user passed.
  Future<bool> authenticate(String reason);
}

/// Android and iOS, through local_auth.
class LocalBiometricAuth implements BiometricAuth {
  final _auth = LocalAuthentication();

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      // Not biometric-only: the phone's PIN is the fallback, as on iOS.
      return await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
    } on Exception {
      // Locked out, no lock set up, canceled by the system…: stays locked.
      return false;
    }
  }
}

/// Web and desktop: no lock.
class NoBiometricAuth implements BiometricAuth {
  const NoBiometricAuth();

  @override
  bool get supported => false;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}
