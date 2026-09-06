import 'dart:math';

import 'package:clash_party/models/common.dart';
import 'package:clash_party/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 提到外面只编译一次。`fixed` 曾经是流量格式化的底座，现在流量走
/// [_formatTrafficNum]（照抄桌面端），但 `fixed` 本身仍是通用工具，留着。
final _trailingZeros = RegExp(r'0*$');

/// 等宽数字（OpenType 的 `tnum`）。**给每秒都在变的数字用。**
///
/// **桌面端没有这一条，是模仿不是照抄。** 桌面端靠固定宽度的容器解决位移
/// （`conn-card.tsx:242` 的 `w-full text-right`），但那只保证「整串文字的右边缘
/// 不动」，保不住串**内部**——比例字体里 `1` 比 `8` 窄，`1.00 KB/s` 换成
/// `8.88 KB/s` 时每个字符都会挪一点。`tnum` 让所有数字占同样宽度，位数不变时
/// 连一个像素都不会动。
///
/// 代价接近零：字体不支持时排版引擎直接忽略，不会退化成别的样子。安卓默认字体
/// Roboto 自带 `tnum`。
const tabularFigures = <FontFeature>[FontFeature.tabularFigures()];

/// 流量单位序列，逐字照抄桌面端 `src/renderer/src/utils/calc.ts` 的
/// `calcTraffic`：**九档，到 YB 为止**。
///
/// 这里**不用** `TrafficUnit` 枚举：那个只到 TB（五档），而桌面端有九档，
/// 且枚举属于别人的文件不归本次改动动。
///
/// 注意进制是 1024 但单位写 `KB` 而不是 `KiB`——桌面端就是这么写的，**别「修正」**，
/// 修了两端就对不上了。
const _trafficUnits = <String>[
  'B',
  'KB',
  'MB',
  'GB',
  'TB',
  'PB',
  'EB',
  'ZB',
  'YB',
];

/// 逐字照抄桌面端 `calc.ts` 里的 `formatNumString`。
///
/// 规则是**按字符串长度截短**，不是按数值大小：
/// * 先 `toFixed(2)`；长度 ≤ 5 就直接用（`0.00`、`9.50`、`12.34`）
/// * 长度正好 6 时改成一位小数（`123.46` → `123.5`；`999.99` → `1000.0`）
/// * 更长就四舍五入成整数（`1023.99` → `1024`）
///
/// **不去尾零**是这条规则的关键：`1.00` 就写成 `1.00`，不写成 `1`。安卓端原来
/// 去尾零，于是 `1KB` / `1.5KB` / `10.2KB` 三者宽度差一大截，数字每秒都在改变
/// 整行的排版宽度——这正是「数字跳动」的一半原因。
///
/// 与 JS 的差异只在一个够不着的角落：`Math.round(-0.5)` 在 JS 里是 `-0`（打印成
/// `0`），Dart 的 `(-0.5).round()` 是 `-1`。这条分支要求字符串长度 ≥ 7，也就是
/// 绝对值至少三位数，`-0.5` 根本进不来。
String _formatTrafficNum(double num) {
  final str = num.toStringAsFixed(2);
  if (str.length <= 5) {
    return str;
  }
  if (str.length == 6) {
    return num.toStringAsFixed(1);
  }
  return num.round().toString();
}

extension NumExt on num {
  String fixed({int decimals = 2}) {
    String formatted = toStringAsFixed(decimals);
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(_trailingZeros, '');
      if (formatted.endsWith('.')) {
        formatted = formatted.substring(0, formatted.length - 1);
      }
    }
    return formatted;
  }

  double get ap {
    return this * (1 + (globalState.theme.textScaleFactor - 1) * 0.5);
  }

  double get mAp {
    return this * min((1 + (globalState.theme.textScaleFactor - 1) * 0.5), 1);
  }

  /// 流量文本，**和桌面端 `calcTraffic` 逐字节一致**。
  ///
  /// 进位条件写成 `>= 1024` 是桌面端那串 `if (byte < 1024) return ...` 的等价
  /// 展开——注意它比的是**带符号的值**不是绝对值，所以负数在第一档就返回 `B`。
  /// 这不是笔误，是照抄。
  ///
  /// `unit` 里**不带空格**，空格由 `TrafficShowExt.show` 在拼接时补，这样
  /// 「数值和单位分两个 Text 摆」的地方（流量磁贴、内存磁贴）不会多出一个
  /// 前导空格。拼起来就是桌面端的 `1.50 KB`。
  TrafficShow get traffic {
    var size = toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < _trafficUnits.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return TrafficShow(
      value: _formatTrafficNum(size),
      unit: _trafficUnits[unitIndex],
    );
  }

  /// 托盘标题用的紧凑写法：不带小数。
  ///
  /// 桌面端托盘走的是完整的 `calcTraffic` 再 `padStart(9)`
  /// （`src/main/core/mihomoApi.ts:511`），这里保留安卓端原有的紧凑写法：托盘只在
  /// 桌面版 FlClash 上存在，不在本次「上传下载数字跳动」的范围内。
  TrafficShow get shortTraffic {
    var size = toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < _trafficUnits.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return TrafficShow(
      value: size.toStringAsFixed(0),
      unit: _trafficUnits[unitIndex],
    );
  }
}

extension DoubleExt on double {
  bool moreOrEqual(double value) {
    return this > value || (value - this).abs() < precisionErrorTolerance + 1;
  }
}

extension OffsetExt on Offset {
  double getCrossAxisOffset(Axis direction) {
    return direction == Axis.vertical ? dx : dy;
  }

  double getMainAxisOffset(Axis direction) {
    return direction == Axis.vertical ? dy : dx;
  }

  bool less(Offset offset) {
    if (dy < offset.dy) {
      return true;
    }
    if (dy == offset.dy && dx < offset.dx) {
      return true;
    }
    return false;
  }
}

extension RectExt on Rect {
  bool doRectIntersect(Rect rect) {
    return left < rect.right &&
        right > rect.left &&
        top < rect.bottom &&
        bottom > rect.top;
  }
}
