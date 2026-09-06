import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 全应用只用一种转圈。
///
/// 用户要求「能直接抄桌面端的全部抄」，而桌面端所有 loading 都是同一个
/// HeroUI Spinner。安卓端原来散着 FlClash 自带的 `CommonCircleLoading`
/// （Material 3 多边形变形加载器），一个页面一个样。
///
/// 这条测试是**扫源码**而不是画界面：转圈散落在十几个页面里，逐个搭出真实环境
/// 去渲染的成本比它能挡住的问题高得多；而"有没有人又把旧的那个用回来"恰恰是
/// 一次文本搜索就能钉死的事。
void main() {
  /// 允许残留旧加载器的地方。
  ///
  /// （旧加载器 `widgets/loading.dart` 与它的测试已于 2026-09-03 删除。）
  /// - `widgets/hero_spinner.dart` 的注释里提到它，是在说明来历；
  /// - `manager/status_manager.dart` 里那处是**注释掉的代码**。
  ///
  /// `views/config/on_demand.dart` 一度因为被另一个智能体占用而漏掉，正是这条
  /// 测试当场把它揪出来的。**放进白名单的东西必须有到期时间**，否则白名单会变成
  /// "永远不修"的借口。
  const allowed = {
    'lib/widgets/hero_spinner.dart',
    'lib/manager/status_manager.dart',
    // 这条测试自己会提到旧组件的名字。
    'test/widgets/spinner_unified_test.dart',
  };

  /// **两个都要拦**：第一版只拦了 FlClash 自带的那个，Material 自带的
  /// `CircularProgressIndicator` 一直没人管，于是崩溃界面的「重新加载」和 Smart
  /// 模型的下载按钮成了应用里的第三种转圈——防回退的测试是绿的，界面却不统一。
  ///
  /// `LinearProgressIndicator` 不在此列：那是进度条，和转圈是两种组件。
  const banned = ['CommonCircleLoading', 'CircularProgressIndicator'];

  test('全应用只有一种转圈', () {
    final offenders = <String>[];
    // **`test/` 也要扫。** 第一版只扫了 `lib/`，结果
    // `core_status_button_test.dart` 里 14 处 `find.byType(CommonCircleLoading)`
    // 全部漏网——源码换了、测试还在找旧组件，跑起来直接红，而这条本该拦住它的
    // 测试却是绿的。**"防回退"的扫描漏掉测试目录，等于漏掉一半。**
    for (final entity in [
      ...Directory('lib').listSync(recursive: true),
      ...Directory('test').listSync(recursive: true),
    ]) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final path = entity.path.replaceAll(r'\', '/');
      if (allowed.contains(path)) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final hit = banned.firstWhere(
          line.contains,
          orElse: () => '',
        );
        if (hit.isEmpty) {
          continue;
        }
        // 注释掉的代码不算数。
        if (line.trimLeft().startsWith('//')) {
          continue;
        }
        offenders.add('$path:${i + 1} ($hit)');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '这些地方还在用 FlClash 的加载器，应该换成 HeroSpinner：\n'
          '${offenders.join('\n')}',
    );
  });
}
