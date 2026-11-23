import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_provider.dart';

final moneyPrivacyProvider = NotifierProvider<MoneyPrivacyController, bool>(
  MoneyPrivacyController.new,
);

class MoneyPrivacyController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(balanceHiddenKey) ?? false;

  Future<void> toggle() async {
    state = !state;
    await ref.read(sharedPreferencesProvider).setBool(balanceHiddenKey, state);
  }
}
