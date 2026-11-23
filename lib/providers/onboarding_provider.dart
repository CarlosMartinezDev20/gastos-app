import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/onboarding_tour.dart';
import 'auth_provider.dart';
import 'storage_provider.dart';

/// Whether Inicio should start the first-run tour as soon as it's shown:
/// set from Perfil ("Ver recorrido de la app"), which then goes to Inicio.
/// Also remembers, per user, that the tour already ran.
final onboardingTourProvider = NotifierProvider<OnboardingTour, bool>(
  OnboardingTour.new,
);

class OnboardingTour extends Notifier<bool> {
  @override
  bool build() {
    // Another account on this device gets its own tour.
    ref.watch(currentUserIdProvider);
    return false;
  }

  String? get _key => switch (ref.read(currentUserIdProvider)) {
    final id? => onboardingDoneKey(id),
    null => null,
  };

  /// The tour already ran for the signed-in user on this device.
  bool get seen => switch (_key) {
    final key? => ref.read(sharedPreferencesProvider).getBool(key) ?? false,
    null => true,
  };

  /// Asks Inicio to show the tour again.
  void request() => state = true;

  /// The tour is on screen: the request is done and it won't start again
  /// on its own.
  void started() {
    state = false;
    if (_key case final key?) {
      ref.read(sharedPreferencesProvider).setBool(key, true);
    }
  }
}
