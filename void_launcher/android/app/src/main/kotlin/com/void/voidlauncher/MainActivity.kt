package com.void.voidlauncher

import android.app.Activity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Host activity. Also the HOME activity (see AndroidManifest intent filter).
 *
 * Responsibilities:
 *  • attach the [LauncherBridge] MethodChannel ('void.launcher/bridge')
 *  • swallow the BACK button — a real launcher never pops itself away
 *  • notify Flutter on resume so app lists refresh after returning home
 */
class MainActivity : FlutterActivity() {

    private val bridge = LauncherBridge()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridge.attach(flutterEngine.dartExecutor.binaryMessenger, this)
    }

    @Suppress("OVERRIDE_DEPRECATION")
    override fun onBackPressed() {
        // Intentionally empty: HOME apps must ignore back at the root.
    }

    override fun onResume() {
        super.onResume()
        // When returning from an app, nudge Flutter that state may have changed.
        bridge.notifyAppsChangedMaybe()
    }

    companion object {
        const val CHANNEL = "void.launcher/bridge"
    }
}

/** Unused import guard keeps some lint setups quiet about Activity refs. */
@Suppress("unused")
private inline fun <reified T : Activity> typeRef(): Unit {}
