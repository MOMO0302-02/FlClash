import 'dart:math' as math;

import 'package:clash_party/common/common.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/profiles/add.dart';
import 'package:clash_party/widgets/speed_sparkline.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 状态总览块。
///
/// 设计意图：把「我现在从哪出去」放到最显眼的位置。FlClash 原本首屏最大的一块是
/// 网速折线图，但日常最常看的其实是出口 IP 和当前节点——曲线好不好看无所谓。
/// 未连接时整块转为中性色，避免用蓝色暗示「已连接」。
///
/// 连接 / 断开是这个 app 最重要的一次状态变化，所以整块的底色、文字色、按钮圆的
/// 配色都由同一个 0→1 的过渡量驱动，一起渐变过去，而不是各自「啪」地换掉。
///
/// **用缓动而不是弹簧**：虽然是用户点出来的，但内核启动要花时间，`runTime` 是过
/// 一会儿才异步变成非空的——用户早就松手了，这一下在他看来是「系统回话了」而不是
/// 「我按下去了」。再说颜色过冲也没有物理含义。
///
/// ## 为什么把「网络速度」并进来
///
/// 原来首屏顶上是两块 8×2 的大砖：这一块讲「连没连上、从哪出去」，紧接着一块
/// 只画一条速率折线。**两块都在讲同一件事——现在通不通**，却各占两行，首屏一半
/// 面积就没了，而且折线那块除了曲线什么信息都没有。桌面端从来就只有一张卡：
/// 曲线是**卡片的背景**，速率数字缩在右上角，主角仍然是状态本身
/// （`components/sider/conn-card.tsx`）。这里照着做：曲线沉到背景，速率并进来，
/// 省下的一整块 8×2 还给用户自己排。
class StatusHero extends ConsumerWidget {
  const StatusHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.styleTokens;
    final colorScheme = context.colorScheme;

