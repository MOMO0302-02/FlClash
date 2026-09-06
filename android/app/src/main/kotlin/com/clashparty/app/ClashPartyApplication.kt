package com.clashparty.app

import android.app.Application
import android.content.Context
import com.clashparty.app.common.GlobalState

class ClashPartyApplication : Application() {
    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        GlobalState.init(this)
    }
}
