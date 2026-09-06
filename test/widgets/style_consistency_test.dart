import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 全应用的视觉风格得是一套，不是十几个页面各写各的。
///
/// **来历**：用户要求「检查整个 APP 的 UI 设计风格是否完全统一」。查下来问题不在
/// 排版，而在**同一个概念有好几个取值**——项目里明明已经定好了统一的语义色和统一
/// 的转圈组件，却还有几处在用 Material 自带的那套：
///
/// * 「已连接」在内核状态按钮的两个分支里分别是
///   `Colors.green.harmonizeWith(...)` 和 `Colors.greenAccent`——**同一个状态、
///   同一个按钮、两种绿**；
/// * 备份完成的小圆点又是第三处 `Colors.green.harmonizeWith(...)`；
/// * 订阅用量 80% 那一档是 `Color(0xFFE8B23A)`，一个只出现过一次的琥珀色；
/// * 网络检测的「超时」用 Material 的 `Colors.red`，和别处报错用的危险色不是
///   同一个红。
///
/// `harmonizeWith` 是「把外来色往主色方向拧一点」，而本应用有四种风格、四种主色
/// → 拧出四种绿。语义色的意义正是「到哪儿都是同一个」。
///
/// 这条测试**扫源码**：颜色散在十几个页面里，逐个搭环境渲染再取色的成本远高于它
/// 能挡住的问题；而「有没有人又直接写 Colors.green」是一次文本搜索就能钉死的事。
/// 同类做法见 `spinner_unified_test.dart`。
void main() {
  /// 直接写死、绕过语义色的写法。
  ///
  /// 只列**有语义替代品**的那几个：`AppStyleTokens.success` / `.warning` /
  /// `.danger`。`Colors.white` / `Colors.black` 这类中性色不在此列——它们表达的
  /// 就是"纯白/纯黑"本身，没有语义。
  const banned = <String, String>{
    'Colors.green': 'AppStyleTokens.success',
    'Colors.greenAccent': 'AppStyleTokens.success',
    'Colors.red': 'AppStyleTokens.danger',
    'Colors.redAccent': 'AppStyleTokens.danger',
    'Colors.orange': 'AppStyleTokens.warning',
    'Colors.amber': 'AppStyleTokens.warning',
  };

  // **只扫 `lib/`，不扫 `test/`。**
  //
  // 转圈那条防回退测试是两个目录都扫的，因为「测试里还在找一个已经删掉的组件」
  // 会让测试自己红掉。颜色不一样：测试里经常拿 `Colors.red` 当**记号笔**——比如
  // side_sheet 的测试给弹层塞一个红底色，就为了验证这个参数确实被传下去了。那种
  // 用法没有任何语义，换成 `AppStyleTokens.danger` 反而看不懂。
  //
  // 所以这条规则的边界是「产品代码里表达语义的颜色」，扫 `lib/` 就够了。

  test('语义色不许绕过统一定义', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final path = entity.path.replaceAll(r'\', '/');
      // 生成的代码不归我们管。
      if (path.contains('/generated/')) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // 注释掉的代码不算数。
        if (line.trimLeft().startsWith('//')) {
          continue;
        }
        for (final entry in banned.entries) {
          if (line.contains(entry.key)) {
            offenders.add('$path:${i + 1} 用了 ${entry.key}，应改为 ${entry.value}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: '这些地方绕过了统一的语义色：\n${offenders.join('\n')}',
    );
  });
}
