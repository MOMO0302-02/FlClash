import 'package:clash_party/common/common.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 域名嗅探设置页。
///
/// 对应桌面版 `src/renderer/src/pages/sniffer.tsx`，那一页共 11 项：总开关、
/// override-destination、force-dns-mapping、parse-pure-ip、HTTP/TLS/QUIC 三个
/// 端口输入框、skip-domain、force-domain、skip-dst-address、skip-src-address。
/// 这里逐项照抄，**顺序也照抄**，只按手机的习惯做了三处调整：
///
/// 1. 总开关关掉时下面整组收起来（同 `smart.dart` 的做法）。关掉时应用根本不下发
///    这一整段（见 `common/task.dart`），下面那些拨了确实什么都不会发生，灰着留在
///    那儿只会让人以为有用。
/// 2. 桌面版的端口是一个逗号分隔的输入框；这里改成本应用一贯的 [ListInputPage]
///    列表页，一条一行，省得在手机上对着长串逗号数位置。
/// 3. 桌面版三个协议的键恒定存在、只能改端口；这里每个协议多了一个开关。因为
///    **内核只加载 `sniff` 表里出现过的协议键**（`config/config.go` 的
///    `parseSniffer` 拿 `sniff` 的键去比对 `snifferTypes.List`），"不嗅探某协议"
///    只能靠把键删掉表达，桌面版那种写法做不到。
class SnifferView extends StatelessWidget {
  const SnifferView({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: context.appLocalizations.sniffer,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ...generateSection(isFirst: true, items: const [SnifferEnableItem()]),
          const _SnifferOptionsSection(),
        ],
      ),
    );
  }
}

class SnifferEnableItem extends ConsumerWidget {
  const SnifferEnableItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final enable = ref.watch(
      patchClashConfigProvider.select((state) => state.sniffer.enable),
    );
    return ListItem.toggle(
      leading: const Icon(Icons.travel_explore_outlined),
      title: Text(appLocalizations.sniffer),
      subtitle: Text(appLocalizations.snifferDesc),
      value: enable,
      onChanged: (bool value) {
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.sniffer(enable: value));
      },
    );
  }
}

class _SnifferOptionsSection extends ConsumerWidget {
  const _SnifferOptionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final enable = ref.watch(
      patchClashConfigProvider.select((state) => state.sniffer.enable),
    );
    return AnimatedSize(
      duration: Motion.quick,
      curve: Motion.move,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: enable
            ? [
                ...generateSection(
                  title: appLocalizations.options,
                  items: const [
                    SnifferOverrideDestItem(),
                    SnifferForceDnsMappingItem(),
                    SnifferParsePureIpItem(),
                  ],
                ),
                ...generateSection(
                  title: appLocalizations.snifferProtocols,
                  items: const [
                    _SnifferProtocolGroup(protocol: 'HTTP'),
                    _SnifferProtocolGroup(protocol: 'TLS'),
                    _SnifferProtocolGroup(protocol: 'QUIC'),
                    // 端口列表留空 = 用内核默认端口（HTTP 80、TLS 443、QUIC 443，
                    // 见内核 `component/sniffer/*_sniffer.go` 里那三段
                    // `if len(ports) == 0`）。这件事只说一次，不用在每个协议底下
                    // 重复。
                    _SnifferPortsHintItem(),
                  ],
                ),
                ...generateSection(
                  title: appLocalizations.snifferFilters,
                  items: const [
                    SnifferSkipDomainItem(),
                    SnifferForceDomainItem(),
                    SnifferSkipDstAddressItem(),
                    SnifferSkipSrcAddressItem(),
                  ],
                ),
              ]
            : const [],
      ),
    );
  }
}

class SnifferOverrideDestItem extends ConsumerWidget {
  const SnifferOverrideDestItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final value = ref.watch(
      patchClashConfigProvider.select((state) => state.sniffer.overrideDest),
    );
    return ListItem.toggle(
      leading: const Icon(Icons.alt_route_outlined),
      title: Text(appLocalizations.snifferOverrideDest),
      subtitle: Text(appLocalizations.snifferOverrideDestDesc),
      value: value,
      onChanged: (bool next) {
        ref.read(patchClashConfigProvider.notifier).update((state) {
          // HTTP 那一条要跟着一起改，抄的是桌面版 `sniffer.tsx:157-176` 同一个
          // 开关里的动作。内核 `parseSniffer` 里协议自己的 override-destination
          // **优先于全局那个**，而 HTTP 这一条我们的出厂值明写着 false——不跟着
          // 改的话，用户把全局开关打开，HTTP 流量依然我行我素。
          final sniff = Map<String, SnifferConfig>.from(state.sniffer.sniff);
          final http = sniff['HTTP'];
          if (http != null) {
            sniff['HTTP'] = http.copyWith(overrideDest: next);
          }
          return state.copyWith.sniffer(overrideDest: next, sniff: sniff);
        });
      },
    );
  }
}

