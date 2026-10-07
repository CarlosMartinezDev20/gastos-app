import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../core/utils/phone_widget.dart';

/// Sends data to the native home-screen widget (Android and iOS only).
class PhoneWidgetService {
  const PhoneWidgetService();

  /// App Group shared by the app and the iOS widget extension.
  static const appGroupId = 'group.com.example.appgastos';
  static const androidProvider = 'com.example.appgastos.FinanceWidgetProvider';
  static const iOSKind = 'FinanceWidget';

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Only Android launchers can add a widget from inside the app.
  bool get canPin => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> publish(PhoneWidgetPayload payload) async {
    if (!supported) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }
      for (final MapEntry(:key, :value) in payload.toData().entries) {
        await HomeWidget.saveWidgetData<Object>(key, value);
      }
      await HomeWidget.updateWidget(
        qualifiedAndroidName: androidProvider,
        iOSName: iOSKind,
      );
    } on PlatformException catch (e) {
      debugPrint('No se pudo actualizar el widget: $e');
    } on MissingPluginException {
      // Tests and platforms without the plugin.
    }
  }

  /// Asks the launcher to add the widget. False when it can't.
  Future<bool> requestPin() async {
    if (!canPin) return false;
    try {
      if (await HomeWidget.isRequestPinWidgetSupported() != true) return false;
      await HomeWidget.requestPinWidget(qualifiedAndroidName: androidProvider);
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
