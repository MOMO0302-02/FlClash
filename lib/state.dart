import 'dart:async';
import 'dart:io';

import 'package:animations/animations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/widgets/dialog.dart';
import 'package:clash_party/widgets/list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_color_utilities/palettes/core_palette.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'common/common.dart';
import 'common/migration.dart';
import 'database/database.dart';
import 'enum/enum.dart';
import 'l10n/l10n.dart';
import 'models/models.dart';
import 'providers/providers.dart';

class GlobalState {
  static GlobalState? _instance;
  final navigatorKey = GlobalKey<NavigatorState>();
  late final String appEnv;
  late final PackageInfo packageInfo;
  Function? updateCurrentDelayDebounce;
  late Measure measure;
  late CommonTheme theme;
  Color accentColor = const Color(defaultPrimaryColor);
  late ProviderContainer container;
  bool needInitStatus = true;

  /// 上次是不是陷在「一开就崩」里（连续两次启动没走完）。
  bool _didCrashOnPreviousExecution = false;

  bool get isPre => appEnv != 'stable';

  bool get canCrashCore => canCrashCoreFor(isDebug: kDebugMode, appEnv: appEnv);

  @visibleForTesting
  static bool canCrashCoreFor({required bool isDebug, required String appEnv}) {
    return isDebug || appEnv == 'dev';
  }

  // ignore: deprecated_member_use
  CorePalette? corePalette;
  String? lastConfigMd5;
  VpnState? lastVpnState;
  bool isAttach = false;

  GlobalState._internal();

  factory GlobalState() {
    _instance ??= GlobalState._internal();
    return _instance!;
  }

  Future<ProviderContainer> init(int version) async {
    appEnv = const String.fromEnvironment('APP_ENV', defaultValue: 'pre');
    await _initDynamicColor();
    return _initData(version);
  }

  Future<void> _initDynamicColor() async {
    try {
      corePalette = await DynamicColorPlugin.getCorePalette();
      accentColor = await DynamicColorPlugin.getAccentColor() ?? accentColor;
    } catch (error) {
      commonPrint.log(
        'Failed to initialize dynamic color: $error',
        logLevel: LogLevel.warning,
      );
    }
  }

  String get ua => container
      .read(patchClashConfigProvider.select((state) => state.globalUa))
      .takeFirstValid([packageInfo.ua]);

  BuildContext get _context => navigatorKey.currentContext!;

  /// 把 Smart 的几项参数**一次性**对齐到推荐值。
  ///
  /// **为什么需要这一步**：这些参数的推荐值是写在 freezed 的 `@Default` 里的，
  /// 而 `@Default` 只在「存档里根本没有这个字段」时才生效。已经装过的机器上这些
  /// 字段早就写进去了，改默认值对它们一点作用都没有——用户在设置页看到的还是
  /// 旧值（延迟容差 0、按运营商归纳开着），而那正是要调的东西。
  ///
  /// **覆盖用户设置是件重的事，所以限定得很死**：只跑一次（[preferences]
  /// 里单独一个标记记着跑到第几版），只碰 Smart 这几项，不碰其它任何设置。跑完
  /// 用户想怎么改都行，不会再被覆盖第二次。
  ///
  /// 每一项为什么是这个值，连同内核源码依据，钉在
  /// `test/config/smart_defaults_test.dart`。
  Future<Config> _applySmartTuning(Config config) async {
    const tuningVersion = 1;
    if (await preferences.getSmartTuningVersion() >= tuningVersion) {
      return config;
    }
    final tuned = config.copyWith(
      appSettingProps: config.appSettingProps.copyWith(
        // 该开的：模型选路是 Smart 的全部意义；延迟去抖防止手机网络抖动导致
        // 节点反复横跳；模型自动更新有「只在 Wi-Fi」那道闸兜着。
        smartUseLightGBM: true,
        smartTolerance: defaultSmartTolerance,
        smartLgbmAutoUpdate: true,
        // 该关的：收集数据只写一个供**离线**训练的 CSV，运行时选路一点都不读，
        // 手机上又不能训练，开着就是白占最多 100 MB；按运营商归纳会在选路路径上
        // 多做一次阻塞的 DNS 解析，还要把 10.8 MB 的 ASN 库读进内存。
        smartCollectData: false,
        smartPreferAsn: false,
      ),
    );
    await preferences.saveConfig(tuned);
    await preferences.setSmartTuningVersion(tuningVersion);
    return tuned;
  }