    // 只取「是否已连接」这一个布尔值。原来 watch 的是完整的 runTime，而它每秒都
    // 在变——整块（包括下面那个 380 毫秒的底色过渡）会跟着每秒重建一次，动画永远
    // 跑不完还白白重排一遍。时长文本改由最底下单独的 Consumer 订阅。
    final isStart = ref.watch(runTimeProvider.select((state) => state != null));
    final detection = ref.watch(networkDetectionProvider);
    final groupName = ref.watch(
      currentProfileProvider.select((state) => state?.currentGroupName),
    );
    final selectedMap = ref.watch(selectedMapProvider);
    final node = groupName == null ? null : selectedMap[groupName];
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );

    final accent = tokens.accent(colorScheme);
    final onAccent = tokens.onAccent(colorScheme);

    final ip = detection.ipInfo?.ip;
    // 没有订阅时点了也起不来，所以这块直接变成「去添加订阅」的入口——原来这件事
    // 是右下角那个悬浮按钮在管（没订阅就把自己藏起来），按钮撤了得有人接着管，
    // 否则点了毫无反应。
    final subtitle = !hasProfile
        ? context.appLocalizations.nullProfileDesc
        : isStart
        ? [context.appLocalizations.connected, ?node ?? groupName].join(' · ')
        : context.appLocalizations.disconnected;

    final icon = !hasProfile
        ? Icons.add
        : isStart
        ? Icons.power_settings_new
        : Icons.play_arrow;

    return SizedBox(
      height: getWidgetHeight(2),
      // 这块不是 CommonCard，自己画的壳，所以按压缩放也得自己包一层——不然全首页
      // 就它一块按下去没反应。深色底上 InkWell 的水波纹几乎看不见。
      // PressFeedback 用 Listener 观察指针，不抢手势，里面的 InkWell 照常工作。
      child: PressFeedback(
        child: TweenAnimationBuilder<double>(
          // t=0 断开、t=1 已连接。所有随状态变的颜色都从这一个量插出来，
          // 保证它们严格同步——分别写各自的动画就会出现「底色到了字还没到」。
          tween: Tween(end: isStart ? 1.0 : 0.0),
          duration: Motion.slow,
          curve: Motion.move,
          builder: (context, t, _) {
            final background = Color.lerp(
              colorScheme.surfaceContainerLow,
              accent,
              t,
            )!;
            final primaryText = Color.lerp(colorScheme.onSurface, onAccent, t)!;
            // 已连接时用主色上的白字降透明度做次要信息；未连接时用常规的次要文字色
            final secondaryText = Color.lerp(
              colorScheme.onSurfaceVariant,
              onAccent.withValues(alpha: 0.75),
              t,
            )!;
            // 未连接时和普通卡片一样有那圈高光边；已连接时整块是主色，不需要。
            // 边框宽度保持 1 只把颜色淡出去：改宽度会让内容跟着动一下。
            final rim = tokens.rim;
            final circleColor = Color.lerp(
              accent,
              onAccent.withValues(alpha: 0.18),
              t,
            )!;
            // 波动线的基色。
            //
            // 未连接：中性的次级文字色——桌面端未选中时用的就是 default-400
            // （`rgb(161,161,170)`），同一路数。
            // 已连接：整块底已经是主色了，再铺一层 0.8 的纯白就成了「卡片上糊了
            // 一坨白」，还要跟白色大字抢。所以基色先压到 0.42 的白，乘上渐变顶端的
            // 0.8 之后峰顶大约是 34% 的白——看得见山形，读得清字。
            final waveColor = Color.lerp(
              colorScheme.onSurfaceVariant,
              onAccent.withValues(alpha: 0.42),
              t,
            )!;

            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(tokens.cardRadius),
                boxShadow: tokens.cardShadow,
                border: Border.all(
                  color: rim.withValues(alpha: rim.a * (1 - t)),
                  width: 1,
                ),
              ),
              child: Material(
                color: background,
                // 颜色已经由外面那条过渡在逐帧算了，Material 自己再补一层
                // 隐式动画会变成两段缓动叠加，观感是「先快后拖」。
                animationDuration: Duration.zero,
                borderRadius: BorderRadius.circular(tokens.cardRadius),
                // 波动线是铺满整块的背景，山峰会顶到上边缘、两端会顶到左右边缘，
                // 不裁就会画出圆角外面去。桌面端同样是靠卡片的 `rounded-[14px]`
                // 裁掉的（`conn-card.tsx:221`）。
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(tokens.cardRadius),
                  onTap: () {
                    if (!hasProfile) {
                      // 没订阅时这块卡片上写的是「添加订阅」，那就真的直接开
                      // 添加面板（扫码 / 文件 / URL 三选一）。原来打开的是订阅
                      // **列表**页——而列表此刻必然是空的，用户还得自己在页面上
                      // 找那个加号；而且首页另有「订阅」磁贴同样通向那个列表，
                      // 两个入口撞在一起。
                      _showAddProfile(context);
                      return;
                    }
                    ref.read(commonActionProvider.notifier).toggleRunning();
                  },
                  child: Stack(
                    children: [
                      // 背景层：在内容**下面**、铺满整块、不接指针（它上面压着
                      // 内容，且整块的点击本来就由外面这个 InkWell 接）。
                      Positioned.fill(child: _SparklineLayer(color: waveColor)),
                      Padding(
                        padding: baseInfoEdgeInsets,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 状态一行、出口 IP 一行、时长流量一行，三行分居上中下。
                            // 原来三行全挤在顶部，底下留一大片空白，看起来像没加载出来。
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textTheme.labelMedium
                                        ?.copyWith(color: secondaryText),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 画成一个实心圆的按钮，而不是一个光秃秃的图标。
                                //
                                // 右下角那个悬浮开始按钮撤掉之后，启停就只剩这里了，
                                // 可它长得完全不像个能按的东西。未连接时用主色实心圆
                                // （整张卡是暗的，圆点最跳）；已连接时整张卡已经是主色，
                                // 改用半透明白圆才分得出层次。
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: circleColor,
                                    // 未连接时圆点带一圈主色辉光，已连接时整块都是
                                    // 主色、辉光就没意义了，跟着 t 一起淡掉。
                                    boxShadow: _fadedGlow(
                                      tokens.accentGlow(colorScheme),
                                      1 - t,
                                    ),
                                  ),
                                  // 播放 → 电源是这块最直白的「状态真的换了」的证据，
                                  // 直接换图标会闪一下。缩放 + 淡入淡出比旋转克制，
                                  // 这两个图形没有旋转关系，转起来只会显得花哨。
                                  child: AnimatedSwitcher(
                                    duration: Motion.quick,
                                    switchInCurve: Motion.enter,
                                    switchOutCurve: Motion.exit,
                                    transitionBuilder: (child, animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: ScaleTransition(
                                          scale: Tween<double>(
                                            begin: 0.7,
                                            end: 1,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Icon(
                                      icon,
                                      // key 只认图标本身：颜色每帧都在变，拿颜色一起
                                      // 做 key 会让它每帧都当成「换了个图标」重播动画。
                                      key: ValueKey(icon),
                                      color: primaryText,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: FadeThroughBox(
                                    child: Text(
                                      // 没连接时大字改显当前选中的节点，比一个破折号有用。
                                      //
                                      // 已连接但查不到出口 IP 时**不能一直显示
                                      // `···`**：查询早就结束了（provider 会把
                                      // isLoading 置回 false、ipInfo 留 null），
                                      // 首页最大的那行字却还在装作「正在加载」，
                                      // 于是「已连接 + 永远转不完」——用户看不出
                                      // 是节点不通还是应用卡住了。网络检测磁贴与
                                      // 详情页在同一情况下显示的就是「超时」，
                                      // 这里跟它们对齐。
                                      !hasProfile
                                          ? context.appLocalizations.addProfile
                                          : ip ??
                                                (isStart
                                                    ? (detection.isLoading
                                                          ? '···'
                                                          : context
                                                                .appLocalizations
                                                                .timeout)
                                                    : (node ??
                                                          groupName ??
                                                          '—')),
                                      key: ValueKey(
                                        ip ?? '$isStart-${detection.isLoading}',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.textTheme.headlineSmall
                                          ?.copyWith(
                                            color: primaryText,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ),
                                // **这里不再放实时速率。**
                                //
                                // 速率原本缩在这块卡片右侧（照搬桌面端
                                // `conn-card.tsx` 的排布）。但流量统计磁贴重做
                                // 之后画的就是「实时速率 + 累计」，两块磁贴显示
                                // 的是同一份数据——用户在添加磁贴面板里一眼就
                                // 看出来了。
                                //
                                // 按已定的分工收：数字归流量统计，这块卡片只管
                                // 「连没连上、从哪出去」和点一下启停。
                              ],
                            ),
                            const Spacer(),
                            DefaultTextStyle(
                              style:
                                  context.textTheme.labelMedium?.copyWith(
                                    color: secondaryText,
                                  ) ??
                                  const TextStyle(),
                              // 累计流量同样挪走了（见上）。这一行只剩已连接
                              // 时长——它是这块卡片自己的状态，别处没有。
                              child: const _RunTimeText(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 打开「添加订阅」面板。
  ///
  /// 和订阅页右下角那个悬浮按钮走的是同一段：`AddProfileView` 要一个能压栈的
  /// context（扫码页要从它上面推上去），所以取全局导航器的，不能用卡片自己的。
  void _showAddProfile(BuildContext context) {
    final navigatorContext = globalState.navigatorKey.currentState!.context;
    showExtend(
      navigatorContext,
      builder: (_) => AdaptiveSheetScaffold(
        body: AddProfileView(context: navigatorContext),
        title: context.appLocalizations.addProfile,
      ),
    );
  }

  /// 把一组辉光按 [opacity] 整体淡出。
  ///
  /// 不用 `BoxShadow.lerp(..., null, t)`：那个是把模糊半径和偏移一起缩到 0，看起来
  /// 是「辉光被吸回去了」；这里要的是「亮度退下去」，所以只动 alpha。
  List<BoxShadow> _fadedGlow(List<BoxShadow> glow, double opacity) {
    if (opacity >= 1) {
      return glow;
    }
    return [
      for (final shadow in glow)
        BoxShadow(
          color: shadow.color.withValues(alpha: shadow.color.a * opacity),
          offset: shadow.offset,
          blurRadius: shadow.blurRadius,
          spreadRadius: shadow.spreadRadius,
          blurStyle: shadow.blurStyle,
        ),
    ];
  }
}

/// 波动线那一层。
///
/// 单独抽出来是为了把「每秒一次」关在这一层里：`trafficsProvider` 每秒**无条件**
/// 通知一次（`FixedList` 没重写 `==`，`copyWith().add()` 每次都是新身份），跟整块
/// 状态总览绑在一起的话，那个 380 毫秒的底色过渡永远跑不完。
class _SparklineLayer extends ConsumerWidget {
  const _SparklineLayer({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traffics = ref.watch(trafficsProvider);
    return SpeedSparkline(values: _speeds(traffics), color: color);
  }

  /// 取最近 [sparklinePointCount] 个采样的**上行 + 下行之和**。
  ///
  /// 一条线不是两条：桌面端 `conn-card.tsx:139` 就是 `data.push(info.up + info.down)`。
  /// 两条线叠在文字背后会互相穿插成一团网格，读不出任何东西；要看上下行分开的
  /// 曲线请点右边的速率数字进详情页。
  ///
  /// 不走 `FixedList.list`：那个 getter 每次都 `List.unmodifiable` 复制一整份，
  /// 而这里每秒调一次、只要末尾 10 个。直接按下标读。
  List<double> _speeds(FixedList<Traffic> traffics) {
    final take = math.min(sparklinePointCount, traffics.length);
    return [
      for (var i = traffics.length - take; i < traffics.length; i++)
        traffics[i].speed.toDouble(),
    ];
  }
}

/// 连接时长。
///
/// **故意不做数字滚动。** 这是一个时钟，不是一个统计量：`00:00:05 → 00:00:06`
/// 中间那些小数插值格式化出来还是这两个值中的一个，屏幕上什么都看不到，唯一的效果
/// 是让秒针晚跳最多两百多毫秒——一个走得慢半拍的钟只会显得卡，不会显得顺。
///
/// 单独抽成一个 [ConsumerWidget] 是为了把每秒一次的重建关在这一行字里，不带着整块
/// 状态总览一起重建。
class _RunTimeText extends ConsumerWidget {
  const _RunTimeText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runTime = ref.watch(runTimeProvider);
    return Text(utils.getTimeText(runTime));
  }
}