class SnifferForceDnsMappingItem extends ConsumerWidget {
  const SnifferForceDnsMappingItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final value = ref.watch(
      patchClashConfigProvider.select((state) => state.sniffer.forceDnsMapping),
    );
    return ListItem.toggle(
      leading: const Icon(Icons.dns_outlined),
      title: Text(appLocalizations.snifferForceDnsMapping),
      subtitle: Text(appLocalizations.snifferForceDnsMappingDesc),
      value: value,
      onChanged: (bool next) {
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.sniffer(forceDnsMapping: next));
      },
    );
  }
}

class SnifferParsePureIpItem extends ConsumerWidget {
  const SnifferParsePureIpItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final value = ref.watch(
      patchClashConfigProvider.select((state) => state.sniffer.parsePureIp),
    );
    return ListItem.toggle(
      leading: const Icon(Icons.numbers_outlined),
      title: Text(appLocalizations.snifferParsePureIp),
      subtitle: Text(appLocalizations.snifferParsePureIpDesc),
      value: value,
      onChanged: (bool next) {
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.sniffer(parsePureIp: next));
      },
    );
  }
}

/// 一个协议的两行：开关 + 端口。端口那一行只在开关开着时出现。
class _SnifferProtocolGroup extends ConsumerWidget {
  const _SnifferProtocolGroup({required this.protocol});

  final String protocol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.sniffer.sniff.containsKey(protocol),
      ),
    );
    return AnimatedSize(
      duration: Motion.quick,
      curve: Motion.move,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SnifferProtocolItem(protocol: protocol),
          if (enabled) SnifferProtocolPortsItem(protocol: protocol),
        ],
      ),
    );
  }
}

class _SnifferPortsHintItem extends StatelessWidget {
  const _SnifferPortsHintItem();

  @override
  Widget build(BuildContext context) {
    return ListItem(
      leading: const Icon(Icons.info_outline),
      title: Text(context.appLocalizations.snifferPortsDesc),
    );
  }
}

class SnifferProtocolItem extends ConsumerWidget {
  const SnifferProtocolItem({super.key, required this.protocol});

  final String protocol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final enabled = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.sniffer.sniff.containsKey(protocol),
      ),
    );
    return ListItem.toggle(
      title: Text(protocol),
      // QUIC 单独给一段说明：安卓上它不是可有可无的边角协议，Chrome 默认就走它。
      // 另外两个协议的行为一看名字就懂，不用赘述。
      subtitle: protocol == 'QUIC'
          ? Text(appLocalizations.snifferQuicDesc)
          : null,
      value: enabled,
      onChanged: (bool next) {
        ref.read(patchClashConfigProvider.notifier).update((state) {
          final sniff = Map<String, SnifferConfig>.from(state.sniffer.sniff);
          if (next) {
            // 端口给空列表——那正好是"用内核默认端口"的写法（HTTP 80、TLS 443、
            // QUIC 443）。不猜一个端口塞进去，用户想改自己去下面那行填。
            sniff[protocol] = const SnifferConfig();
          } else {
            // 删键而不是留一个空配置：内核只加载表里出现过的协议键，留着就等于
            // 没关掉。
            sniff.remove(protocol);
          }
          return state.copyWith.sniffer(sniff: sniff);
        });
      },
    );
  }
}

class SnifferProtocolPortsItem extends ConsumerWidget {
  const SnifferProtocolPortsItem({super.key, required this.protocol});

