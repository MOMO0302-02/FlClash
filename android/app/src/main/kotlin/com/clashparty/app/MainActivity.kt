package com.clashparty.app

import com.clashparty.app.common.GlobalState
import com.clashparty.app.plugins.AppPlugin
import com.clashparty.app.plugins.ServicePlugin
import com.clashparty.app.plugins.TilePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AppPlugin())
        flutterEngine.plugins.add(ServicePlugin())
        flutterEngine.plugins.add(TilePlugin())
        ServiceState.attachFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        // **这里不再管崩溃标记。**
        //
        // 曾经在这里「正常退出就清标记」，但覆盖安装、系统回收后台、从最近任务
        // 划掉都不会走到这儿，于是每次都被判成崩溃、每次都清掉用户的订阅。
        // 现在改成由 Dart 侧在启动走完时调 `markStartupComplete()`，见
        // `GlobalState.consumeStartupFailureStreak()`。
        flutterEngine?.let(ServiceState::detachFlutterEngine)
        super.onDestroy()
    }
}
