import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';

class MoneyPrivacyScope extends InheritedWidget {
  const MoneyPrivacyScope({
    super.key,
    required this.hidden,
    required super.child,
  });
  final bool hidden;

  static bool hiddenOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MoneyPrivacyScope>()?.hidden ??
      false;

  @override
  bool updateShouldNotify(MoneyPrivacyScope oldWidget) =>
      hidden != oldWidget.hidden;
}

extension PrivateMoney on BuildContext {
  String money(num value) => MoneyPrivacyScope.hiddenOf(this)
      ? '••••••'
      : Formatters.compactMoney(value);

  String privateMoneyText(String text) => MoneyPrivacyScope.hiddenOf(this)
      ? text.replaceAll(RegExp(r'\$\s*-?[\d.,]+'), '••••••')
      : text;
}

/// The hidden chart is not built, so its labels and tooltips cannot leak amounts.
class PrivateChart extends StatelessWidget {
  const PrivateChart({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => MoneyPrivacyScope.hiddenOf(context)
      ? const Center(child: Text('Gráfico oculto por privacidad'))
      : child;
}
