package com.void.voidlauncher

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fires when any package is installed / removed / updated.
 * A launcher must keep its app list live — we simply piggyback on the
 * Activity's debounced "appsChanged" channel event by relaunching Home.
 */
class PackageChangedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Bring the (singleTask) home activity back to front so onResume
        // triggers LauncherBridge.notifyAppsChangedMaybe().
        val home = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        runCatching { context.startActivity(home) }
    }
}
