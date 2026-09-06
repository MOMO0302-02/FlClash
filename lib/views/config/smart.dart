import 'package:clash_party/common/common.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/config/smart_model.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Smart 内核设置页。
///
/// 对应桌面版「内核设置」里那张 Smart 卡片（`src/renderer/src/pages/mihomo.tsx`
/// 的 `:355-610`）。**桌面版有、这里没有的只有一项**：`enableSmartCore`（在两个
/// 内核二进制之间切换）。安卓端打包的内核本来就是 Smart 版，没有第二个二进制可切，
/// 所以那一项在这里没有对应物；桌面版真正管"要不要自动改写配置"的
/// `enableSmartOverride` 才是这一页顶上那个总开关。
///
/// 每一项底下都写了说明，文案取自桌面版的 `mihomo.smart*Tooltip`。桌面端是鼠标
/// 悬停在 ⓘ 上才显示，手机上没有悬停这回事，就直接摊在标题下面——这也是本应用
/// 其它设置页一贯的写法。
class SmartView extends StatelessWidget {
  const SmartView({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: context.appLocalizations.smartCore,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ...generateSection(isFirst: true, items: const [SmartRoutingItem()]),
          const _SmartOptionsSection(),
        ],
      ),
    );
  }
}

/// 总开关关掉时，下面那一组选项一个都不生效（配置里的 Smart 组会被换成
/// url-test），所以整组收起来而不是留在那儿灰着——留着只会让人以为拨了有用。
class _SmartOptionsSection extends ConsumerWidget {
  const _SmartOptionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm3 = ref.watch(
      appSettingProvider.select(
        (state) => VM3(
          state.smartRouting,
          state.smartCollectData,
          state.smartUseLightGBM,
        ),
      ),
    );
    final enable = vm3.a;
    final collectData = vm3.b;
    final useLightGBM = vm3.c;
    return AnimatedSize(
      duration: Motion.quick,
      curve: Motion.move,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: enable
            ? [
                ...generateSection(
                  items: [
                    // 「全局模式下要选名叫 Smart Group 的节点」原来塞在总开关那条
                    // 说明里，把一句话撑成三行。它只对**已经开了 Smart 的人**有
                    // 意义，所以挪到这里：开了才出现，没开的人不用先读一段用不上的
                    // 注意事项。
                    ListItem(
                      leading: const Icon(Icons.info_outline),
                      title: Text(
                        context.appLocalizations.smartRoutingGlobalTip,
                      ),
                    ),
                    const SmartUseLightGBMItem(),
                    const SmartCollectDataItem(),
                    // 采样率只管"收集数据"往盘上写多少，收集没开的时候它什么都不
                    // 管——所以跟着收集一起出现，别让人调一个不起作用的数。
                    if (collectData) const SmartSampleRateItem(),
                    const SmartCollectorSizeItem(),
                    const SmartToleranceItem(),
                    const SmartPreferAsnItem(),
                    const SmartStrategyItem(),
                  ],
                ),
                // 模型只有开了 LightGBM 才用得上——没开的时候下不下载都一样，
                // 这一整组就不该出现，否则用户会以为自己非下不可。
                if (useLightGBM)
                  // 这一组不另起标题：第一行本身就叫「选路模型」，再加一个同名
                  // 的分组标题只是把同一个词在屏幕上写两遍。
                  ...generateSection(
                    items: const [
                      SmartModelStatusItem(),
                      SmartLgbmAutoUpdateItem(),
                      _SmartLgbmAutoUpdateSection(),
                      SmartLgbmUrlItem(),
                    ],
                  ),
              ]
            : const [],
      ),
    );
  }
}

/// Smart 选路总开关。对应桌面版的 `enableSmartOverride`。
class SmartRoutingItem extends ConsumerWidget {
  const SmartRoutingItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final smartRouting = ref.watch(
      appSettingProvider.select((state) => state.smartRouting),
    );

    return ListItem.toggle(
      leading: const Icon(Icons.psychology),
      // 不带说明文字。
      //
      // 这一行是 Smart 内核页里的总开关，用户是从「Smart 内核」那个入口点进来的
      // ——入口处已经有一句说明，进来再说一遍是重复。页面标题也已经写着
      // 「Smart 内核」，开关本身要表达的东西一目了然。
      title: Text(appLocalizations.smartRouting),
      value: smartRouting,
      onChanged: (bool value) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(smartRouting: value));
      },
    );
  }
}

