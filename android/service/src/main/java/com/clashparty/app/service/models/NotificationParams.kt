package com.clashparty.app.service.models

data class NotificationParams(
    val title: String = "Clash Party",
    val stopText: String = "STOP",
    val onlyStatisticsProxy: Boolean = false,
    // 关掉时通知栏只留标题，不再每秒刷速率。
    val showNotificationSpeed: Boolean = true,
)
