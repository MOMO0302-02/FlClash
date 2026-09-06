package com.clashparty.app.plugins

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.ActivityManager
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.PersistableBundle
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.ContextCompat.getSystemService
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.net.toUri
import com.clashparty.app.common.Components
import com.clashparty.app.common.GlobalState
import com.clashparty.app.getPackageIconPath
import com.clashparty.app.packages.PackageResolver
import com.clashparty.app.showToast
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class AppPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private var activity: Activity? = null

    private lateinit var channel: MethodChannel

    private lateinit var scope: CoroutineScope

    private var vpnPrepareCallback: ((Boolean) -> Unit)? = null

    private var requestNotificationCallback: ((Boolean) -> Unit)? = null

    private var isRequestingNotificationPermission = false

    private val gson = Gson()

    private val packageResolver by lazy {
        PackageResolver(
            GlobalState.application.packageManager,
            GlobalState.application.packageName,
        )
    }

    private var skipNotificationPermissionRequest = false

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "moveTaskToBack" -> {
                activity?.moveTaskToBack(true)
                result.success(true)
            }

            "updateExcludeFromRecents" -> {
                val value = call.argument<Boolean>("value")
                updateExcludeFromRecents(value)
                result.success(true)
            }

            // Dart 侧仍会在启动时调一次。快捷方式本身已经由清单静态声明，
            // 这里只是再兜一次「清掉老版本的动态快捷方式」（幂等）。
            "initShortcuts" -> {
                clearLegacyDynamicShortcuts()
                result.success(true)
            }

            "getPackages" -> {
                scope.launch(Dispatchers.IO) {
                    result.success(gson.toJson(packageResolver.installedPackages))
                }
            }

            "getChinaPackageNames" -> {
                scope.launch(Dispatchers.IO) {
                    result.success(gson.toJson(packageResolver.getChinaPackageNames()))
                }
            }

            "getPackageIcon" -> {
                handleGetPackageIcon(call, result)
            }

            "tip" -> {
                val message = call.argument<String>("message")
                GlobalState.application.showToast(message)
                result.success(true)
            }

            "setSensitiveClipboard" -> {
                val text = call.argument<String>("text") ?: ""
                result.success(setSensitiveClipboard(text))
            }

            "isBatteryOptimizationDisabled" -> {
                result.success(isBatteryOptimizationDisabled())
            }

            "openBatteryOptimizationSettings" -> {
                result.success(openBatteryOptimizationSettings())
            }

            "openAppSettings" -> {
                result.success(openAppSettings())
            }

            "openVpnSettings" -> {
                result.success(openVpnSettings())
            }

            "consumeStartupFailureStreak" -> {
                result.success(GlobalState.consumeStartupFailureStreak())
            }

            "markStartupComplete" -> {
                GlobalState.markStartupComplete()
                result.success(true)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun handleGetPackageIcon(call: MethodCall, result: Result) {
        scope.launch {
            val packageName = call.argument<String>("packageName")
            if (packageName == null) {
                result.success("")
                return@launch
            }
            val path = GlobalState.application.packageManager.getPackageIconPath(packageName)
            result.success(path)
        }
    }

    /**
     * 清掉老版本留下的动态快捷方式。
     *
     * 长按应用图标的快捷方式**已经改成清单里的静态快捷方式**（res/xml/shortcuts.xml）：
     * 装完不用先把应用打开一次就能长按出来，而且是启动 / 暂停 / 切换三条，
     * 不再只有一条「切换」；文案走安卓字符串资源，因为系统在应用还没跑起来时就要读它。
     *
     * 老版本用 setDynamicShortcuts 建过一条 id 叫 "toggle" 的动态快捷方式，升级之后
     * 它还留在系统里，会和新的那条「切换」并排出现（老的没有长文案、图标也是旧的）。
     * removeAllDynamicShortcuts 只动动态那部分，碰不到清单里的三条。
     *
     * 幂等，重复调用无副作用；API 25 以下 ShortcutManagerCompat 内部直接返回。
     */
    private fun clearLegacyDynamicShortcuts() {
        runCatching {
            ShortcutManagerCompat.removeAllDynamicShortcuts(GlobalState.application)
        }.onFailure {
            GlobalState.log("removeAllDynamicShortcuts failed: $it")
        }
    }

    /**
     * 把文本放进剪贴板，并在 Android 13+（TIRAMISU）上打上「敏感内容」标记。
     *
     * 订阅链接里带 token。EXTRA_IS_SENSITIVE 让系统在剪贴板复制预览里不显示明文，
     * 输入法与剪贴板历史也据此不去记录内容。API 33 以下没有这个标记，退回普通复制。
     * 返回是否设置成功；失败时 Dart 侧会回退到普通 Clipboard。
     */
    private fun setSensitiveClipboard(text: String): Boolean {
        return try {
            val clipboard = getSystemService(GlobalState.application, ClipboardManager::class.java)
                ?: return false
            val clip = ClipData.newPlainText(GlobalState.application.packageName, text)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                clip.description.extras = PersistableBundle().apply {
                    putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
                }
            }
            clipboard.setPrimaryClip(clip)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun isBatteryOptimizationDisabled(): Boolean {
        val powerManager = getSystemService(GlobalState.application, PowerManager::class.java)
        return powerManager?.isIgnoringBatteryOptimizations(GlobalState.application.packageName)
            ?: false
    }

    @SuppressLint("BatteryLife")
    private fun openBatteryOptimizationSettings(): Boolean {
        // VPN continuity is the user-requested core function, so the direct exemption is intentional.
        val activity = activity ?: return false
        return try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = "package:${GlobalState.application.packageName}".toUri()
            }
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openAppSettings(): Boolean {
        val activity = activity ?: return false
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = "package:${GlobalState.application.packageName}".toUri()
            }
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * 跳到系统的「VPN」设置页，用户在那里点应用旁边的齿轮才能打开「始终开启 VPN」。
     *
     * 安卓**没有**能直接落到「始终开启」那个开关上的公开入口，只能送到 VPN 列表页；
     * 更深的那一层要么是隐藏 API、要么各家 ROM 路径不一样，硬跳的下场是崩或者跳到
     * 一个空白页。所以这里只跳到列表，跳不过去就返回 false，由界面改成给一句路径提示。
     *
     * action 直接写字符串而不用 Settings.ACTION_VPN_SETTINGS：那个常量 API 24 才有，
     * 本项目 minSdk 是 24。字符串在老系统上解析不到会走到 catch，不会崩。
     */
    private fun openVpnSettings(): Boolean {
        val activity = activity ?: return false
        return try {
            activity.startActivity(Intent("android.settings.VPN_SETTINGS"))
            true
        } catch (_: Exception) {
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun updateExcludeFromRecents(value: Boolean?) {
        val am = getSystemService(GlobalState.application, ActivityManager::class.java)
        val task = am?.appTasks?.firstOrNull {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                it.taskInfo.taskId == activity?.taskId
            } else {
                it.taskInfo.id == activity?.taskId
            }
        }
        task?.setExcludeFromRecents(value ?: false)
    }

    fun requestNotificationPermission(callback: (Boolean) -> Unit) {
        requestNotificationCallback?.invoke(false)
        requestNotificationCallback = callback
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val permission = ContextCompat.checkSelfPermission(
                GlobalState.application,
                Manifest.permission.POST_NOTIFICATIONS,
            )
            if (permission == PackageManager.PERMISSION_GRANTED || skipNotificationPermissionRequest) {
                invokeRequestNotificationCallback(true)
                return
            }
            if (isRequestingNotificationPermission) {
                return
            }
            isRequestingNotificationPermission = true
            activity?.let {
                ActivityCompat.requestPermissions(
                    it,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST_CODE,
                )
            } ?: invokeRequestNotificationCallback(true)
            return
        }
        invokeRequestNotificationCallback(true)
    }

    private fun invokeRequestNotificationCallback(shouldStart: Boolean) {
        isRequestingNotificationPermission = false
        requestNotificationCallback?.invoke(shouldStart)
        requestNotificationCallback = null
    }

    fun prepareVpn(needPrepare: Boolean, callback: (Boolean) -> Unit) {
        invokeVpnPrepareCallback(false)
        vpnPrepareCallback = callback
        if (!needPrepare) {
            invokeVpnPrepareCallback(true)
            return
        }
        val intent = VpnService.prepare(GlobalState.application)
        if (intent != null) {
            val activity = activity
            if (activity == null) {
                invokeVpnPrepareCallback(false)
            } else {
                @Suppress("DEPRECATION")
                activity.startActivityForResult(intent, VPN_PERMISSION_REQUEST_CODE)
            }
            return
        }
        invokeVpnPrepareCallback(true)
    }

    fun cancelVpnPreparation(callback: (Boolean) -> Unit) {
        if (vpnPrepareCallback === callback) {
            vpnPrepareCallback = null
        }
    }

    private fun invokeVpnPrepareCallback(granted: Boolean) {
        vpnPrepareCallback?.invoke(granted)
        vpnPrepareCallback = null
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        channel =
            MethodChannel(flutterPluginBinding.binaryMessenger, "${Components.PACKAGE_NAME}/app")
        channel.setMethodCallHandler(this)
        // 这里就做掉，不等 Dart 那边的 initShortcuts 调过来。
        // Dart 那个调用挂在 application.dart 启动链的最后一环（`await globalState.attach()`
        // 之后），而 attach() 里包含启动内核等一串 await——模拟器上实测跑到界面都出来了、
        // 这一环仍然没轮到。清理旧快捷方式不该依赖那条链子。
        clearLegacyDynamicShortcuts()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
        invokeVpnPrepareCallback(false)
        invokeRequestNotificationCallback(false)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attachToActivity(binding)
    }

    private fun attachToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(::onActivityResult)
        binding.addRequestPermissionsResultListener(::onRequestPermissionsResultListener)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attachToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        channel.invokeMethod("exit", null)
        activity = null
        invokeVpnPrepareCallback(false)
        invokeRequestNotificationCallback(false)
    }

    private fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != VPN_PERMISSION_REQUEST_CODE) {
            return false
        }
        invokeVpnPrepareCallback(resultCode == Activity.RESULT_OK)
        return true
    }

    private fun onRequestPermissionsResultListener(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST_CODE) {
            return false
        }
        skipNotificationPermissionRequest = true
        invokeRequestNotificationCallback(true)
        return true
    }

    private companion object {
        const val VPN_PERMISSION_REQUEST_CODE = 1001
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1002
    }
}
