import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fade_box.dart';
import 'text.dart';

class Info {
  final String label;
  final IconData? iconData;

  const Info({required this.label, this.iconData});
}

class InfoHeader extends StatelessWidget {
  final Info info;
  final List<Widget> actions;
  final EdgeInsets? padding;

  const InfoHeader({
    super.key,
    required this.info,
    this.padding,
    List<Widget>? actions,
  }) : actions = actions ?? const [];

  @override
  Widget build(BuildContext context) {
    EdgeInsetsGeometry nextPadding = (padding ?? baseInfoEdgeInsets);
    if (actions.isNotEmpty) {
      nextPadding = nextPadding.subtract(EdgeInsets.symmetric(vertical: 8.mAp));
    }
    return Padding(
      padding: nextPadding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 1,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                if (info.iconData != null) ...[
                  Icon(
                    info.iconData,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  flex: 1,
                  child: TooltipText(
                    text: Text(
                      info.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (actions.isNotEmpty)
            SizedBox(
              height: globalState.measure.titleSmallHeight + 16.ap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [...actions],
              ),
            ),
        ],
      ),
    );
  }
}

class CommonCard extends StatelessWidget {
  const CommonCard({
    super.key,
    bool? isSelected,
    this.type = CommonCardType.plain,
    this.onPressed,
    this.selectWidget,
    this.radius,
    this.padding,
    this.enterAnimated = false,
    this.info,
    this.onLongPress,
    this.shape,
    this.isError = false,
    this.enterActionsOnRight = false,
    required this.child,
  }) : isSelected = isSelected ?? false;

  final bool enterAnimated;
  final bool enterActionsOnRight;
  final bool isSelected;
  final bool isError;
  final void Function()? onPressed;
  final void Function()? onLongPress;
  final Widget? selectWidget;
  final Widget child;
  final EdgeInsets? padding;
  final Info? info;
  final CommonCardType type;
  final double? radius;
  final OutlinedBorder? shape;

  /// 画阴影那一层该用的圆角。
  ///
  /// 从 [shape] 里取真实圆角；取不到就用直角——`LinearBorder.none`（拖动中的
  /// 那一项）画出来就是直角，阴影也该是直角。没传 [shape] 时才回落到卡片默认圆角。
  BorderRadius _shadowBorderRadius(BuildContext context) {
    final currentShape = shape;
    if (currentShape == null) {
      return BorderRadius.circular(radius ?? context.styleTokens.cardRadius);
    }
    return switch (currentShape) {
      RoundedSuperellipseBorder(:final borderRadius) => borderRadius.resolve(
        Directionality.of(context),
      ),
      RoundedRectangleBorder(:final borderRadius) => borderRadius.resolve(
        Directionality.of(context),
      ),
      _ => BorderRadius.zero,
    };
  }

