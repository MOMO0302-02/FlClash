import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/plugins/app.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 数据流式列表里的一条：外面套一层和设置分组卡片一样的圆角卡片。
///
/// 桌面端的连接页与日志页也是「一条一张卡」（`components/connections/
/// connection-item.tsx`），而不是通栏平铺 + 整宽分隔线——后者是 Material 的默认
/// 样子，和这个 app 其它地方（磁贴、设置分组卡）对不上。
///
/// 取值全部走 `styleTokens`，所以换风格时圆角、高光边、阴影会跟着走。
class StreamItemCard extends StatelessWidget {
  final Widget child;

  const StreamItemCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = context.styleTokens;
    final borderRadius = BorderRadius.circular(tokens.cardRadius);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: tokens.cardShadow,
          border: Border.all(color: tokens.rim, width: 1),
        ),
        // 用 Material 而不是带背景色的 Container：里面装的是 ListTile，
        // 普通容器会让它的水波纹画不出来。
        child: Material(
          clipBehavior: Clip.antiAlias,
          color: context.colorScheme.surfaceContainerLow,
          borderRadius: borderRadius,
          child: child,
        ),
      ),
    );
  }
}

/// 桌面端那种空心胶囊（HeroUI 的 `Chip variant="bordered"`）：透明底 + 一圈
/// 描边 + 同色文字，而不是 Material `ActionChip` 那种灰底实心块。
///
/// `color` 为空时用次要文字色（桌面端多数胶囊就是中性的），传强调色才是蓝的。
class StreamPill extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const StreamPill({super.key, required this.label, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.styleTokens;
    final foreground = color ?? context.colorScheme.onSurfaceVariant;
    final borderRadius = BorderRadius.circular(tokens.controlRadius);
    return Center(
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: foreground.opacity60, width: 1),
            ),
            child: Text(
              label,
              maxLines: 1,
              style: context.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

/// 提到外面只建一次。原来写在 `_getTitleText()` 里，而那个方法在连接页
/// 每秒整表刷新时，会被每一张可见卡片各调一次——等于每秒重新编译十几个正则。
final _exeSuffix = RegExp(r'\.exe$');

class TrackerInfoItem extends ConsumerWidget {
  final TrackerInfo trackerInfo;
  final Function(String)? onClickKeyword;
  final Widget? trailing;
  final String detailTitle;

  const TrackerInfoItem({
    super.key,
    required this.trackerInfo,
    this.onClickKeyword,
    this.trailing,
    required this.detailTitle,
  });

  static double get subTitleHeight {
    return globalState.measure.bodySmallHeight + 20;
  }

  /// **不要写成 `async`**：`async` 每次都会包出一个新的 Future，
  /// [App.getPackageIcon] 那层按包名做的缓存就白做了——FutureBuilder 比的是
  /// Future 的身份，拿到新对象就重置回 waiting，图标当场闪没，并且再打一次
  /// 平台通道。直接把缓存里的那个 Future 原样传出去。
  Future<ImageProvider?>? _getPackageIcon(TrackerInfo connection) {
    return app?.getPackageIcon(connection.metadata.process);
  }

  /// 桌面端的连接卡片标题是「进程 → 目标」（`components/connections/
  /// connection-item.tsx`），不是 `tcp://host:port` 这种协议串。协议移到下面
  /// 的胶囊里，标题只回答「谁在连哪」。
  String _getTitleText() {
    final metadata = trackerInfo.metadata;
    final process = metadata.process.replaceFirst(_exeSuffix, '');
    final source = process.isNotEmpty ? process : metadata.sourceIP;
    final destination = [
      metadata.host,
      metadata.destinationIP,
      metadata.remoteDestination,
    ].firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final target = destination.isNotEmpty && metadata.destinationPort.isNotEmpty
        ? '$destination:${metadata.destinationPort}'
        : destination;
    if (source.isEmpty) return target;
    if (target.isEmpty) return source;
    return '$source → $target';
  }

  /// 卡片下方那排胶囊，顺序照桌面端：协议 → 代理链 → 累计流量 → 实时速度。
  List<Widget> _buildPills(BuildContext context) {
    final metadata = trackerInfo.metadata;
    final uploadSpeed = trackerInfo.uploadSpeed ?? 0;
    final downloadSpeed = trackerInfo.downloadSpeed ?? 0;
    return [
      if (metadata.network.isNotEmpty)
        StreamPill(label: metadata.network.toUpperCase()),
      for (final chain in trackerInfo.chains)
        StreamPill(
          label: chain,
          onTap: onClickKeyword == null ? null : () => onClickKeyword!(chain),
        ),
      StreamPill(
        label:
            '↑ ${trackerInfo.upload.traffic.show} '
            '↓ ${trackerInfo.download.traffic.show}',
      ),
      // 只有真的在跑流量时才出现，且用强调色——桌面端也是唯一一个 primary 胶囊。
      if (uploadSpeed > 0 || downloadSpeed > 0)
        StreamPill(
          label:
              '↑ ${uploadSpeed.traffic.show}/s '
              '↓ ${downloadSpeed.traffic.show}/s',
          color: context.styleTokens.accent(context.colorScheme),
        ),
    ];
  }

  @override
  Widget build(BuildContext context, ref) {
    final value = ref.watch(
      patchClashConfigProvider.select(
        (state) =>
            state.findProcessMode == FindProcessMode.always && system.isAndroid,
      ),
    );
    final pills = _buildPills(context);
    // 用 LayoutBuilder 是为了给时间一个**按比例**的宽度上限。
    //
    // 时间这一项没有 flex，Row 会先按它的自然宽度排；而它是本地化的相对时间，
    // 俄语的「8 месяцев назад」比中文的「8 个月前」长一大截，再叠上 1.4 倍字号，
    // 窄屏上有可能一个人就把整行占满、把标题挤成 0 宽还继续往外顶。
    //
    // 这里不能改成 Flexible：Expanded 和 Flexible 各占一半 flex，标题会被**永远**
    // 钉在 50% 宽上；也不能只加省略号——没有约束的话它按自然宽度排，省略号根本
    // 不会触发。给一个 40% 的上限既不动常规情况的排版（标题仍靠 Expanded 吃掉
    // 全部余量、时间照旧贴在右侧），又保证最坏情况下时间自己先截断。
    final title = LayoutBuilder(
      builder: (context, constraints) => Row(
        spacing: 8,
        children: [
          Expanded(
            child: Text(
              _getTitleText(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyLarge,
            ),
          ),
          // 时间挪到标题右侧（桌面端就在这），下面那行整行让给胶囊。
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.4),
            child: Text(
              trackerInfo.start.getLastUpdateTimeDesc(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
    final subTitle = SizedBox(
      height: subTitleHeight,
      child: ListView.separated(
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        padding: EdgeInsets.zero,
        scrollDirection: Axis.horizontal,
        itemCount: pills.length,
        itemBuilder: (_, index) => pills[index],
      ),
    );
    final icon = value
        ? GestureDetector(
            onTap: () {
              if (onClickKeyword == null) return;
              final process = trackerInfo.metadata.process;
              if (process.isEmpty) return;
              onClickKeyword!(process);
            },
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              width: 42,
              height: 42,
              child: FutureBuilder<ImageProvider?>(
                future: _getPackageIcon(trackerInfo),
                builder: (_, snapshot) {
                  if (!snapshot.hasData && snapshot.data == null) {
                    return Container();
                  } else {
                    return Image(
                      image: snapshot.data!,
                      gaplessPlayback: true,
                      width: 42,
                      height: 42,
                    );
                  }
                },
              ),
            ),
          )
        : null;
    return StreamItemCard(
      child: ListItem(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () {
          showExtend(
            context,
            builder: (_) {
              return AdaptiveSheetScaffold(
                body: TrackerInfoDetailView(trackerInfo: trackerInfo),
                title: detailTitle,
              );
            },
          );
        },
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              spacing: 12,
              children: [
                ?icon,
                // 用 Expanded 而不是 Flexible：标题行里的 Expanded 需要一个
                // 有界宽度，松约束下会当场报无法布局。
                Expanded(child: title),
              ],
            ),
            const SizedBox(height: 8),
            subTitle,
          ],
        ),
      ),
    );
  }
}

class TrackerInfoDetailView extends StatelessWidget {
  final TrackerInfo trackerInfo;

  const TrackerInfoDetailView({super.key, required this.trackerInfo});

  String _getRuleText() {
    final rule = trackerInfo.rule;
    final rulePayload = trackerInfo.rulePayload;
    if (rulePayload.isNotEmpty) {
      return '$rule($rulePayload)';
    }
    return rule;
  }

  String _getProcessText() {
    final process = trackerInfo.metadata.process;
    final uid = trackerInfo.metadata.uid;
    if (uid != 0) {
      return '$process($uid)';
    }
    return process;
  }

  String _getSourceText() {
    final sourceIP = trackerInfo.metadata.sourceIP;
    if (sourceIP.isEmpty) {
      return '';
    }
    final sourcePort = trackerInfo.metadata.sourcePort;
    if (sourcePort.isNotEmpty) {
      return '$sourceIP:$sourcePort';
    }
    return sourceIP;
  }

  String _getDestinationText() {
    final destinationIP = trackerInfo.metadata.destinationIP;
    if (destinationIP.isEmpty) {
      return '';
    }
    final destinationPort = trackerInfo.metadata.destinationPort;
    if (destinationPort.isNotEmpty) {
      return '$destinationIP:$destinationPort';
    }
    return destinationIP;
  }

  /// 详情页里所有值都可以点一下复制。
  ///
  /// 原来标题旁挂着一个复制按钮，`onPressed` 是空的——点了没反应；代理链的
  /// 胶囊也是同样的空回调。整行/整块可点比一个 18 像素的图标好按，也与网络检测
  /// 详情页的做法一致。
  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      context.showNotifier(context.appLocalizations.copySuccess);
    }
  }

  Widget _buildChains(BuildContext context) {
    final chains = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        for (final chain in trackerInfo.chains)
          StreamPill(
            label: chain,
            onTap: () {
              _copy(context, chain);
            },
          ),
      ],
    );
    return ListItem(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          Text(context.appLocalizations.proxyChains),
          Flexible(child: chains),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required String title,
    required String desc,
  }) {
    return ListItem(
      onTap: () {
        _copy(context, desc);
      },
      title: Row(
        spacing: 16,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          Flexible(child: Text(desc, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final items = [
      _buildItem(
        context,
        title: appLocalizations.creationTime,
        desc: trackerInfo.start.showFull,
      ),
      if (_getProcessText().isNotEmpty)
        _buildItem(
          context,
          title: appLocalizations.process,
          desc: _getProcessText(),
        ),
      _buildItem(
        context,
        title: appLocalizations.networkType,
        desc: trackerInfo.metadata.network,
      ),
      _buildItem(context, title: appLocalizations.rule, desc: _getRuleText()),
      if (trackerInfo.metadata.host.isNotEmpty)
        _buildItem(
          context,
          title: appLocalizations.host,
          desc: trackerInfo.metadata.host,
        ),
      if (_getSourceText().isNotEmpty)
        _buildItem(
          context,
          title: appLocalizations.source,
          desc: _getSourceText(),
        ),
      if (_getDestinationText().isNotEmpty)
        _buildItem(
          context,
          title: appLocalizations.destination,
          desc: _getDestinationText(),
        ),
      _buildItem(
        context,
        title: appLocalizations.upload,
        desc: trackerInfo.upload.traffic.show,
      ),
      _buildItem(
        context,
        title: appLocalizations.download,
        desc: trackerInfo.download.traffic.show,
      ),
      if (trackerInfo.metadata.destinationGeoIP.isNotEmpty)
        _buildItem(
          context,
          title: appLocalizations.destinationGeoIP,
          desc: trackerInfo.metadata.destinationGeoIP.join(' '),
        ),
      if (trackerInfo.metadata.destinationIPASN.isNotEmpty)
        _buildItem(
          context,
          title: appLocalizations.destinationIPASN,
          desc: trackerInfo.metadata.destinationIPASN,
        ),
      if (trackerInfo.metadata.dnsMode != null)
        _buildItem(
          context,
          title: appLocalizations.dnsMode,
          desc: trackerInfo.metadata.dnsMode!.name,
        ),
      if (trackerInfo.metadata.specialProxy.isNotEmpty)
        _buildItem(
          context,
          title: appLocalizations.specialProxy,
          desc: trackerInfo.metadata.specialProxy,
        ),
      if (trackerInfo.metadata.specialRules.isNotEmpty)
        _buildItem(
          context,
          title: appLocalizations.specialRules,
          desc: trackerInfo.metadata.specialRules,
        ),
      if (trackerInfo.metadata.remoteDestination.isNotEmpty)
        _buildItem(
          context,
          title: appLocalizations.remoteDestination,
          desc: trackerInfo.metadata.remoteDestination,
        ),
      _buildChains(context),
    ];
    return SelectionArea(
      // 走 generateSection：详情是一组属性，桌面端的详情弹窗也是一张卡片里
      // 一行一条。原来是通栏平铺的 ListView，是 Material 的默认样子。
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: generateSection(items: items),
      ),
    );
  }
}