class SmartUseLightGBMItem extends ConsumerWidget {
  const SmartUseLightGBMItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final value = ref.watch(
      appSettingProvider.select((state) => state.smartUseLightGBM),
    );
    return ListItem.toggle(
      leading: const Icon(Icons.model_training_outlined),
      title: Text(appLocalizations.smartUseLightGBM),
      subtitle: Text(appLocalizations.smartUseLightGBMDesc),
      value: value,
      onChanged: (bool next) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(smartUseLightGBM: next));
      },
    );
  }
}

class SmartCollectDataItem extends ConsumerWidget {
  const SmartCollectDataItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final value = ref.watch(
      appSettingProvider.select((state) => state.smartCollectData),
    );
    return ListItem.toggle(
      leading: const Icon(Icons.insights_outlined),
      title: Text(appLocalizations.smartCollectData),
      subtitle: Text(appLocalizations.smartCollectDataDesc),
      value: value,
      onChanged: (bool next) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(smartCollectData: next));
      },
    );
  }
}

class SmartCollectorSizeItem extends ConsumerWidget {
  const SmartCollectorSizeItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final value = ref.watch(
      appSettingProvider.select((state) => state.smartCollectorSize),
    );
    return ListItem.input(
      leading: const Icon(Icons.folder_outlined),
      title: Text(appLocalizations.smartCollectorSize),
      subtitle: Text(appLocalizations.smartCollectorSizeDesc),
      trailing: Text('$value MB'),
      dialogTitle: appLocalizations.smartCollectorSize,
      // 单位不进翻译表：MB 在四种语言里都写作 MB。
      suffixText: 'MB',
      resetValue: '$defaultSmartCollectorSize',
      value: '$value',
      maxLength: TextInputLimits.number,
      keyboardType: TextInputType.number,
      validator: (String? input) {
        if (input == null || input.isEmpty) {
          return appLocalizations.emptyTip(appLocalizations.smartCollectorSize);
        }
        if (int.tryParse(input) == null) {
          return appLocalizations.numberTip(
            appLocalizations.smartCollectorSize,
          );
        }
        return null;
      },
      onChanged: (String? input) {
        if (input == null) return;
        // 桌面版是在输入框失焦时把小于 1 的值夹回 1，这里同样夹一下：
        // 0 或负数会让内核一落盘就把收集文件砍掉，等于开了收集却什么都没收到。
        final next = (int.tryParse(input) ?? defaultSmartCollectorSize).clamp(
          1,
          1 << 30,
        );
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(smartCollectorSize: next));
      },
    );
  }
}

class SmartStrategyItem extends ConsumerWidget {
  const SmartStrategyItem({super.key});

  String _label(BuildContext context, String strategy) {
    final appLocalizations = context.appLocalizations;
    return switch (normalizeSmartStrategy(strategy)) {
      smartStrategyRoundRobin => appLocalizations.smartStrategyRoundRobin,
      _ => appLocalizations.smartStrategyStickySessions,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final value = ref.watch(
      appSettingProvider.select((state) => state.smartStrategy),
    );
    return ListItem<String>.options(
      leading: const Icon(Icons.alt_route_outlined),
      title: Text(appLocalizations.smartStrategy),
      subtitle: Text(appLocalizations.smartStrategyDesc),
      trailing: Text(_label(context, value)),
      dialogTitle: appLocalizations.smartStrategy,
      options: smartStrategies,
      // 存档里可能是个已经不认识的值（比如从桌面版同步过来的旧配置），
      // 那就当作默认的粘性会话，别让选项对话框一项都选不中。
      value: normalizeSmartStrategy(value),
      textBuilder: (strategy) => _label(context, strategy),
      onChanged: (String? next) {
        if (next == null) return;
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(smartStrategy: next));
      },
    );
  }
}

class SmartToleranceItem extends ConsumerWidget {
  const SmartToleranceItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final value = ref.watch(
      appSettingProvider.select((state) => state.smartTolerance),
    );
    return ListItem.input(
      leading: const Icon(Icons.tune_outlined),
      title: Text(appLocalizations.smartTolerance),
      subtitle: Text(appLocalizations.smartToleranceDesc),
      trailing: Text('$value ${appLocalizations.milliseconds}'),
      dialogTitle: appLocalizations.smartTolerance,
      suffixText: appLocalizations.milliseconds,
      resetValue: '0',
      value: '$value',
      maxLength: TextInputLimits.number,
      keyboardType: TextInputType.number,
      validator: (String? input) {
        if (input == null || input.isEmpty) {
          return appLocalizations.emptyTip(appLocalizations.smartTolerance);
        }
        if (int.tryParse(input) == null) {
          return appLocalizations.numberTip(appLocalizations.smartTolerance);
        }
        return null;
      },
      onChanged: (String? input) {
        if (input == null) return;
        final next = (int.tryParse(input) ?? 0).clamp(0, 1 << 30);
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(smartTolerance: next));
      },
    );
  }
}

