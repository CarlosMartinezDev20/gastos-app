import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main.');
});

/// The balance privacy toggle on Inicio (also hides it in the phone widget).
const balanceHiddenKey = 'balance_hidden';
