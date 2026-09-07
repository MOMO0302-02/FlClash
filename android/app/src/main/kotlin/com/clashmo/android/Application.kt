package com.clashmo.android

import android.app.Application
import android.content.Context
import com.clashmo.android.common.GlobalState

class Application : Application() {

    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        GlobalState.init(this)
    }
}
