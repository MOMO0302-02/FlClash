import 'package:clash_party/common/common.dart';
import 'package:flutter/material.dart';

class DisabledMask extends StatefulWidget {
  final Widget child;
  final bool status;

  const DisabledMask({super.key, required this.child, this.status = true});

  @override
  State<DisabledMask> createState() => _DisabledMaskState();
}

class _DisabledMaskState extends State<DisabledMask> {
  GlobalKey childKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final child = Container(key: childKey, child: widget.child);
    // 变灰 / 变回来要过渡。开关一翻整块「啪」地变灰，观感是界面坏了而不是
    // 「这块现在没在用」。用一个 0→1 的进度在原色和灰度矩阵之间插值。
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.status ? 1.0 : 0.0),
      duration: Motion.normal,
      curve: Motion.move,
      child: child,
      builder: (_, t, child) {
        if (t == 0) {
          return child!;
        }
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(_grayscale(t)),
          child: child!,
        );
      },
    );
  }

  /// 灰度矩阵按 [t] 在「原样」和「全灰」之间插值。
  ///
  /// t=0 是单位矩阵（原色），t=1 是那套亮度加权的灰度 + 提亮 30。
  List<double> _grayscale(double t) {
    const r = 0.2126;
    const g = 0.7152;
    const b = 0.0722;
    double mix(double identity, double gray) =>
        identity + (gray - identity) * t;
    return <double>[
      mix(1, r),
      mix(0, g),
      mix(0, b),
      0,
      30 * t,
      mix(0, r),
      mix(1, g),
      mix(0, b),
      0,
      30 * t,
      mix(0, r),
      mix(0, g),
      mix(1, b),
      0,
      30 * t,
      0,
      0,
      0,
      1,
      0,
    ];
  }
}
