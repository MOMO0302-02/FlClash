import 'dart:async';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/core/core.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/action.dart';
import 'package:clash_party/providers/app.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/providers/state.dart';
import 'package:clash_party/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoreManager extends ConsumerStatefulWidget {
  final Widget child;
  final CoreController controller;

  CoreManager({super.key, required this.child, CoreController? controller})
    : controller = controller ?? coreController;

  @override
  ConsumerState<CoreManager> createState() => _CoreContainerState();
}

class _CoreContainerState extends ConsumerState<CoreManager>
    with CoreEventListener {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    coreEventManager.addListener(this);
    ref.listenManual(currentProfileIdProvider, (prev, next) {
      if (prev != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(setupActionProvider.notifier).fullSetup();
        });
      }
    });
    ref.listenManual(updateParamsProvider, (prev, next) {
      if (prev != next) {
        ref.read(setupActionProvider.notifier).updateConfigDebounce();
      }
    });
    // Smart 选路的**任何一项**变了都要重新生成整份配置，不能只发补丁。
    //
    // 上面那个 updateParams 走的是 PATCH /configs，只能改端口、模式这类顶层选项；
    // 而这些设置改的是代理组本身（组的 type、uselightgbm、strategy…），必须整份
    // 重下发，否则用户拨了开关却什么都不会发生——比开关不存在还让人困惑。
    //
    // **以后加 Smart 设置项时不用再改这里**：盯的是 `smartOptionsState` 这个包，
    // 新字段只要进了它（`AppSettingPropsSmartExt`），这条监听自动覆盖到。
    //
    // 盯的是 smartOptionsState 而不是 appSetting 里那个：前者还带着当前的网络
    // 类型，所以**从 Wi-Fi 切到流量也会触发重新下发**——「仅 Wi-Fi 更新模型」
    // 那道闸就是靠这一下才会真的在切网时生效，而不是等下次改设置。
    ref.listenManual(smartOptionsStateProvider, (prev, next) {
      if (prev != null && prev != next) {
        ref.read(setupActionProvider.notifier).applyProfileDebounce();
      }
    });
    // 嗅探和混合端口验证同理：这几项只存在于生成的配置文件里，上面那个
    // updateParams 走的 PATCH /configs 改不了它们（内核 `hub/route/configs.go`
    // 的 configSchema 里根本没有 sniffer / authentication / secret 这些字段），
    // 不整份重下发的话，用户拨了开关要等到下次换订阅或重启才生效——那和开关
    // 坏了没区别。
    ref.listenManual(
      patchClashConfigProvider.select(
        (state) => VM4(
          state.sniffer,
          state.authentication,
          state.skipAuthPrefixes,
          state.secret,
        ),
      ),
      (prev, next) {
        // prev 为 null 是启动时读档那一次，不是用户改的；那时候
        // `initStatus` 自己会 applyProfile(force: true)。
        if (prev != null && prev != next) {
          ref.read(setupActionProvider.notifier).applyProfileDebounce();
        }
      },
    );
    ref.listenManual(appSettingProvider.select((state) => state.openLogs), (
      prev,
      next,
    ) {
      if (next) {
        widget.controller.startLog();
      } else {
        widget.controller.stopLog();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    coreEventManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onDelay(Delay delay) async {
    super.onDelay(delay);
    final proxiesAction = ref.read(proxiesActionProvider.notifier);
    proxiesAction.setDelay(delay);
    debouncer.call(FunctionTag.updateDelay, () async {
      proxiesAction.updateGroupsDebounce();
    }, duration: const Duration(milliseconds: 5000));
  }

  @override
  void onLog(Log log) {
    ref.read(logsProvider.notifier).add(log);
    if (log.logLevel == LogLevel.error) {
      globalState.showNotifier(log.payload);
    }
    super.onLog(log);
  }

  @override
  void onRequest(TrackerInfo trackerInfo) async {
    ref.read(requestsProvider.notifier).addRequest(trackerInfo);
    super.onRequest(trackerInfo);
  }

  @override
  Future<void> onLoaded(String providerName) async {
    final ref = globalState.container;
    ref
        .read(providersProvider.notifier)
        .setProvider(await widget.controller.getExternalProvider(providerName));
    debouncer.call(FunctionTag.loadedProvider, () async {
      ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
    }, duration: const Duration(milliseconds: 5000));
    super.onLoaded(providerName);
  }

  @override
  Future<void> onCrash(String message) async {
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      context.showNotifier(message);
    }
    if (system.isDesktop) {
      // Desktop has no auto-restart, and isStartProvider still reads as
      // started, so ProxyManager would keep the system proxy pointed at the
      // dead core's port. Release the app-side state only: the core is
      // already gone, so stopping it here would just block on a dead
      // transport.
      ref.read(setupActionProvider.notifier).markStopped();
    }
    super.onCrash(message);
  }

  @override
  void onGeoUpdate(String geoType, bool updating, bool skipped, String? error) {
    final geoResource = GeoResource.fromJson(geoType.toLowerCase());
    final key = geoResource.updatingKey;
    final l10n = currentAppLocalizations;
    final hasError = error != null && error.isNotEmpty;
    if (updating) {
      globalState.showNotifier(l10n.geoUpdating(geoResource.name));
    } else if (hasError) {
      // Only the error below; announcing 'updated' first is misleading.
    } else if (skipped) {
      globalState.showNotifier(l10n.geoSkipped(geoResource.name));
    } else {
      globalState.showNotifier(l10n.geoUpdated(geoResource.name));
    }
    ref.read(isUpdatingProvider(key).notifier).value = updating;
    if (!updating && hasError) {
      globalState.showNotifier(error);
    }
    super.onGeoUpdate(geoType, updating, skipped, error);
  }
}