class SmartPreferAsnItem extends ConsumerWidget {
  const SmartPreferAsnItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final value = ref.watch(
      appSettingProvider.select((state) => state.smartPreferAsn),
    );
    return ListItem.toggle(
      leading: const Icon(Icons.hub_outlined),
      title: Text(appLocalizations.smartPreferAsn),
      subtitle: Text(appLocalizations.smartPreferAsnDesc),
      value: value,
      onChanged: (bool next) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(smartPreferAsn: next));
      },
    );
  }
}

class SmartSampleRateItem extends ConsumerWidget {
  const SmartSampleRateItem({super.key});

  /// 1.0 显示成 "1"、0.5 显示成 "0.5"——别把整数写成 "1.0"，那看着像个 bug。
  static String formatRate(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final value = ref.watch(
      appSettingProvider.select((state) => state.smartSampleRate),
    );
    return ListItem.input(
      leading: const Icon(Icons.percent_outlined),
      title: Text(appLocalizations.smartSampleRate),
      subtitle: Text(appLocalizations.smartSampleRateDesc),
      trailing: Text(formatRate(value)),
      dialogTitle: appLocalizations.smartSampleRate,
      resetValue: '1',
      value: formatRate(value),
      maxLength: TextInputLimits.number,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (String? input) {
        if (input == null || input.isEmpty) {
          return appLocalizations.emptyTip(appLocalizations.smartSampleRate);
        }
        final parsed = double.tryParse(input);
        if (parsed == null) {
          return appLocalizations.numberTip(appLocalizations.smartSampleRate);
        }
        // 内核对越界值的处理是"忽略并回落到 1"，界面上直接拦住，
        // 免得用户填了 0 以为关掉了收集、结果什么都没变。
        if (parsed <= 0 || parsed > 1) {
          return appLocalizations.smartSampleRateTip;
        }
        return null;
      },
      onChanged: (String? input) {
        if (input == null) return;
        final parsed = double.tryParse(input);
        if (parsed == null || parsed <= 0 || parsed > 1) return;
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(smartSampleRate: parsed));
      },
    );
  }
}

/// 模型状态那一行：现在有没有模型、多大、什么时候下的，右边一个下载按钮。
///
/// **桌面端没有这一行**，理由见 `smart_model.dart` 的文件头。
///
/// 为什么非有不可：模型缺失时内核只是安静地退回「按延迟挑」，`uselightgbm: true`
/// 照样写在配置里、代理组照样显示成 Smart，**没有任何地方看得出来它在空转**。
/// 实测就撞上过这种情况。
class SmartModelStatusItem extends ConsumerStatefulWidget {
  const SmartModelStatusItem({super.key});

  @override
  ConsumerState<SmartModelStatusItem> createState() =>
      _SmartModelStatusItemState();
}

class _SmartModelStatusItemState extends ConsumerState<SmartModelStatusItem> {
  SmartModelStatus? _status;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await readSmartModelStatus();
    if (!mounted) {
      return;
    }
    setState(() {
      _status = status;
    });
  }

  Future<void> _download() async {
    if (_downloading) {
      return;
    }
    setState(() {
      _downloading = true;
    });
    final url = ref.read(appSettingProvider).smartLgbmUrl;
    try {
      final status = await downloadSmartModel(url: url);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
      });
      globalState.showNotifier(currentAppLocalizations.smartModelDownloaded);
    } catch (e) {
      if (!mounted) {
        return;
      }
      // 失败时**不改** `_status`：原来那个模型一个字节都没动过，界面上也不该变。
      // `downloadSmartModel` 保证验不过就不落盘。
      globalState.showNotifier(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  /// 副标题：状态一句话，就绪时后面补上大小和日期。
  ///
  /// 大小和日期只在**已就绪**时才有意义——没下载时没有文件，损坏时那两个数字
  /// 只会让人以为文件是好的。
  String _subtitle(AppLocalizations appLocalizations) {
    final status = _status;
    if (status == null) {
      return appLocalizations.loading;
    }
    return switch (status.state) {
      SmartModelState.missing => appLocalizations.smartModelMissing,
      SmartModelState.damaged => appLocalizations.smartModelDamaged,
      SmartModelState.ready => [
        appLocalizations.smartModelReady,
        status.size.traffic.show,
        if (status.modified case final modified?) modified.show,
      ].join(' · '),
    };
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final status = _status;
    // 「没下载」和「损坏」都算不正常：前者让 LightGBM 空转，后者更狠——它会让
    // 内核起不来。两者都用错误色，具体差别在文案里说。
    final bad = status != null && status.state != SmartModelState.ready;
    final colorScheme = context.colorScheme;
    return ListItem(
      leading: Icon(
        bad ? Icons.gpp_maybe_outlined : Icons.dataset_outlined,
        color: bad ? colorScheme.error : null,
      ),
      title: Text(appLocalizations.smartModel),
      subtitle: Text(
        _subtitle(appLocalizations),
        style: bad ? TextStyle(color: colorScheme.error) : null,
      ),
      trailing: _downloading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: HeroSpinner(strokeWidth: 2),
            )
          : IconButton(
              tooltip: appLocalizations.download,
              onPressed: _download,
              icon: const Icon(Icons.download_outlined),
            ),
    );
  }
}

