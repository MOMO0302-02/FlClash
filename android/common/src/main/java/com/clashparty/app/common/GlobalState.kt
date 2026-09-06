package com.clashparty.app.common

import android.app.Application
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

object GlobalState : CoroutineScope by CoroutineScope(SupervisorJob() + Dispatchers.Default) {
    const val NOTIFICATION_CHANNEL = "ClashParty"
    const val NOTIFICATION_ID = 1

    val packageName: String
        get() = application.packageName

    val receiveBroadcastPermission: String
        get() = "$packageName.permission.RECEIVE_BROADCASTS"

    val application: Application
        get() = checkNotNull(appInstance) { "GlobalState is not initialized" }

    @Volatile
    private var appInstance: Application? = null

    fun init(application: Application) {
        appInstance = application
    }

    fun log(text: String) {
        Log.d("ClashParty", text)
    }

    /// 连续多少次「启动没走完」。
    ///
    /// **判定的是启动有没有走完，不是有没有正常退出。** 这两者差别很大：
    /// 「正常退出」只在用户主动关掉应用时才成立，而**覆盖安装新版本、系统回收
    /// 后台进程、从最近任务里划掉**都不会走到那一步——用「有没有正常退出」判定
    /// 会把这些全都算成崩溃。
    ///
    /// 误报不是没代价的：Dart 侧判定为崩溃后会**清掉用户当前选中的订阅**，
    /// 用户得重新选一次。
    ///
    /// 换成「启动有没有走完」之后，上面那三种情况都发生在启动早已走完、标记早已
    /// 清除之后，不会误报；而真正的「一开就崩」死循环里启动永远走不完，一定抓得到。
    ///
    /// 返回的是**连续**失败次数：Dart 侧要求满 2 次才动用户的配置，免得用户在启动
    /// 头几秒手动强杀一次就丢了订阅。真死循环十秒内就能满两次。
    fun consumeStartupFailureStreak(): Int {
        val prefs = application.getSharedPreferences(RUNTIME_PREFS, 0)
        val pending = prefs.getBoolean(KEY_STARTUP_PENDING, false)
        val streak = if (pending) prefs.getInt(KEY_STARTUP_FAILURES, 0) + 1 else 0
        prefs.edit()
            .putBoolean(KEY_STARTUP_PENDING, true)
            .putInt(KEY_STARTUP_FAILURES, streak)
            .apply()
        return streak
    }

    /// 启动走完了。由 Dart 侧在 `attach()` 结束时调用。
    ///
    /// 不调用它，下次启动就会累加一次失败——所以调用点必须在「内核起完、初始化
    /// 做完」之后，不能提前。
    fun markStartupComplete() {
        application
            .getSharedPreferences(RUNTIME_PREFS, 0)
            .edit()
            .putBoolean(KEY_STARTUP_PENDING, false)
            .putInt(KEY_STARTUP_FAILURES, 0)
            .apply()
    }

    private const val RUNTIME_PREFS = "clash_party_runtime"
    private const val KEY_STARTUP_PENDING = "startup_pending"
    private const val KEY_STARTUP_FAILURES = "startup_failures"
}
