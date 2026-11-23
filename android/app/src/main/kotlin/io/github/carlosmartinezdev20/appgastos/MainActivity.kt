package io.github.carlosmartinezdev20.appgastos

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// A FragmentActivity: local_auth shows the fingerprint/face prompt in it.
class MainActivity : FlutterFragmentActivity() {

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    // Launcher icon per accent (lib/services/app_icon_service.dart).
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "miaunero/app_icon")
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "current" -> result.success(currentIcon())
          "set" -> {
            setIcon(call.arguments as String? ?: DEFAULT)
            result.success(null)
          }
          else -> result.notImplemented()
        }
      }
  }

  // The activity-aliases of AndroidManifest.xml: ".Launcher<name>".
  private fun alias(name: String) =
    ComponentName(this, "${MainActivity::class.java.`package`!!.name}.Launcher$name")

  private fun currentIcon(): String = ICONS.firstOrNull { name ->
    when (packageManager.getComponentEnabledSetting(alias(name))) {
      PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
      PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> name == DEFAULT
      else -> false
    }
  } ?: DEFAULT

  // Enables the new entry before disabling the old one, so the launcher never
  // has none; DONT_KILL_APP keeps the app running (the app only switches while
  // it's in the background: some launchers still close it).
  private fun setIcon(name: String) {
    if (name !in ICONS || name == currentIcon()) return
    packageManager.setComponentEnabledSetting(
      alias(name),
      PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
      PackageManager.DONT_KILL_APP,
    )
    for (other in ICONS) {
      if (other == name) continue
      packageManager.setComponentEnabledSetting(
        alias(other),
        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
        PackageManager.DONT_KILL_APP,
      )
    }
  }

  private companion object {
    const val DEFAULT = "Lima"
    val ICONS = listOf("Lima", "Menta", "Cielo", "Violeta", "Ambar")
  }
}
