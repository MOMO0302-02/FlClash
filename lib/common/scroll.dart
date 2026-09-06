import 'dart:math';
import 'dart:ui';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/widgets/scroll.dart';
import 'package:flutter/material.dart';

class BaseScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    if (system.isDesktop) PointerDeviceKind.mouse,
    PointerDeviceKind.unknown,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    switch (axisDirectionToAxis(details.direction)) {
      case Axis.horizontal:
        return child;
      case Axis.vertical:
        switch (getPlatform(context)) {
          case TargetPlatform.linux:
          case TargetPlatform.macOS:
          case TargetPlatform.windows:
            assert(details.controller != null);
            return CommonScrollBar(
              controller: details.controller,
              child: child,
            );
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.iOS:
            return child;
        }
    }
  }
}

class HiddenBarScrollBehavior extends BaseScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class ShowBarScrollBehavior extends BaseScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return CommonScrollBar(controller: details.controller, child: child);
  }
}

class NextClampingScrollPhysics extends ClampingScrollPhysics {
  const NextClampingScrollPhysics({super.parent});

  @override
  NextClampingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return NextClampingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final Tolerance tolerance = toleranceFor(position);
    if (position.outOfRange) {
      double? end;
      if (position.pixels > position.maxScrollExtent) {
        end = position.maxScrollExtent;
      }
      if (position.pixels < position.minScrollExtent) {
        end = position.minScrollExtent;
      }
      assert(end != null);
      return ScrollSpringSimulation(
        spring,
        end!,
        end,
        min(0.0, velocity),
        tolerance: tolerance,
      );
    }
    if (velocity.abs() < tolerance.velocity) {
      return null;
    }
    if (velocity > 0.0 && position.pixels >= position.maxScrollExtent) {
      return null;
    }
    if (velocity < 0.0 && position.pixels <= position.minScrollExtent) {
      return null;
    }
    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      tolerance: tolerance,
    );
  }
}

// class CacheScrollPositionController extends ScrollController {
//   final String key;
//
//   CacheScrollPositionController({
//     required this.key,
//     double initialScrollOffset = 0.0,
//     super.keepScrollOffset = true,
//     super.debugLabel,
//     super.onAttach,
//     super.onDetach,
//   });
//
//   @override
//   ScrollPosition createScrollPosition(
//     ScrollPhysics physics,
//     ScrollContext context,
//     ScrollPosition? oldPosition,
//   ) {
//     return ScrollPositionWithSingleContext(
//       physics: physics,
//       context: context,
//       initialPixels:
//           globalState.scrollPositionCache[key] ?? initialScrollOffset,
//       keepScrollOffset: keepScrollOffset,
//       oldPosition: oldPosition,
//       debugLabel: debugLabel,
//     );
//   }
//
//   double? get cacheOffset => globalState.scrollPositionCache[key];
//
//   _handleScroll() {
//     globalState.scrollPositionCache[key] = position.pixels;
//   }
//
//   @override
//   void attach(ScrollPosition position) {
//     super.attach(position);
//     addListener(_handleScroll);
//   }
//
//   @override
//   void detach(ScrollPosition position) {
//     removeListener(_handleScroll);
//     super.detach(position);
//   }
// }

class ReverseScrollController extends ScrollController {
  ReverseScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return ReverseScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class ReverseScrollPosition extends ScrollPositionWithSingleContext {
  ReverseScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels = 0.0,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  bool _isInit = false;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    if (!_isInit) {
      correctPixels(maxScrollExtent);
      _isInit = true;
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}

/// 取当前页面该用的滚动控制器：**优先用协调层提供的那个**。
///
/// `CommonScaffold` 把整页交给 `NestedScrollView` 协调，标题栏是它的外层 sliver。
/// 只有正文的滚动接在协调层提供的 `PrimaryScrollController` 上，标题栏才会跟着内容
/// 滚走——页面自己 `new` 一个控制器的话，两边各滚各的，标题栏纹丝不动。
///
/// **必须从协调层内部的 context 取。** 页面 `State.context` 在 `CommonScaffold`
/// **外面**，从那儿取到的要么是 null、要么是**外层页面**的控制器；后者会让同一个
/// 控制器被两个滚动视图接上，任何读 `.position` 的代码当场断言
/// （`ScrollController attached to multiple scroll views`）。所以这个方法要求传
/// 一个 context，调用点应当在正文内部的 `Builder` 里。
///
/// 找不到协调层时（比如页面被塞进底部弹层，那种场合标题本来就该固定）回落到自己
/// 造一个，并由本 mixin 负责释放。
mixin PageScrollController<T extends StatefulWidget> on State<T> {
  ScrollController? _ownScrollController;

  ScrollController pageScrollControllerOf(BuildContext context) =>
      PrimaryScrollController.maybeOf(context) ??
      (_ownScrollController ??= ScrollController());

  @override
  void dispose() {
    _ownScrollController?.dispose();
    super.dispose();
  }
}
