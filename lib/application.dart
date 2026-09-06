import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:clash_party/common/common.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/manager/hotkey_manager.dart';
import 'package:clash_party/manager/manager.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/plugins/app.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/pages.dart';

class Application extends ConsumerStatefulWidget {
  const Application({super.key});

  @override
  ConsumerState<Application> createState() => ApplicationState();
}

class ApplicationState extends ConsumerState<Application> {
  Timer? _autoUpdateProfilesTaskTimer;
  bool _preHasVpn = false;

  /// 提示条的样式。
  ///
  /// 必须挂在这里而不是页面层：`ScaffoldMessenger` 挂在 `MaterialApp` 之上，
  /// 页面里的主题包不住它，所以提示条一直是 Material 默认的浅色圆角条——
  /// 全 App 唯一一处怎么改页面都改不掉的默认样式。
  /// 标题栏不要自己染色。
  ///
  /// Material 3 默认会按滚动高度给 AppBar 叠一层主色调（surfaceTint），于是浅色
  /// 下标题栏泛蓝灰、正文是纯白，同一屏出现两种「白」——用户一眼就看出别扭。
  /// 桌面端的标题栏和内容区是同一个底色，这里对齐它：底色跟随页面、不加染色、
  /// 不加投影。
  /// 页面顶栏。高度与标题字号见 [kAppBarToolbarHeight]。
  /// 页面顶栏。高度与标题字号见 [kAppBarToolbarHeight]。
  ///
  /// **必须按配色方案现算，不能写成 const。** 早先这里是个 const，
  /// `titleTextStyle` 只写了字号和字重——而 `AppBarTheme.titleTextStyle` 是
  /// **整体替换**默认样式，不是合并：默认那份（`titleLarge`）带着 `onSurface`
  /// 颜色，被换掉之后颜色没了，落回环境里的 `DefaultTextStyle`，浅色模式下显示成
  /// 纯白（用户原话「标题是纯白色的看不清楚」）。
  ///
  /// 所以这里把底色、前景色、标题颜色三样都从 `colorScheme` 明确取出来。
  @visibleForTesting
  static AppBarTheme appBarThemeOf(ColorScheme scheme) => AppBarTheme(
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    toolbarHeight: kAppBarToolbarHeight,
    backgroundColor: scheme.surface,
    foregroundColor: scheme.onSurface,
    titleTextStyle: TextStyle(
      fontSize: kAppBarTitleFontSize,
      fontWeight: FontWeight.w400,
      color: scheme.onSurface,
    ),
  );

  SnackBarThemeData _snackBarTheme(ThemeProps props) {
    final tokens = _styleTokens(props);
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF27272A),
      contentTextStyle: const TextStyle(color: Color(0xFFECEDEE)),
      actionTextColor: tokens.seed,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        side: BorderSide(color: tokens.rim),
      ),
    );
  }

  /// 视觉取值全部由用户选的界面风格决定。
  AppStyleTokens _styleTokens(ThemeProps props) =>
      AppStyleTokens.of(props.appStyle);

  final _pageTransitionsTheme = const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: commonSharedXPageTransitions,
      TargetPlatform.windows: commonSharedXPageTransitions,
      TargetPlatform.linux: commonSharedXPageTransitions,
      TargetPlatform.macOS: commonSharedXPageTransitions,
    },
  );

  /// 配色全部由界面风格推导，见 `genColorScheme`。
  ColorScheme _getAppColorScheme(Brightness brightness) {
    return ref.read(genColorSchemeProvider(brightness));
  }

  @override
  void initState() {
    super.initState();
    SystemNavigator.setFrameworkHandlesBack(true);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      if (globalState.navigatorKey.currentContext != null) {
        await globalState.attach();
      } else {
        exit(0);
      }
      _autoUpdateProfilesTask();
      _initLink();
      app?.initShortcuts();
    });
  }

  void _initLink() {
    linkManager.initAppLinksListen((url) async {
      final res = await globalState.showMessage(
        title: currentAppLocalizations.addProfile,
        message: TextSpan(
          children: [
            TextSpan(text: currentAppLocalizations.doYouWantToPass),
            TextSpan(
              text: ' $url ',
              style: TextStyle(
                color: context.colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: context.colorScheme.primary,
              ),
            ),
            TextSpan(text: currentAppLocalizations.createProfile),
          ],
        ),
      );
      if (res != true) return;
      ref.read(profilesActionProvider.notifier).addProfileFormURL(url);
    });
  }

  void _autoUpdateProfilesTask() {
    _autoUpdateProfilesTaskTimer = Timer(const Duration(minutes: 20), () async {
      await ref.read(profilesActionProvider.notifier).autoUpdateProfiles();
      _autoUpdateProfilesTask();
    });
  }

  Widget _buildPlatformState({required Widget child}) {
    if (system.isDesktop) {
      return WindowManager(
        child: TrayManager(
          child: HotKeyManager(child: ProxyManager(child: child)),
        ),
      );
    }
    return AndroidManager(child: TileManager(child: child));
  }

  Widget _buildState({required Widget child}) {
    return AppStateManager(
      child: CoreManager(
        child: ConnectivityManager(
          onConnectivityChanged: (results) async {
            commonPrint.log('connectivityChanged ${results.toString()}');
            ref.read(systemActionProvider.notifier).updateLocalIp();
            final hasVpn = results.contains(ConnectivityResult.vpn);
            if (_preHasVpn == hasVpn) {
              ref.read(checkIpNumProvider.notifier).add();
            }
            _preHasVpn = hasVpn;
          },
          child: child,
        ),
      ),
    );
  }

  Widget _buildPlatformApp({required Widget child}) {
    if (system.isDesktop) {
      return WindowHeaderContainer(child: child);
    }
    return VpnManager(child: child);
  }

  Widget _buildApp({required Widget child}) {
    return StatusManager(child: ThemeManager(child: child));
  }

  @override
  Widget build(context) {
    return Consumer(
      builder: (_, ref, child) {
        final locale = ref.watch(
          appSettingProvider.select((state) => state.locale),
        );
        final themeProps = ref.watch(themeSettingProvider);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: globalState.navigatorKey,
          onNavigationNotification: (_) => true,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          builder: (_, child) {
            return AppEnvManager(
              child: _buildApp(
                child: _buildPlatformState(
                  child: _buildState(child: _buildPlatformApp(child: child!)),
                ),
              ),
            );
          },
          scrollBehavior: BaseScrollBehavior(),
          title: appName,
          locale: utils.getLocaleForString(locale),
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          themeMode: themeProps.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            pageTransitionsTheme: _pageTransitionsTheme,
            extensions: <ThemeExtension<dynamic>>[_styleTokens(themeProps)],
            snackBarTheme: _snackBarTheme(themeProps),
            appBarTheme: appBarThemeOf(_getAppColorScheme(Brightness.light)),
            colorScheme: _getAppColorScheme(Brightness.light),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            pageTransitionsTheme: _pageTransitionsTheme,
            extensions: <ThemeExtension<dynamic>>[_styleTokens(themeProps)],
            snackBarTheme: _snackBarTheme(themeProps),
            appBarTheme: appBarThemeOf(_getAppColorScheme(Brightness.dark)),
            colorScheme: _getAppColorScheme(Brightness.dark),
          ),
          home: child!,
        );
      },
      child: const HomePage(),
    );
  }

  @override
  void dispose() {
    linkManager.destroy();
    _autoUpdateProfilesTaskTimer?.cancel();
    super.dispose();
  }
}
