import 'package:clash_party/common/common.dart';
import 'package:clash_party/models/common.dart';
import 'package:clash_party/providers/app.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/inherited.dart';
import 'package:clash_party/widgets/liquid_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'scaffold.dart';
import 'side_sheet.dart';
import 'theme.dart';

@immutable
class SheetProps {
  final double? maxWidth;
  final double? maxHeight;
  final bool isScrollControlled;
  final bool useSafeArea;
  final Color? backgroundColor;
  final bool blur;

  const SheetProps({
    this.maxWidth,
    this.maxHeight,
    this.backgroundColor,
    this.useSafeArea = true,
    this.isScrollControlled = false,
    this.blur = true,
  });
}

@immutable
class ExtendProps {
  final double? maxWidth;
  final bool useSafeArea;
  final bool blur;
  final bool forceFull;

  const ExtendProps({
    this.maxWidth,
    this.useSafeArea = true,
    this.blur = true,
    this.forceFull = false,
  });
}

enum SheetType { page, bottomSheet, sideSheet }

/// 底部弹层顶上那两个圆角。
///
/// 弹层是一块比卡片大得多的面，用卡片圆角会显得局促，所以取卡片圆角的两倍——
/// 默认风格下正好是 28，和之前写死的值一致，换风格时才会跟着变。
double _sheetCornerRadius(BuildContext context) =>
    context.styleTokens.cardRadius * 2;

Future<T?> showSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  SheetProps props = const SheetProps(),
}) {
  final isMobile = globalState.container.read(isMobileViewProvider);
  return switch (isMobile) {
    true => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: props.isScrollControlled,
      builder: (_) {
        return SheetProvider(
          type: SheetType.bottomSheet,
          child: builder(context),
        );
      },
      backgroundColor:
          props.backgroundColor ?? context.colorScheme.surfaceContainerLow,
      // 不给 shape 的话 Material 会用自己的 28 圆角画背景，和弹层内容
      // 自己裁的圆角对不上，换风格时角上会露出一圈底色。
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_sheetCornerRadius(context)),
        ),
      ),
      showDragHandle: false,
      useSafeArea: props.useSafeArea,
    ),
    false => showModalSideSheet<T>(
      useSafeArea: props.useSafeArea,
      isScrollControlled: props.isScrollControlled,
      context: context,
      backgroundColor: props.backgroundColor,
      constraints: BoxConstraints(maxWidth: props.maxWidth ?? 360),
      filter: props.blur ? commonFilter : null,
      builder: (_) {
        return SheetProvider(
          type: SheetType.sideSheet,
          child: builder(context),
        );
      },
    ),
  };
}

Future<T?> showExtend<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  ExtendProps props = const ExtendProps(),
}) {
  final isMobile = globalState.container.read(isMobileViewProvider);
  return switch (isMobile || props.forceFull) {
    true => BaseNavigator.push(
      context,
      SheetProvider(type: SheetType.page, child: builder(context)),
    ),
    false => showModalSideSheet<T>(
      useSafeArea: props.useSafeArea,
      context: context,
      constraints: BoxConstraints(maxWidth: props.maxWidth ?? 360),
      filter: props.blur ? commonFilter : null,
      builder: (context) {
        return SheetProvider(
          type: SheetType.sideSheet,
          child: builder(context),
        );
      },
    ),
  };
}

class AdaptiveSheetScaffold extends StatefulWidget {
  final Widget body;
  final String title;
  final bool sheetTransparentToolBar;
  final List<IconButtonData> actions;
  final VoidCallback? backAction;

  const AdaptiveSheetScaffold({
    super.key,
    required this.body,
    required this.title,
    this.sheetTransparentToolBar = false,
    this.actions = const [],
    this.backAction,
  });

  @override
  State<AdaptiveSheetScaffold> createState() => _AdaptiveSheetScaffoldState();
}

class _AdaptiveSheetScaffoldState extends State<AdaptiveSheetScaffold> {
  final _isScrolledController = ValueNotifier<bool>(false);

