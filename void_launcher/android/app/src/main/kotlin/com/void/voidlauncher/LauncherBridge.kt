package com.void.voidlauncher

import android.app.Activity
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Native side of the launcher bridge.
 *
 * Implements exactly what the Dart [PlatformLauncherService] calls:
 *   getApps                 → enumerate launchable apps (+ PNG icon bytes)
 *   launchApp               → start the package's launcher activity
 *   isDefaultLauncher       → resolveActivity self-check
 *   requestHomeRole         → system "set default home?" sheet (API 29+)
 *   openDefaultAppsSettings → fallback Settings screen (API < 29)
 *
 * Icons are downscaled to 128px PNGs to keep the platform channel light.
 */
class LauncherBridge : MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var activityRef: Activity? = null

    fun attach(executor: DartExecutor, activity: Activity) {
        channel = MethodChannel(executor, MainActivity.CHANNEL)
        channel.setMethodCallHandler(this)
        activityRef = activity
    }

    /** Debounced event so rapid install/uninstall bursts don't spam Flutter. */
    private val mainHandler = Handler(Looper.getMainLooper())

    fun notifyAppsChangedMaybe() {
        if (!::channel.isInitialized) return
        mainHandler.removeCallbacksAndMessages(null)
        mainHandler.postDelayed({
            activityRef?.let { runCatching { channel.invokeMethod("appsChanged", null) } }
        }, 700)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx: Context = activityRef
            ?: return result.error("no_activity", "activity not attached", null)
        when (call.method) {
            "getApps" ->
                result.success(readApps(ctx, icons = call.argument<Boolean>("icons") ?: true))

            "launchApp" -> {
                val pkg = call.argument<String>("packageName")
                if (pkg == null) result.error("bad_args", "packageName missing", null)
                else result.success(launch(ctx, pkg))
            }

            "isDefaultLauncher" -> result.success(isHomeDefault(ctx))
            "requestHomeRole" -> result.success(requestHomeRole(ctx))
            "openDefaultAppsSettings" -> result.success(openDefaultAppsSettings(ctx))
            else -> result.notImplemented()
        }
    }

    // ─────────────────────────── APP ENUMERATION ───────────────────────────

    private fun readApps(ctx: Context, icons: Boolean): List<Map<String, Any?>> {
        val pm = ctx.packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved = pm.queryIntentActivities(launcherIntent, PackageManager.MATCH_DEFAULT_ONLY)

        return resolved.mapNotNull { ri ->
            val appInfo: ApplicationInfo = ri.activityInfo.applicationInfo
            val label = ri.loadLabel(pm).toString()
            val bytes: ByteArray? =
                if (icons) runCatching { iconPng(pm, appInfo) }.getOrNull() else null
            mapOf(
                "packageName" to ri.activityInfo.packageName,
                "appName" to label,
                "isLaunchable" to true,
                "icon" to bytes,
            )
        }.sortedBy { (it["appName"] as String).lowercase() }
    }

    private fun iconPng(pm: PackageManager, ai: ApplicationInfo): ByteArray? {
        val d: Drawable = runCatching { pm.getApplicationIcon(ai) }.getOrNull() ?: return null
        val size = 128
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        d.setBounds(0, 0, size, size)
        d.draw(canvas)
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
        bmp.recycle()
        return out.toByteArray()
    }

    // ────────────────────────────── LAUNCHING ──────────────────────────────

    private fun launch(ctx: Context, pkg: String): Boolean {
        val intent = ctx.packageManager.getLaunchIntentForPackage(pkg) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return runCatching { ctx.startActivity(intent); true }.getOrDefault(false)
    }

    // ─────────────────────────── HOME ROLE LOGIC ───────────────────────────

    private fun isHomeDefault(ctx: Context): Boolean {
        val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val resolved = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.packageManager.resolveActivity(
                homeIntent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong())
            )
        } else {
            @Suppress("DEPRECATION")
            ctx.packageManager.resolveActivity(homeIntent, PackageManager.MATCH_DEFAULT_ONLY)
        }
        return resolved?.activityInfo?.packageName == ctx.packageName
    }

    /**
     * Preferred path on API 29+: RoleManager shows the native
     * "Choose your default Home app" dialog. Older devices fall through
     * to the Settings screen.
     */
    private fun requestHomeRole(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleMgr = ctx.getSystemService(Context.ROLE_SERVICE) as? RoleManager
            if (roleMgr != null && roleMgr.isRoleAvailable(RoleManager.ROLE_HOME)) {
                val intent = roleMgr.createRequestRoleIntent(RoleManager.ROLE_HOME)
                return runCatching {
                    if (ctx is Activity) {
                        ctx.startActivityForResult(intent, REQ_HOME_ROLE)
                    } else {
                        ctx.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    }
                    true
                }.getOrDefault(false)
            }
        }
        return openDefaultAppsSettings(ctx)
    }

    private fun openDefaultAppsSettings(ctx: Context): Boolean {
        val intent = Intent("android.settings.MANAGE_DEFAULT_APPS_SETTINGS").apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return runCatching { ctx.startActivity(intent); true }.getOrDefault(false)
    }

    companion object {
        const val REQ_HOME_ROLE = 4011
    }
}
