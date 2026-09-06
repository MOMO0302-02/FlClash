import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/proxies/common.dart';
import 'package:clash_party/views/proxies/selection_flight.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxyCard extends StatelessWidget {
  final String groupName;
  final Proxy proxy;
  final GroupType groupType;
  final ProxyCardType type;
  final String? testUrl;

  const ProxyCard({
    super.key,
    required this.groupName,
    required this.testUrl,
    required this.proxy,
    required this.groupType,
    required this.type,
  });

  Measure get measure => globalState.measure;

  void _handleTestCurrentDelay() {
    proxyDelayTest(proxy, testUrl);
  }

  Widget _buildDelayText(double selectedProgress) {
    return SizedBox(
      height: measure.labelSmallHeight,
      child: Consumer(
        builder: (context, ref, _) {
          final delay = ref.watch(
            delayProvider(proxyName: proxy.name, testUrl: testUrl),
          );
          // 选中后整块是主色，延迟的分档色仍然要保留——它是这一栏唯一的语义信号。
          // 只有「还没测过」那个入口跟着前景色走，免得蓝底上再糊一块蓝。
          final untestedColor = Color.lerp(
            context.styleTokens.accent(context.colorScheme),
            context.styleTokens.selectedForeground(context.colorScheme),
            selectedProgress,
          );
          return FadeThroughBox(
            alignment: type == ProxyCardType.expand
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: delay == 0 || delay == null
                ? SizedBox(
                    height: measure.labelSmallHeight,
                    width: measure.labelSmallHeight,
                    child: delay == 0
                        // 照抄桌面端的转圈（HeroUI Spinner），不用 FlClash
                        // 自带的那个 M3 多边形变形加载器。颜色跟着延迟分档色走，
                        // 对应桌面端 `<Button isLoading color={delayColor(delay)}>`。
                        ? HeroSpinner(color: utils.getDelayColor(delay))
                        : IconButton(
                            icon: const Icon(Icons.bolt),
                            iconSize: globalState.measure.labelSmallHeight,
                            padding: EdgeInsets.zero,
                            color: untestedColor,
                            onPressed: _handleTestCurrentDelay,
                          ),
                  )
                // 点这个数字会重测一次，可它只有十几像素高、又没有水波纹，
                // 按下去完全没有回应。缩一下是这里唯一能给的「按到了」。
                : PressableScale(
                    scale: 0.88,
                    onTap: _handleTestCurrentDelay,
                    child: Text(
                      delay > 0 ? '$delay ms' : 'Timeout',
                      style: context.textTheme.labelSmall?.copyWith(
                        overflow: TextOverflow.ellipsis,
                        color: utils.getDelayColor(delay),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildProxyNameText(BuildContext context, double selectedProgress) {
    final style = context.textTheme.bodyMedium?.copyWith(
      color: Color.lerp(
        context.colorScheme.onSurface,
        context.styleTokens.selectedForeground(context.colorScheme),
        selectedProgress,
      ),
    );
    if (type == ProxyCardType.min) {
      return SizedBox(
        height: measure.bodyMediumHeight * 1,
        child: EmojiText(
          proxy.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      );
    } else {
      return SizedBox(
        height: measure.bodyMediumHeight * 2,
        child: EmojiText(
          proxy.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      );
    }
  }

  Future<void> _changeProxy(BuildContext context) async {
    final isComputedSelected = groupType.isComputedSelected;
    final isSelector = groupType == GroupType.Selector;
    final ref = globalState.container;
    if (isComputedSelected || isSelector) {
      final currentProxyName = ref.read(proxyNameProvider(groupName));
      final nextProxyName = switch (isComputedSelected) {
        true => currentProxyName == proxy.name ? '' : proxy.name,
        false => proxy.name,
      };
      // 必须在改状态之前读：一旦更新，「原来选中的是谁」就查不到了，
      // 也就没法告诉飞行层这一下是从哪张卡挪过来的。
      final previousProxyName = ref.read(selectedProxyNameProvider(groupName));
      ProxySelectionFlight.maybeOf(context)?.fly(
        groupName: groupName,
        fromProxy: previousProxyName ?? '',
        toProxy: nextProxyName,
      );
      ref
          .read(profilesActionProvider.notifier)
          .updateCurrentSelectedMap(groupName, nextProxyName);
      ref
          .read(proxiesActionProvider.notifier)
          .changeProxyDebounce(groupName, nextProxyName);
      return;
    }
    globalState.showNotifier(currentAppLocalizations.notSelectedTip);
  }

  Widget _buildBody(BuildContext context, double selectedProgress) {
    final measure = globalState.measure;
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProxyNameText(context, selectedProgress),
          const SizedBox(height: 8),
          if (type == ProxyCardType.expand) ...[
            SizedBox(
              height: measure.bodySmallHeight,
              child: _ProxyDesc(
                proxy: proxy,
                selectedProgress: selectedProgress,
              ),
            ),
            const SizedBox(height: 6),
            _buildDelayText(selectedProgress),
          ] else
            SizedBox(
              height: measure.bodySmallHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    flex: 1,
                    child: _ProxyTypeTag(
                      label: proxy.type,
                      selectedProgress: selectedProgress,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildDelayText(selectedProgress),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final selectedProxyName = ref.watch(
          selectedProxyNameProvider(groupName),
        );
        // 选中态由 CommonCard 统一处理：整块填主色 + 白字 + 往外冒一圈蓝光。
        // 卡片里那些次级文字不会自动跟着换色，所以 isSelected 必须一路传下去。
        final isSelected = selectedProxyName == proxy.name;
        return ProxySelectionAnchor(
          groupName: groupName,
          proxyName: proxy.name,
          child: Stack(
            children: [
              CommonCard(
                key: key,
                onPressed: () => _changeProxy(context),
                isSelected: isSelected,
                // 底色由 CommonCard 里的 Material 自己渐变过去，可卡片里的文字、
                // 小标签是直接按 isSelected 选色的，会在底色还在渐变时**当场**变白。
                // 用同一个 0→1 的进度把它们一起带过去，两件事才像一件事。
                //
                // 包在 child 里而不是包住整张 CommonCard：这样逐帧重建的只有卡片
                // 内容，不会连按钮和阴影层一起重造。
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: isSelected ? 1.0 : 0.0),
                  // 对齐 Material 换背景色的默认时长（200ms），快慢差太多会分家。
                  duration: Motion.quick,
                  curve: Motion.move,
                  builder: (context, value, _) => _buildBody(context, value),
                ),
              ),
              if (groupType.isComputedSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _ProxyComputedMark(
                    groupName: groupName,
                    proxy: proxy,
                    isSelected: isSelected,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 协议类型的小标签。桌面端把它画成一个浅底圆角的小块（`bg-default-100`），
/// 不是一行裸文字——这一块是节点卡片上最容易看出「照没照着桌面端做」的细节。
class _ProxyTypeTag extends StatelessWidget {
  const _ProxyTypeTag({required this.label, required this.selectedProgress});

  final String label;
  final double selectedProgress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.styleTokens;
    final colorScheme = context.colorScheme;
    final selectedFg = tokens.selectedForeground(colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        // 选中后底是主色，再铺一层灰底就糊成一片；改用半透明的白，
        // 保住「小块标签」的形态又能读得出来。
        color: Color.lerp(
          colorScheme.surfaceContainerHighest,
          selectedFg.withValues(alpha: 0.18),
          selectedProgress,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: context.textTheme.bodySmall?.copyWith(
          overflow: TextOverflow.ellipsis,
          color: Color.lerp(
            colorScheme.onSurfaceVariant,
            selectedFg,
            selectedProgress,
          ),
        ),
      ),
    );
  }
}

class _ProxyDesc extends ConsumerWidget {
  final Proxy proxy;
  final double selectedProgress;

  const _ProxyDesc({required this.proxy, required this.selectedProgress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desc = ref.watch(proxyDescProvider(proxy));
    final colorScheme = context.colorScheme;
    return EmojiText(
      desc,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.bodySmall?.copyWith(
        color: Color.lerp(
          colorScheme.onSurfaceVariant,
          context.styleTokens.selectedForeground(colorScheme).opacity80,
          selectedProgress,
        ),
      ),
    );
  }
}

/// 自动选路的组（Smart / url-test 之类）里，内核实际选中的那个节点上打的勾。
class _ProxyComputedMark extends ConsumerWidget {
  final String groupName;
  final Proxy proxy;
  final bool isSelected;

  const _ProxyComputedMark({
    required this.groupName,
    required this.proxy,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxyName = ref.watch(proxyNameProvider(groupName));
    // 内核换了选路结果时，这个勾原来是在一张卡上凭空消失、在另一张上凭空出现。
    // 改成缩放淡出淡入：不是用户点出来的变化，用缓动而不是弹簧。
    //
    // 不再用「不匹配就返回 SizedBox」：那样一来 Widget 直接从树上消失，
    // 没有任何东西可以拿来做退场。它待在 Positioned 里，撑着也不影响卡片布局。
    final visible = proxyName == proxy.name;
    final tokens = context.styleTokens;
    final colorScheme = context.colorScheme;
    final accent = tokens.accent(colorScheme);
    final selectedFg = tokens.selectedForeground(colorScheme);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: visible ? 1.0 : 0.0),
      duration: Motion.normal,
      curve: visible ? Motion.enter : Motion.exit,
      builder: (context, appear, child) {
        if (appear == 0) {
          return const SizedBox.shrink();
        }
        return Opacity(
          opacity: appear.clamp(0.0, 1.0),
          child: Transform.scale(scale: appear, child: child),
        );
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: isSelected ? 1.0 : 0.0),
        duration: Motion.quick,
        curve: Motion.move,
        builder: (context, selectedProgress, _) {
          return Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // 卡片本身已经是主色时，勾要反过来画，不然蓝上加蓝等于没有。
              color: Color.lerp(accent, selectedFg, selectedProgress),
            ),
            child: Icon(
              Icons.check,
              size: 12,
              color: Color.lerp(selectedFg, accent, selectedProgress),
            ),
          );
        },
      ),
    );
  }
}
