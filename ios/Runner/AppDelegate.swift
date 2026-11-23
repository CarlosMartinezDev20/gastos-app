import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppIcon") {
      registerAppIconChannel(registrar.messenger())
    }
  }

  /// Launcher icon per accent (lib/services/app_icon_service.dart). The
  /// alternate icons are the AppIcon-<name> sets listed in the build setting
  /// ASSETCATALOG_COMPILER_ALTERNATE_APP_ICON_NAMES; nil is the default one.
  private func registerAppIconChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "miaunero/app_icon", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let app = UIApplication.shared
      switch call.method {
      case "current":
        result(app.alternateIconName.map { String($0.dropFirst("AppIcon-".count)) })
      case "set":
        let name = (call.arguments as? String).map { "AppIcon-\($0)" }
        guard app.supportsAlternateIcons, name != app.alternateIconName else {
          result(nil)
          return
        }
        // iOS shows its own "you have changed the icon" alert.
        app.setAlternateIconName(name) { error in
          if let error {
            result(FlutterError(code: "icon", message: error.localizedDescription, details: nil))
          } else {
            result(nil)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