/// 让内核自己定期更新模型（内核 `lgbm-auto-update`）。
///
/// **默认关**：这是会花流量的事，用户没要求就不该替他开。
class SmartLgbmAutoUpdateItem extends ConsumerWidget {
  const SmartLgbmAutoUpdateItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final value = ref.watch(
      appSettingProvider.select((state) => state.smartLgbmAutoUpdate),
    );
    return ListItem.toggle(
      leading: const Icon(Icons.update_outlined),
      title: Text(appLocalizations.smartLgbmAutoUpdate),
      subtitle: Text(appLocalizations.smartLgbmAutoUpdateDesc),
      value: value,
      onChanged: (bool next) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(smartLgbmAutoUpdate: next));
      },
    );
  }
}

/// 自动更新关着时，「仅 Wi-Fi」和「更新间隔」都没有作用对象，整组收起来。
class _SmartLgbmAutoUpdateSection extends ConsumerWidget {
  const _SmartLgbmAutoUpdateSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoUpdate = ref.watch(
      appSettingProvider.select((state) => state.smartLgbmAutoUpdate),
    );
    return AnimatedSize(
      duration: Motion.quick,
      curve: Motion.move,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: autoUpdate
            ? const [SmartLgbmWifiOnlyItem(), SmartLgbmIntervalItem()]
            : const [],
      ),
    );
  }
}

/// 只在 Wi-Fi 下更新。**默认开。**
///
/// **这道闸只能在应用侧，内核做不到**：下载是内核发起的，它不知道自己现在走的
/// 是 Wi-Fi 还是流量。所以由应用判断当前网络类型，只有确实在 Wi-Fi 上时才把
/// `lgbm-auto-update: true` 下发下去（见 `SmartOptionsExt.lgbmAutoUpdateNow`
/// 与 `common/task.dart`）。
class SmartLgbmWifiOnlyItem extends ConsumerWidget {
  const SmartLgbmWifiOnlyItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final value = ref.watch(
      appSettingProvider.select((state) => state.smartLgbmWifiOnly),
    );
    return ListItem.toggle(
      leading: const Icon(Icons.wifi_outlined),
      title: Text(appLocalizations.smartLgbmWifiOnly),
      subtitle: Text(appLocalizations.smartLgbmWifiOnlyDesc),
      value: value,
      onChanged: (bool next) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(smartLgbmWifiOnly: next));
      },
    );
  }
}

/// 自动更新的间隔，单位小时（内核 `lgbm-update-interval`，默认 72）。
class SmartLgbmIntervalItem extends ConsumerWidget {
  const SmartLgbmIntervalItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final value = ref.watch(
      appSettingProvider.select((state) => state.smartLgbmUpdateInterval),
    );
    return ListItem.input(
      leading: const Icon(Icons.schedule_outlined),
      title: Text(appLocalizations.smartLgbmUpdateInterval),
      subtitle: Text(appLocalizations.smartLgbmUpdateIntervalDesc),
      trailing: Text('$value ${appLocalizations.hours}'),
      dialogTitle: appLocalizations.smartLgbmUpdateInterval,
      suffixText: appLocalizations.hours,
      resetValue: '$defaultSmartLgbmInterval',
      value: '$value',
      maxLength: TextInputLimits.interval,
      keyboardType: TextInputType.number,
      validator: (String? input) {
        if (input == null || input.isEmpty) {
          return appLocalizations.emptyTip(
            appLocalizations.smartLgbmUpdateInterval,
          );
        }
        if (int.tryParse(input) == null) {
          return appLocalizations.numberTip(
            appLocalizations.smartLgbmUpdateInterval,
          );
        }
        return null;
      },
      onChanged: (String? input) {
        if (input == null) {
          return;
        }
        // 0 或负数会让内核每次启动都立刻重下一遍模型（`update_lgbm.go` 是拿
        // 「距上次更新是否超过间隔」判断的），夹到至少 1 小时。
        final next = (int.tryParse(input) ?? defaultSmartLgbmInterval).clamp(
          1,
          1 << 20,
        );
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(smartLgbmUpdateInterval: next));
      },
    );
  }
}

