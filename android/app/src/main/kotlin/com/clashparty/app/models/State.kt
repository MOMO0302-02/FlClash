package com.clashparty.app.models

import com.clashparty.app.service.models.VpnOptions
import com.google.gson.annotations.SerializedName

data class SharedState(
    val startTip: String = "Starting VPN...",
    val stopTip: String = "Stopping VPN...",
    val currentProfileName: String = "Clash Party",
    val stopText: String = "Stop",
    val onlyStatisticsProxy: Boolean = false,
    // 通知栏要不要显示实时速率。默认显示，保持和以前一致。
    val showNotificationSpeed: Boolean = true,
    val vpnOptions: VpnOptions? = null,
    val setupParams: SetupParams? = null,
)

data class SetupParams(
    @SerializedName("test-url")
    val testUrl: String,
    @SerializedName("selected-map")
    val selectedMap: Map<String, String>,
)
