package com.clashparty.app

import android.app.Activity
import android.os.Bundle
import androidx.core.content.pm.ShortcutManagerCompat
import com.clashparty.app.common.GlobalState
import com.clashparty.app.common.QuickAction
import com.clashparty.app.common.action
import kotlinx.coroutines.launch

class QuickActionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        when (intent.action) {
            QuickAction.START.action -> GlobalState.launch { ServiceState.handleStartAction() }
            QuickAction.STOP.action -> GlobalState.launch { ServiceState.handleStopAction() }
            QuickAction.TOGGLE.action -> {
                ShortcutManagerCompat.reportShortcutUsed(this, SHORTCUT_ID)
                GlobalState.launch { ServiceState.handleToggleAction() }
            }
        }
        finish()
    }

    private companion object {
        /**
         * 长按图标那条「切换」快捷方式的 id，必须和 res/xml/shortcuts.xml 里写的一致。
         *
         * 不叫 "toggle" 是有原因的：老版本用 setDynamicShortcuts 建过一条 id 就叫
         * "toggle" 的动态快捷方式，升级时系统**不会**让清单里的同 id 快捷方式顶掉它
         * （模拟器实测：日志写着 3 条清单快捷方式，实际只生效了 start / stop 两条）。
         * 换个 id 才能让三条都稳稳地出来。
         */
        const val SHORTCUT_ID = "toggle_vpn"
    }
}