  IconData get backIconData {
    if (kIsWeb) {
      return Icons.arrow_back;
    }
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return Icons.arrow_back;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return Icons.arrow_back_ios_new_rounded;
    }
  }

  @override
  void didUpdateWidget(covariant AdaptiveSheetScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backAction != widget.backAction) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _isScrolledController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheetProvider = SheetProvider.of(context);
    final nestedNavigatorPop = sheetProvider?.nestedNavigatorPop;
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    final type = sheetProvider?.type ?? SheetType.page;
    final backgroundColor = type == SheetType.bottomSheet
        ? context.colorScheme.surfaceContainerLow
        : context.colorScheme.surface;
    final useCloseIcon =
        type != SheetType.page &&
        (nestedNavigatorPop != null && route?.impliesAppBarDismissal == false ||
            nestedNavigatorPop == null);
    Widget buildIconButton(IconButtonData data) {
      if (type == SheetType.bottomSheet) {
        return IconButton.filledTonal(
          onPressed: data.onPressed,
          // filledTonal 默认填 secondaryContainer——那是 Material 从种子推出来的
          // 一块闷色，和弹层的深灰不是一路。换成比弹层高一档的容器色。
          style: IconButton.styleFrom(
            backgroundColor: context.colorScheme.surfaceContainerHigh,
            foregroundColor: context.colorScheme.onSurface,
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(data.icon),
        );
      }
      return IconButton(
        onPressed: data.onPressed,
        style: IconButton.styleFrom(
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(data.icon),
      );
    }

    final actions = widget.actions.map(buildIconButton).toList();

    final popButton = type != SheetType.page
        ? (useCloseIcon
              ? buildIconButton(
                  IconButtonData(
                    icon: Icons.close,
                    onPressed: context.safeNestedPop,
                  ),
                )
              : buildIconButton(
                  IconButtonData(
                    icon: backIconData,
                    onPressed:
                        widget.backAction ??
                        () {
                          Navigator.of(context).pop();
                        },
                  ),
                ))
        : null;

    final suffixPop = type != SheetType.page && actions.isEmpty && useCloseIcon;
    final appBar = AppBar(
      backgroundColor: backgroundColor,
      forceMaterialTransparency: type == SheetType.bottomSheet ? true : false,
      leading: suffixPop ? null : popButton,
      automaticallyImplyLeading: type == SheetType.page ? true : false,
      centerTitle: true,
      toolbarHeight: type == SheetType.bottomSheet ? 48 : null,
      title: Text(widget.title),
      titleTextStyle: type == SheetType.bottomSheet
          ? context.textTheme.titleLarge?.adjustSize(-4)
          : null,
      actions: !suffixPop ? genActions(actions) : genActions([?popButton]),
    );
    if (type == SheetType.bottomSheet) {
      const handleSize = Size(28, 4);
      final sheetAppBar = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              alignment: Alignment.center,
              height: handleSize.height,
              width: handleSize.width,
              decoration: ShapeDecoration(
                // 抓手是提示不是主角，用足量的次要文字色会抢眼；压到 38% 才像
                // 一条摸得着的把手而不是一条分隔线。
                color: context.colorScheme.onSurfaceVariant.opacity38,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(handleSize.height / 2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: appBar,
          ),
          const SizedBox(height: 6),
        ],
      );
      // 底部弹层不走 CommonScaffold，所以控件主题要自己带上，
      // 否则弹层里的输入框和按钮会退回 Material 默认长相。
      return CommonControlTheme(
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(_sheetCornerRadius(context)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.sheetTransparentToolBar) ...[
                sheetAppBar,
                Flexible(child: widget.body),
              ] else ...[
                Flexible(
                  child: Stack(
                    children: [
                      NotificationListener<ScrollNotification>(
                        child: widget.body,
                        onNotification: (notification) {
                          if (notification is ScrollUpdateNotification) {
                            final pixels = notification.metrics.pixels;
                            _isScrolledController.value = pixels > 6;
                          }
                          return false;
                        },
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: ValueListenableBuilder(
                          valueListenable: _isScrolledController,
                          builder: (_, isScrolled, child) {
                            final topRadius = BorderRadius.vertical(
                              top: Radius.circular(_sheetCornerRadius(context)),
                            );
                            // **必须走 LiquidGlass，不能写裸 BackdropFilter。**
                            //
                            // 这里原来是 `BackdropFilter(filter: commonFilter)`，
                            // 也就是写死 sigma 5 的模糊——既不看设备能力，也不看
                            // 系统里的「移除动画」开关。于是低配机上照样逐帧重采样
                            // 整块背景，对动态效果敏感的用户也躲不掉。
                            // LiquidGlass 是能力分档的唯一入口。
                            //
                            // 弱机回落时把弹层自己的底色传进去（fallbackColor）：
                            // 不传的话会拿到 surfaceContainer，比下面的正文高一档，
                            // 看着像两块拼起来的。
                            return LiquidGlass(
                              borderRadius: topRadius,
                              tint: isScrolled
                                  ? backgroundColor.opacity60
                                  : backgroundColor,
                              fallbackColor: backgroundColor,
                              child: child!,
                            );
                          },
                          child: sheetAppBar,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
            ],
          ),
        ),
      );
    }
    return CommonScaffold(appBar: appBar, body: widget.body);
  }
}