/// 选路模型的尺寸。
///
/// 原来这里是一个「自己填下载地址」的输入框，默认留空（＝用内核内置地址，下的
/// 是标准版）。用户反馈「点进去是空的」——确实：想要更准的大模型，得先知道有
/// 三种尺寸、再自己找到 URL 填进去，等于把选择权藏起来了。
///
/// 现在直接给三档。三个地址与体积都实测确认过（HTTP 200 + Content-Length，
/// 2026-09-04），见 [SmartModelSize]。
///
/// 「自定义」这一档是为了不顶掉已经填过别的地址的人：只要现有地址不等于三个
/// 已知地址中的任何一个，就落在这一档，选中它会弹出输入框。
///
/// 手动下载按钮用的也是这里选定的地址，两边保持一致——否则会出现「自动更新下
/// 的是大模型、手动按钮下的是标准版」这种说不清的状态。
class SmartLgbmUrlItem extends ConsumerWidget {
  const SmartLgbmUrlItem({super.key});

  /// 当前地址对应哪一档。认不出来就是「自定义」。
  SmartModelSize? _sizeOf(String url) {
    if (url.isEmpty) {
      return SmartModelSize.standard;
    }
    for (final size in SmartModelSize.values) {
      if (size.url == url) {
        return size;
      }
    }
    return null;
  }

  String _label(BuildContext context, SmartModelSize? size) {
    final appLocalizations = context.appLocalizations;
    return switch (size) {
      SmartModelSize.standard => appLocalizations.smartModelSizeStandard,
      SmartModelSize.middle => appLocalizations.smartModelSizeMiddle,
      SmartModelSize.large => appLocalizations.smartModelSizeLarge,
      null => appLocalizations.smartModelSizeCustom,
    };
  }

  /// 每一档后面缀上体积，让用户选之前就知道要下多大。
  String _optionText(BuildContext context, SmartModelSize? size) {
    if (size == null) {
      return _label(context, null);
    }
    final mb = (size.bytes / 1048576).toStringAsFixed(1);
    return '${_label(context, size)} · $mb MB';
  }

  Future<void> _editCustom(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final appLocalizations = context.appLocalizations;
    final input = await globalState.showCommonDialog<String>(
      child: InputDialog(
        title: appLocalizations.smartLgbmUrl,
        value: current,
        maxLength: TextInputLimits.url,
        validator: (String? value) {
          if (value == null || value.isEmpty) {
            return appLocalizations.urlTip(appLocalizations.smartLgbmUrl);
          }
          final uri = Uri.tryParse(value);
          if (uri == null ||
              (!uri.isScheme('http') && !uri.isScheme('https'))) {
            return appLocalizations.urlTip(appLocalizations.smartLgbmUrl);
          }
          return null;
        },
      ),
    );
    if (input == null) {
      return;
    }
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(smartLgbmUrl: input));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final url = ref.watch(
      appSettingProvider.select((state) => state.smartLgbmUrl),
    );
    final current = _sizeOf(url);
    return ListItem<SmartModelSize?>.options(
      leading: const Icon(Icons.straighten),
      title: Text(appLocalizations.smartModelSize),
      subtitle: Text(appLocalizations.smartModelSizeDesc),
      trailing: Text(_label(context, current)),
      dialogTitle: appLocalizations.smartModelSize,
      options: const [...SmartModelSize.values, null],
      value: current,
      textBuilder: (size) => _optionText(context, size),
      onChanged: (SmartModelSize? next) {
        if (next == null) {
          // 选了「自定义」才弹输入框；不选就别打扰。
          _editCustom(context, ref, url);
          return;
        }
        ref
            .read(appSettingProvider.notifier)
            .update(
              // 标准版存空串，语义等同「用内核内置地址」，
              // 和以前的存档保持兼容。
              (state) => state.copyWith(
                smartLgbmUrl: next == SmartModelSize.standard ? '' : next.url,
              ),
            );
      },
    );
  }
}
