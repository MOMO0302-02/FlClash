import 'dart:async';
import 'dart:io';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class App {
  static App? _instance;
  late MethodChannel methodChannel;
  Function()? onExit;

  App._internal() {
    methodChannel = const MethodChannel('$packageName/app');
    methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'exit':
          if (onExit != null) {
            await onExit!();
          }
        default:
          throw MissingPluginException();
      }
    });
  }

  factory App() {
    _instance ??= App._internal();
    return _instance!;
  }

  Future<bool?> moveTaskToBack() async {
    return methodChannel.invokeMethod<bool>('moveTaskToBack');
  }

  Future<List<Package>> getPackages() async {
    final packagesString = await methodChannel.invokeMethod<String>(
      'getPackages',
    );
    final List<dynamic> packagesRaw =
        (await packagesString?.commonToJSON<List<dynamic>>()) ?? [];
    return packagesRaw.map((e) => Package.fromJson(e)).toSet().toList();
  }

  Future<List<String>> getChinaPackageNames() async {
    final packageNamesString = await methodChannel.invokeMethod<String>(
      'getChinaPackageNames',
    );
    final List<dynamic> packageNamesRaw =
        await packageNamesString?.commonToJSON<List<dynamic>>() ?? [];
    return packageNamesRaw.map((e) => e.toString()).toList();
  }

  Future<bool?> requestNotificationsPermission() async {
    return methodChannel.invokeMethod<bool>('requestNotificationsPermission');
  }

  Future<bool> openFile(String path) async {
    return await methodChannel.invokeMethod<bool>('openFile', {'path': path}) ??
        false;
  }

  /// 应用图标按包名缓存住**同一个 Future 对象**。
  ///
  /// 连接页每秒整表重建一次，卡片里是 `FutureBuilder(future: getPackageIcon(...))`
  /// —— future 在 build 里现造。FutureBuilder 按 `!=` 比较新旧 future，每秒都拿到
  /// 新对象，于是每秒每张可见卡片都要走一次平台通道查 PackageManager，而且在结果
  /// 回来之前先渲染一帧没有图标的空白，这就是「图标每秒闪一下」的来源。
  ///
  /// 缓存 Future 而不是结果：重建时拿到同一个对象，FutureBuilder 不再重置，
  /// 平台调用每个包名只发生一次。用 [FixedMap] 兜住上限，避免包名过多时无限增长。
  final _packageIconCache = FixedMap<String, Future<ImageProvider?>>(256);

  Future<ImageProvider?> getPackageIcon(String packageName) {
    return _packageIconCache.updateCacheValue(
      packageName,
      () => _loadPackageIcon(packageName),
    );
  }

  Future<ImageProvider?> _loadPackageIcon(String packageName) async {
    final path = await methodChannel.invokeMethod<String>('getPackageIcon', {
      'packageName': packageName,
    });
    if (path == null) {
      return null;
    }
    return FileImage(File(path));
  }

  Future<bool?> tip(String? message) async {
    return methodChannel.invokeMethod<bool>('tip', {'message': '$message'});
  }

  /// 把 [text] 放进剪贴板，并在 Android 13+ 上标成敏感内容
  /// （`ClipDescription.EXTRA_IS_SENSITIVE`）。
  ///
  /// 订阅链接带 token，敏感标记能让系统的剪贴板预览、输入法与剪贴板历史不去展示
  /// 它的内容。返回 false 表示平台侧没设成功，调用方应回退到普通 Clipboard。
  Future<bool> setSensitiveClipboard(String text) async {
    return await methodChannel.invokeMethod<bool>('setSensitiveClipboard', {
          'text': text,
        }) ??
        false;
  }

  /// 长按启动图标的快捷方式现在是清单里的静态快捷方式（安装完就有，不用先开一次
  /// 应用），文案走安卓自己的字符串资源，所以不再需要把本地化文案传过去。
  ///
  /// 这个调用只剩「清掉旧版留下的动态快捷方式」一件事，而且是**兜底**——安卓那边
  /// 在插件挂上引擎时就已经清过一次了。之所以不指望这条链路：它排在
  /// `globalState.attach()` 之后，而 attach 里要等内核启动等一串 await，
  /// 模拟器上实测界面都出来了这一步仍然没轮到。
  Future<bool?> initShortcuts() async {
    if (!Platform.isAndroid) return false;
    return methodChannel.invokeMethod<bool>('initShortcuts');
  }

  Future<bool?> updateExcludeFromRecents(bool value) async {
    return methodChannel.invokeMethod<bool>('updateExcludeFromRecents', {
      'value': value,
    });
  }

  Future<bool?> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    return methodChannel.invokeMethod<bool>('isBatteryOptimizationDisabled');
  }

  Future<bool?> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return false;
    return methodChannel.invokeMethod<bool>('openBatteryOptimizationSettings');
  }

  Future<bool?> openAppSettings() async {
    if (!Platform.isAndroid) return false;
    return methodChannel.invokeMethod<bool>('openAppSettings');
  }

  /// 跳到系统的「VPN」设置页（「始终开启 VPN」的开关藏在那里应用旁边的齿轮后面）。
  /// 系统没给能直接落到那个开关上的入口，所以只能送到列表页；返回 false 表示
  /// 这台机器上连列表页都跳不过去，界面要改成给一句手动路径。
  Future<bool?> openVpnSettings() async {
    if (!Platform.isAndroid) return false;
    return methodChannel.invokeMethod<bool>('openVpnSettings');
  }

  /// 取「连续多少次启动没走完」，并把本次标记为进行中。
  ///
  /// 出错时返回 0（＝不认为崩过）：这道网是用来兜底的，它自己出问题不该反过来
  /// 去清用户的配置。
  Future<int> consumeStartupFailureStreak() async {
    try {
      return await methodChannel.invokeMethod<int>(
            'consumeStartupFailureStreak',
          ) ??
          0;
    } catch (_) {
      return 0;
    }
  }

  /// 启动走完了，清掉标记。
  Future<void> markStartupComplete() async {
    try {
      await methodChannel.invokeMethod<bool>('markStartupComplete');
    } catch (_) {
      // 清不掉最多是下次多算一次失败，不值得打断启动。
    }
  }
}

final app = system.isAndroid ? App() : null;
