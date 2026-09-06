import 'package:clash_party/common/num.dart';
import 'package:clash_party/models/common.dart';
import 'package:test/test.dart';

/// 流量格式化必须和桌面端 `calcTraffic` **逐字节一致**。
///
/// 对照组不是拍脑袋写的，是把桌面端
/// `upstream-clash-party/src/renderer/src/utils/calc.ts` 的两个函数手工执行出来的。
/// 原文（只有这么长，全文抄在这里，改动前先回来核对）：
///
/// ```ts
/// export function calcTraffic(byte: number): string {
///   if (byte < 1024) return `${formatNumString(byte)} B`
///   byte /= 1024
///   if (byte < 1024) return `${formatNumString(byte)} KB`
///   ... MB GB TB PB EB ZB ...
///   return `${formatNumString(byte)} YB`
/// }
///
/// function formatNumString(num: number): string {
///   let str = num.toFixed(2)
///   if (str.length <= 5) return str
///   if (str.length === 6) { str = num.toFixed(1); return str }
///   else { str = Math.round(num).toString(); return str }
/// }
/// ```
///
/// **下面这些预期值不是「读代码推出来的」，是真把上面那段 JS 跑出来的。**
/// 探针留在 `temp/calc-oracle.mjs`（这 20 条）和 `temp/gen-oracle.mjs`
/// （随机差分，固定种子）。后者生成 6008 个输入 —— 每一档的边界值、每档 300 个
/// 随机整数、2000 个随机小数、以及刻意压在 `99.9 / 999.9 / 1023.9` 三个长度分支
/// 边界上的各 400 个 —— 用 node 跑出桌面端答案再逐个和 Dart 比：**6008 比 0 不符**。
/// 改这个格式化函数之前先回去重跑一遍那个差分，别只看下面这 20 条。
///
/// 三件容易被「顺手修正」掉、修了就对不上的事：
/// 1. **进制 1024，单位却写 KB / MB**（不是 KiB / MiB）。桌面端就是这样。
/// 2. **不去尾零**：`1.00 KB` 不写成 `1 KB`。
/// 3. **截短按字符串长度判，不按数值大小判**——所以 `999.99` 会变成 `1000.0`
///    （长度 6 → 一位小数），而 `1023.99` 会变成 `1024`（长度 7 → 取整）。
void main() {
  /// 每条都写清推导：`byte` 除以 1024 几次落到哪一档，那一档的数值 `toFixed(2)`
  /// 是多长，于是走哪个分支。
  const cases = <(num, String, String)>[
    // 0 → 不进位。formatNumString(0)：'0.00' 长度 4 ≤ 5 → 保留两位。
    (0, '0.00', 'B'),
    // 1023 < 1024 → 不进位。'1023.00' 长度 7 → Math.round → '1023'。
    // **这是最反直觉的一条**：明明是整数，输出却没有小数位。
    (1023, '1023', 'B'),
    // 1024 → 进一位 = 1。'1.00' 长度 4 → 保留两位。
    (1024, '1.00', 'KB'),
    // 1536 / 1024 = 1.5。'1.50' 长度 4 → 保留两位（**不去尾零**）。
    (1536, '1.50', 'KB'),
    // 1048575 = 1024*1024-1 → /1024 = 1023.999…，仍 < 1024 所以停在 KB。
    // '1024.00' 长度 7 → Math.round(1023.999) = 1024 → '1024'。
    // 于是出现「1024 KB」这种看着该进位却没进位的写法，桌面端如此。
    (1048575, '1024', 'KB'),
    // 1048576 → 两次进位 = 1。'1.00' 长度 4。
    (1048576, '1.00', 'MB'),
    // 100 → 不进位。'100.00' 长度 6 → toFixed(1) → '100.0'。
    (100, '100.0', 'B'),
    // 99 → '99.00' 长度 5 → 保留两位。100 和 99 走的是不同分支。
    (99, '99.00', 'B'),
    // 123.456 → '123.46' 长度 6 → toFixed(1) → '123.5'（在这里进了一位）。
    (123.456, '123.5', 'B'),
    // 999.99 → '999.99' 长度 6 → toFixed(1) → '1000.0'。
    // **这是输出能达到的最长数值串（6 个字符）**，布局的最坏情况按它算。
    (999.99, '1000.0', 'B'),
    // 9.5 → '9.50' 长度 4。
    (9.5, '9.50', 'B'),
    // GB：1024^3。
    (1073741824, '1.00', 'GB'),
    // TB：1024^4 * 2.5 → 2.5。'2.50' 长度 4。
    (2.5 * 1024 * 1024 * 1024 * 1024, '2.50', 'TB'),
    // PB / EB / ZB / YB —— 安卓端原来的枚举只到 TB，这四档是这次补齐的。
    (1024.0 * 1024 * 1024 * 1024 * 1024, '1.00', 'PB'),
    (1024.0 * 1024 * 1024 * 1024 * 1024 * 1024, '1.00', 'EB'),
    (1024.0 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024, '1.00', 'ZB'),
    (
      1024.0 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024,
      '1.00',
      'YB',
    ),
    // YB 是最后一档，**不再进位**：桌面端最后一行是无条件 `return ... YB`。
    // 1024^9 = 1024 YB。'1024.00' 长度 7 → '1024'。
    (
      1024.0 *
          1024 *
          1024 *
          1024 *
          1024 *
          1024 *
          1024 *
          1024 *
          1024,
      '1024',
      'YB',
    ),
    // 负数：桌面端第一行比的是 `byte < 1024`（**带符号**，不是绝对值），
    // 所以负数一律停在 B 档。-5 → '-5.00' 长度 5 → 保留两位。
    (-5, '-5.00', 'B'),
    // -12.5 → '-12.50' 长度 6 → toFixed(1) → '-12.5'。
    (-12.5, '-12.5', 'B'),
  ];

  group('traffic 与桌面端 calcTraffic 逐字节一致', () {
    for (final (input, value, unit) in cases) {
      test('$input → $value $unit', () {
        final result = input.traffic;
        expect(result.value, value, reason: '数值');
        expect(result.unit, unit, reason: '单位');
        // 拼起来就是桌面端那一整串，**中间有一个空格**。
        expect(result.show, '$value $unit');
      });
    }
  });

  test('数值串最长 6 个字符——布局最坏情况按这个算', () {
    // 遍历所有能进位的档位边界附近，确认没有比 6 更长的输出。
    // （YB 档溢出到四位数以上的情况在现实里够不着：1024 YB 已经是 1.2e27 字节。）
    var longest = '';
    for (var unit = 0; unit < 8; unit++) {
      var scale = 1.0;
      for (var i = 0; i < unit; i++) {
        scale *= 1024;
      }
      for (var raw = 0.0; raw < 1024; raw += 0.01) {
        final text = (raw * scale).traffic.value;
        if (text.length > longest.length) {
          longest = text;
        }
      }
    }
    expect(longest.length, 6, reason: '实际最长的是 "$longest"');
  });
}