  Future<ProviderContainer> _initData(int version) async {
    packageInfo = await PackageInfo.fromPlatform();
    var config = await migration.run();
    config = await _applySmartTuning(config);
    // **连续两次启动没走完，才认定是「一开就崩」的死循环。**
    //
    // 一次不算：用户在启动头几秒手动强杀、系统正好在那几秒回收进程，都会留下
    // 一次未完成的启动。而认定崩溃是有代价的——会清掉用户当前选中的订阅。
    // 真正的死循环十秒内就能满两次，等一次不影响把用户捞出来。
    _didCrashOnPreviousExecution =
        await system.consumeStartupFailureStreak() >= 2;
    if (_didCrashOnPreviousExecution) {
      config = config.copyWith(currentProfileId: null);
      await preferences.saveConfig(config);
    }
    final appState = AppState(
      brightness: WidgetsBinding.instance.platformDispatcher.platformBrightness,
      version: version,
      viewSize: Size.zero,
      requests: FixedList(maxLength),
      logs: FixedList(maxLength),
      traffics: FixedList(30),
      totalTraffic: const Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    final appStateOverrides = buildAppStateOverrides(appState);
    final configOverrides = buildConfigOverrides(config);
    container = ProviderContainer(
      overrides: [...appStateOverrides, ...configOverrides],
    );
    final profiles = await database.profilesDao.query().get();
    container.read(profilesProvider.notifier).setAndReorder(profiles);
    await AppLocalizations.load(
      utils.getLocaleForString(config.appSettingProps.locale) ??
          WidgetsBinding.instance.platformDispatcher.locale,
    );
    await window?.init(version, config.windowProps);
    if (system.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    return container;
  }

  Future<T?> loadingRun<T>(
    FutureOr<T> Function() futureFunction, {
    String? title,
    required LoadingTag? tag,
    bool silence = false,
  }) async {
    return globalState.safeRun(
      futureFunction,
      silence: silence,
      title: title,
      onStart: () {
        if (tag != null) {
          container.read(loadingProvider(tag).notifier).start();
        }
      },
      onEnd: () {
        if (tag != null) {
          container.read(loadingProvider(tag).notifier).stop();
        }
      },
    );
  }

  Future<T?> safeRun<T>(
    FutureOr<T> Function() futureFunction, {
    String? title,
    VoidCallback? onStart,
    VoidCallback? onEnd,
    bool silence = true,
  }) async {
    try {
      onStart?.call();
      return await futureFunction();
    } catch (e, s) {
      commonPrint.log('$title ===> $e, $s', logLevel: LogLevel.warning);
      if (silence) {
        showNotifier(e.toString());
      } else {
        showMessage(
          title: title ?? currentAppLocalizations.tip,
          message: TextSpan(text: e.toString()),
        );
      }
      return null;
    } finally {
      onEnd?.call();
    }
  }

  Future<bool?> showMessage({
    required InlineSpan message,
    BuildContext? context,
    String? title,
    String? confirmText,
    String? cancelText,
    bool cancelable = true,
    bool? dismissible,
  }) async {
    return showCommonDialog<bool>(
      context: context,
      dismissible: dismissible,
      child: Builder(
        builder: (context) {
          final appLocalizations = context.appLocalizations;
          return CommonDialog(
            title: title ?? appLocalizations.tip,
            actions: [
              if (cancelable)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text(cancelText ?? appLocalizations.cancel),
                ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: Text(confirmText ?? appLocalizations.confirm),
              ),
            ],
            child: Container(
              width: 300,
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: SelectableText.rich(
                  TextSpan(
                    style: Theme.of(context).textTheme.labelLarge,
                    children: [message],
                  ),
                  style: const TextStyle(overflow: TextOverflow.visible),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool?> showAllUpdatingMessagesDialog(
    List<UpdatingMessage> messages,
  ) async {
    return showCommonDialog<bool>(
      child: Builder(
        builder: (context) {
          final appLocalizations = currentAppLocalizations;
          return CommonDialog(
            padding: EdgeInsets.zero,
            title: appLocalizations.tip,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: Text(appLocalizations.confirm),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                itemBuilder: (_, index) {
                  final message = messages[index];
                  return ListItem(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    title: Text(message.label),
                    subtitle: Text(message.message),
                  );
                },
                itemCount: messages.length,
                separatorBuilder: (_, _) => const Divider(height: 0),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<T?> showCommonDialog<T>({
    required Widget child,
    BuildContext? context,
    bool? dismissible,
    bool filter = true,
  }) async {
    return showModal<T>(
      useRootNavigator: false,
      context: context ?? globalState.navigatorKey.currentContext!,
      configuration: FadeScaleTransitionConfiguration(
        barrierColor: Colors.black38,
        barrierDismissible: dismissible ?? true,
      ),
      builder: (_) => child,
      filter: filter ? commonFilter : null,
    );
  }

  void showNotifier(String text, {MessageActionState? actionState}) {
    if (text.isEmpty) {
      return;
    }
    navigatorKey.currentContext?.showNotifier(text, actionState: actionState);
  }

  Future<void> openUrl(String url) async {
    final res = await showMessage(
      message: TextSpan(text: url),
      title: currentAppLocalizations.externalLink,
      confirmText: currentAppLocalizations.go,
    );
    if (res != true) {
      return;
    }
    launchUrl(Uri.parse(url));
  }

  Future<void> attach() async {
    if (isAttach == true) {
      return;
    }
    await _initApp();
    isAttach = true;
  }

  Future<void> _initApp() async {
    FlutterError.onError = (details) {
      Future.microtask(() {
        commonPrint.log(
          'exception: ${details.exception} stack: ${details.stack}',
          logLevel: LogLevel.warning,
        );
      });
    };
    container.read(systemActionProvider.notifier).updateTray();
    container.read(profilesActionProvider.notifier).autoUpdateProfiles();
    container.read(commonActionProvider.notifier).autoCheckUpdate();
    autoLaunch?.updateStatus(container.read(appSettingProvider).autoLaunch);
    if (!container.read(appSettingProvider).silentLaunch) {
      window?.show();
    } else {
      window?.hide();
    }
    await _handleFailedPreference();
    await _handlerDisclaimer();
    await _showCrashRecoveryTip();
    await container.read(coreActionProvider.notifier).startCore();
    if (!_didCrashOnPreviousExecution) {
      await container.read(setupActionProvider.notifier).initStatus();
    }
    container.read(initProvider.notifier).value = true;
    permissions.check();
    // 走到这儿说明启动确实走完了（内核起过、初始化做过）。清掉标记，下次启动
    // 就不会把这次算成失败。**位置不能提前**：提前清掉的话，卡在后面某一步的
    // 死循环就再也检测不出来了。
    await system.markStartupComplete();
  }

  Future<void> _showCrashRecoveryTip() async {
    if (!_didCrashOnPreviousExecution) return;
    await showMessage(
      title: currentAppLocalizations.crashDetected,
      cancelable: false,
      dismissible: false,
      message: TextSpan(text: currentAppLocalizations.crashDetectedTip),
    );
  }

  Future<void> _handleFailedPreference() async {
    if (await preferences.isInit) return;
    final res = await showMessage(
      title: currentAppLocalizations.tip,
      message: TextSpan(text: currentAppLocalizations.cacheCorrupt),
    );
    if (res == true) {
      final file = File(await appPath.sharedPreferencesPath);
      await file.safeDelete();
    }
    await container.read(systemActionProvider.notifier).handleExit();
  }

  Future<bool> showDisclaimer() async {
    return await showCommonDialog<bool>(
          dismissible: false,
          child: CommonDialog(
            title: currentAppLocalizations.disclaimer,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(_context).pop<bool>(false);
                },
                child: Text(currentAppLocalizations.exit),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(_context).pop<bool>(true);
                },
                child: Text(currentAppLocalizations.agree),
              ),
            ],
            child: Text(currentAppLocalizations.disclaimerDesc),
          ),
        ) ??
        false;
  }

  Future<void> _handlerDisclaimer() async {
    if (container.read(
      appSettingProvider.select((state) => state.disclaimerAccepted),
    )) {
      return;
    }
    final isDisclaimerAccepted = await showDisclaimer();
    if (!isDisclaimerAccepted) {
      // Without the return, declining still records acceptance and the
      // disclaimer is never shown again.
      await container.read(systemActionProvider.notifier).handleExit();
      return;
    }
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(disclaimerAccepted: true));
  }
}

final globalState = GlobalState();
