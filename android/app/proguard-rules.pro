
-keep class com.clashparty.app.models.** { *; }

-keep class com.clashparty.app.service.models.** { *; }

# 内核的 JNI 桥接层是按「字符串」找类和方法的
# （core.cpp 里 find_class("com/clashparty/app/core/TunInterface")、
#  find_method(..., "resolverProcess", ...) 等）。
# release 开了代码压缩，一旦被改名，编译期一点问题都看不出来，
# 运行时直接 ClassNotFoundException 闪退——这个坑本项目已经踩过一次。
-keep class com.clashparty.app.core.** { *; }

# 快捷开关、通知栏「停止」按钮、VPN 广播的 action 字符串
# 是拿枚举常量名拼出来的（Ext.kt 的 QuickAction.action / BroadcastAction.action），
# 必须和 AndroidManifest 里写死的 ${applicationId}.action.START 之类对得上。
# 常量名被改掉不会报错，只会表现为「点了没反应」。
-keepclassmembers enum com.clashparty.app.common.** {
    <fields>;
}