  final String protocol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final ports = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.sniffer.sniff[protocol]?.ports ?? const <String>[],
      ),
    );
    final title = '$protocol ${appLocalizations.snifferPorts}';
    return ListItem.open(
      title: Text(title),
      // 空列表不是"没端口"，是"用内核默认端口"。这一行必须说出来，否则用户看到
      // 空的以为自己漏填了。
      subtitle: Text(
        ports.isEmpty ? appLocalizations.snifferPortsDefault : ports.join(', '),
      ),
      blur: false,
      widget: ListInputPage(
        title: title,
        items: ports,
        itemMaxLength: TextInputLimits.port,
        titleBuilder: (item) => Text(item),
      ),
      onChanged: (items) {
        ref.read(patchClashConfigProvider.notifier).update((state) {
          final sniff = Map<String, SnifferConfig>.from(state.sniffer.sniff);
          final current = sniff[protocol];
          if (current == null) {
            return state;
          }
          sniff[protocol] = current.copyWith(
            ports: List<String>.from(items as Iterable),
          );
          return state.copyWith.sniffer(sniff: sniff);
        });
      },
    );
  }
}

class SnifferSkipDomainItem extends ConsumerWidget {
  const SnifferSkipDomainItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final items = ref.watch(
      patchClashConfigProvider.select((state) => state.sniffer.skipDomain),
    );
    return ListItem.open(
      title: Text(appLocalizations.snifferSkipDomain),
      subtitle: Text(appLocalizations.snifferSkipDomainDesc),
      blur: false,
      widget: ListInputPage(
        title: appLocalizations.snifferSkipDomain,
        items: items,
        itemMaxLength: TextInputLimits.domain,
        titleBuilder: (item) => Text(item),
      ),
      onChanged: (value) {
        ref
            .read(patchClashConfigProvider.notifier)
            .update(
              (state) => state.copyWith.sniffer(
                skipDomain: List<String>.from(value as Iterable),
              ),
            );
      },
    );
  }
}

class SnifferForceDomainItem extends ConsumerWidget {
  const SnifferForceDomainItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final items = ref.watch(
      patchClashConfigProvider.select((state) => state.sniffer.forceDomain),
    );
    return ListItem.open(
      title: Text(appLocalizations.snifferForceDomain),
      subtitle: Text(appLocalizations.snifferForceDomainDesc),
      blur: false,
      widget: ListInputPage(
        title: appLocalizations.snifferForceDomain,
        items: items,
        itemMaxLength: TextInputLimits.domain,
        titleBuilder: (item) => Text(item),
      ),
      onChanged: (value) {
        ref
            .read(patchClashConfigProvider.notifier)
            .update(
              (state) => state.copyWith.sniffer(
                forceDomain: List<String>.from(value as Iterable),
              ),
            );
      },
    );
  }
}

class SnifferSkipDstAddressItem extends ConsumerWidget {
  const SnifferSkipDstAddressItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final items = ref.watch(
      patchClashConfigProvider.select((state) => state.sniffer.skipDstAddress),
    );
    return ListItem.open(
      title: Text(appLocalizations.snifferSkipDstAddress),
      subtitle: Text(appLocalizations.snifferSkipDstAddressDesc),
      blur: false,
      maxWidth: 360,
      widget: ListInputPage(
        title: appLocalizations.snifferSkipDstAddress,
        items: items,
        itemMaxLength: TextInputLimits.cidr,
        titleBuilder: (item) => Text(item),
      ),
      onChanged: (value) {
        ref
            .read(patchClashConfigProvider.notifier)
            .update(
              (state) => state.copyWith.sniffer(
                skipDstAddress: List<String>.from(value as Iterable),
              ),
            );
      },
    );
  }
}

class SnifferSkipSrcAddressItem extends ConsumerWidget {
  const SnifferSkipSrcAddressItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final items = ref.watch(
      patchClashConfigProvider.select((state) => state.sniffer.skipSrcAddress),
    );
    return ListItem.open(
      title: Text(appLocalizations.snifferSkipSrcAddress),
      subtitle: Text(appLocalizations.snifferSkipSrcAddressDesc),
      blur: false,
      maxWidth: 360,
      widget: ListInputPage(
        title: appLocalizations.snifferSkipSrcAddress,
        items: items,
        itemMaxLength: TextInputLimits.cidr,
        titleBuilder: (item) => Text(item),
      ),
      onChanged: (value) {
        ref
            .read(patchClashConfigProvider.notifier)
            .update(
              (state) => state.copyWith.sniffer(
                skipSrcAddress: List<String>.from(value as Iterable),
              ),
            );
      },
    );
  }
}