  BorderSide _buildBorderSide(BuildContext context, Set<WidgetState> states) {
    final colorScheme = context.colorScheme;
    if (isError) {
      if (type == CommonCardType.filled) {
        return BorderSide(color: colorScheme.error);
      }
      final hoverColor = isSelected
          ? colorScheme.error.opacity80
          : colorScheme.error.opacity38;
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused) ||
          states.contains(WidgetState.pressed)) {
        return BorderSide(color: hoverColor);
      }
      return BorderSide(
        color: isSelected
            ? colorScheme.error.opacity60
            : colorScheme.error.opacity30,
      );
    }
    final tokens = context.styleTokens;
    if (type == CommonCardType.filled) {
      // 那圈高光边一直都在，选中也不去掉——桌面端选中只换底色（`bg-primary`），
      // 阴影连同里面那层 inset 高光原样保留，见
      // `components/sider/proxy-card.tsx:70` 那一串 `match ? 'bg-primary' : ...`。
      return BorderSide(color: tokens.rim);
    }
    final hoverColor = isSelected
        ? colorScheme.primary.opacity80
        : colorScheme.primary.opacity60;
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused) ||
        states.contains(WidgetState.pressed)) {
      return BorderSide(color: hoverColor);
    }
    // 选中时画不画一圈主色描边，四种风格各有各的答案：
    //
    // · fill（Clash Party）不画——桌面端整块变蓝时四周没有更亮的一道，只有阴影
    //   里那层几乎看不见的 inset 高光。
    // · indicator（Fluent）不画——Windows 的选中项是「左侧一条指示条 + 底色微微
    //   提亮」，整圈描边不是 Fluent 的语言。指示条见 [_buildSelectionOverlay]。
    // · tonal（Material You）不画——M3 的选中是换成 secondaryContainer 的柔和填充，
    //   再套一圈描边就成了「填充 + 描边」两种强调叠在一起。
    // · check（iOS）**要画**——它是唯一不改底色的，不给一道边就只剩右侧那个勾，
    //   在一排卡片里几乎认不出哪个被选中了。
    if (isSelected && tokens.selectionMode == SelectionMode.check) {
      return BorderSide(color: tokens.accent(colorScheme), width: 1.5);
    }
    return BorderSide(color: tokens.rim);
  }

  /// 选中时盖在卡片上的那层东西：Fluent 的左侧指示条、iOS 的右上角对勾。
  ///
  /// `fill` 和 `tonal` 靠底色表达选中，这里什么都不画。
  ///
  /// **必须盖在按钮外面，不能塞进按钮的 child。** 卡片内容普遍比卡片矮（内容是一
  /// 行字，按钮把它垂直居中），塞进去的话 `Positioned.fill` 填的是那一行字的高度
  /// 不是整张卡片——"贴在右上角"会变成"贴在文字右边"，正好压住最后一个字
  /// （`temp/shots/theme_cupertino_light.png` 拍到过 "Dark□" 挨在一起）。
  ///
  /// 用 [IgnorePointer] 裹住：卡片里常装着开关和图标按钮，覆盖层不能抢它们的手势。
  Widget? _buildSelectionOverlay(BuildContext context) {
    if (!isSelected || isError) {
      return null;
    }
    final tokens = context.styleTokens;
    final accent = tokens.accent(context.colorScheme);
    return switch (tokens.selectionMode) {
      SelectionMode.fill || SelectionMode.tonal => null,
      // Windows 11 的选中项：左边缘一条圆头指示条，高度只占中间一段。
      SelectionMode.indicator => IgnorePointer(
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            heightFactor: 0.5,
            child: Container(
              width: tokens.selectionIndicatorWidth,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(
                  tokens.selectionIndicatorWidth,
                ),
              ),
            ),
          ),
        ),
      ),
      // iOS：一个主色的勾，底色一动不动。
      //
      // 放右上角而不是右侧居中：右侧居中会压在内容上（卡片内容几乎都是纵向居中
      // 的）。内缩 6 是为了躲开圆角——覆盖层在按钮外面，不吃按钮的圆角裁剪。
      SelectionMode.check => IgnorePointer(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 6, right: 6),
            child: Icon(Icons.check_rounded, size: 16, color: accent),
          ),
        ),
      ),
    };
  }

  Color? _buildBackgroundColor(BuildContext context) {
    final colorScheme = context.colorScheme;
    // if (isError) {
    //   if (type == CommonCardType.filled) {
    //     return isSelected
    //         ? colorScheme.errorContainer.opacity80
    //         : colorScheme.errorContainer;
    //   }
    //   return isSelected
    //       ? colorScheme.errorContainer.opacity60
    //       : colorScheme.errorContainer.opacity12;
    // }
    // 选中时怎么变由风格决定：整块填充 / 左侧指示条 / 柔和容器色 / 只打勾。
    final tokens = context.styleTokens;
    final base = type == CommonCardType.filled
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerLow;
    if (!isSelected) {
      return base;
    }
    return switch (tokens.selectionMode) {
      // 两种卡片选中时都填满色的主色。原来 filled 用的是 80% 透明度（继承自
      // FlClash），在纯黑底上会淡出一截，和桌面端那块实心 bg-primary 对不上，
      // 还逼得调用方为了拿到满色而去选 plain 类型。
      SelectionMode.fill => tokens.accent(colorScheme),
      SelectionMode.tonal => colorScheme.secondaryContainer,
      // 指示条和打勾都不改底色，只是稍微提亮一点，表示「这块被选中了」。
      SelectionMode.indicator => colorScheme.surfaceContainerHighest,
      SelectionMode.check => base,
    };
  }

  /// 选中的卡片上，文字和图标该用什么颜色。
  ///
  /// 交给 [AppStyleTokens.selectedForeground] 判断——**不能一律用 onAccent**，
  /// 四种选中方式里只有 `fill` 真的把底色换成了强调色。原因和实测症状见那边的
  /// 说明。
  Color? _buildForegroundColor(BuildContext context) {
    final colorScheme = context.colorScheme;
    if (isError) {
      return colorScheme.error;
    }
    if (isSelected) {
      return context.styleTokens.selectedForeground(colorScheme);
    }
    return colorScheme.onSurfaceVariant;
  }

  Color? _buildIconColor(BuildContext context) {
    final colorScheme = context.colorScheme;
    if (isError) {
      return colorScheme.error;
    }
    if (isSelected) {
      return context.styleTokens.selectedForeground(colorScheme);
    }
    // 桌面端未选中的卡片图标是 foreground（近白），不是主色。
    return colorScheme.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    var childWidget = child;

    if (info != null) {
      // Clash Party 的卡片是「内容在上 → 图标+标题在底」，与 Material 的
      // 「图标+标题在上 → 内容在下」正好相反，是观感差异的主要来源。
      //
      // 这是**布局**不是样式，四种主题共用同一套——切主题只改「长什么样」，
      // 不改「东西在哪」。所以这里不再看主题，固定用这一种。
      //
      // 不给整体再套一层内边距：卡片内容本身已经带了内边距，套两层会多占十来个
      // 像素，固定高度的卡片当场溢出。只补一点顶部间距，标题行自己带左右。
      childWidget = Padding(
        padding: EdgeInsets.only(top: 6.mAp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(flex: 1, child: child),
            // 图标与标题挤在同一行：原本的头部也是一行，这样换位置不增高，
            // 卡片的固定高度（getWidgetHeight）就不用跟着改。
            Padding(
              padding: EdgeInsets.fromLTRB(16.mAp, 0, 16.mAp, 12.mAp),
              child: Row(
                children: [
                  if (info!.iconData != null) ...[
                    Icon(info!.iconData, size: 18),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      info!.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (selectWidget != null && isSelected) {
      final List<Widget> children = [];
      children.add(childWidget);
      children.add(Positioned.fill(child: selectWidget!));
      childWidget = Stack(children: children);
    }

    final rawButton = switch (type == CommonCardType.filled) {
      true => FilledButton(
        onLongPress: onLongPress,
        clipBehavior: Clip.antiAlias,
        style:
            FilledButton.styleFrom(
              padding: padding ?? EdgeInsets.zero,
              shape:
                  shape ??
                  RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(
                      radius ?? context.styleTokens.cardRadius,
                    ),
                  ),
              iconSize: 20,
              iconColor: _buildIconColor(context),
              foregroundColor: _buildForegroundColor(context),
              side: BorderSide.none,
              elevation: 0,
            ).copyWith(
              backgroundColor: WidgetStatePropertyAll(
                _buildBackgroundColor(context),
              ),
              side: WidgetStateProperty.resolveWith(
                (states) => _buildBorderSide(context, states),
              ),
            ),
        // ✅ 优化：按压时触发触觉反馈
        onPressed: onPressed != null
            ? () {
                HapticFeedback.lightImpact();
                onPressed!();
              }
            : null,
        child: childWidget,
      ),
      false => OutlinedButton(
        onLongPress: onLongPress,
        clipBehavior: Clip.antiAlias,
        style:
            OutlinedButton.styleFrom(
              padding: padding ?? EdgeInsets.zero,
              shape:
                  shape ??
                  RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(
                      radius ?? context.styleTokens.cardRadius,
                    ),
                  ),
              iconSize: 20,
              iconColor: _buildIconColor(context),
              backgroundColor: _buildBackgroundColor(context),
              foregroundColor: _buildForegroundColor(context),
              elevation: 0,
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => _buildBorderSide(context, states),
              ),
            ),
        // ✅ 优化：按压时触发触觉反馈
        onPressed: onPressed != null
            ? () {
                HapticFeedback.lightImpact();
                onPressed!();
              }
            : null,
        child: childWidget,
      ),
    };
    // 选中态的覆盖层盖在**整张卡片**上，不是盖在内容上——原因见
    // [_buildSelectionOverlay] 的说明。
    final selectionOverlay = _buildSelectionOverlay(context);
    final button = selectionOverlay == null
        ? rawButton
        : Stack(
            // passthrough：按钮拿到的约束和「没有这层 Stack」时一模一样。
            // 默认的 loose 会把约束放松，撑满宽度的卡片会当场缩水。
            fit: StackFit.passthrough,
            children: [
              rawButton,
              Positioned.fill(child: selectionOverlay),
            ],
          );
    // 阴影用 AnimatedContainer：换风格时深浅两套阴影之间要渐变过去，直接换会
    // 「啪」地闪一下。
    //
    // **选中不换阴影。** 桌面端的卡片无论选没选都是同一个 `shadow-medium`
    // （`components/sider/*.tsx` 里选中只改 `bg-primary`，没碰 shadow；
    // `components/proxies/proxy-item.tsx:67-81` 选中改的是 `bg-primary/30` 和左右
    // 两条边框，shadow 一直是 `sm`）。原来选中时会换成一圈蓝光，桌面端没有这个
    // 东西——CSS 不会因为底色亮就往外溢光。
    final shaped = AnimatedContainer(
      duration: Motion.normal,
      curve: Motion.move,
      decoration: BoxDecoration(
        // **圆角必须跟着卡片真实形状走。**
        //
        // 原来这里恒取 `radius ?? cardRadius`（14），不看 [shape]。而列表项会按
        // "这是第几项"给出不同形状：首项上圆角 24、末项下圆角 24、中间项直角，
        // 拖动中的那项是 `LinearBorder.none`（纯直角）。
        //
        // 卡片圆角 24、阴影圆角 14 的结果是**阴影从卡片四角探出来**，浅色背景上
        // 就是几道深色月牙，连起来看着像一圈黑边——用户报的正是这个。
        borderRadius: _shadowBorderRadius(context),
        boxShadow: context.styleTokens.cardShadow,
      ),
      child: button,
    );
    final card = !enterActionsOnRight
        ? shaped
        : Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent ||
                  event.logicalKey != LogicalKeyboardKey.arrowRight) {
                return KeyEventResult.ignored;
              }
              final focusNode = FocusManager.instance.primaryFocus;
              final context = focusNode?.context;
              if (focusNode == null ||
                  context == null ||
                  context.findAncestorWidgetOfExactType<IconButton>() != null) {
                return KeyEventResult.ignored;
              }
              return focusNode.nextFocus()
                  ? KeyEventResult.handled
                  : KeyEventResult.ignored;
            },
            // 这里必须裹 shaped 而不是 button：裹 button 会把画阴影的那一层
            // 整个绕过去，于是所有带右侧动作的卡片（代理组卡片是一大片）都没有
            // 外阴影，在纯黑底上就是一块贴上去的色块。
            child: shaped,
          );

    // 按下时整块轻微缩小。深色底上 Material 的水波纹几乎看不见，不加这一下
    // 点什么都像没反应——这是全 app 性价比最高的一处动效，几乎每个可点的东西
    // 都会经过这里。
    //
    // 用 PressFeedback（只观察指针）而不是 GestureDetector：卡片里经常还装着
    // 开关和图标按钮，抢了手势会把它们一起废掉。
    // 只在真的可点时才包：不可点的卡片跟着缩会让人以为点中了什么。
    final pressable = onPressed == null ? card : PressFeedback(child: card);

    return switch (enterAnimated) {
      true => FadeScaleEnterBox(child: pressable),
      false => pressable,
    };
  }
}

class SelectIcon extends StatelessWidget {
  const SelectIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.inversePrimary,
      shape: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(4),
        child: const Icon(Icons.check, size: 16),
      ),
    );
  }
}

class SettingsBlock extends StatelessWidget {
  final String title;
  final List<Widget> settings;

  const SettingsBlock({super.key, required this.title, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          InfoHeader(info: Info(label: title)),
          Card(
            color: context.colorScheme.surfaceContainer,
            child: Column(children: settings),
          ),
        ],
      ),
    );
  }
}
