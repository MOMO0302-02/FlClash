import 'package:clash_party/common/app_style.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/state.dart';

import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 缩放为 1 时 getWidgetHeight(1) 的实测值。测试里不调那个函数——它依赖运行期
/// 的全局缩放状态，测试环境没有。
const _kCardHeight = 80.0;

/// getWidgetHeight(2) 的实测值：两倍高度的卡片（如「出站模式」）。
const _kTallCardHeight = 174.0;

/// 卡片在各风格、各屏幕尺寸下都不能溢出。
///
/// 为什么要有这组测试：`CommonCard` 是全 App 唯一的卡片实现，改它的排版会同时
/// 影响所有页面，包括改的时候没打开看过的页面。手机上只能看到当前那一屏，
/// 小屏机型上挤爆了根本发现不了——那正是跨设备最常见的翻车方式。
///
/// 判定方式：Flutter 在溢出时会往 `FlutterError.onError` 抛异常，这里把它接住。
/// 只要有任何一条 "overflowed" 就算失败。

/// 覆盖从最小到最大的常见手机屏幕（逻辑像素）。
const _screens = <String, Size>{
  '小屏 (5 寸级)': Size(320, 568),
  '常见 (6 寸级)': Size(390, 844),
  '大屏': Size(430, 932),
  '平板': Size(768, 1024),
};

Future<List<String>> _renderAndCollectOverflows(
  WidgetTester tester,
  Widget child,
  Size size,
) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed')) {
      errors.add(text.split('\n').first);
    } else {
      previous?.call(details);
    }
  };

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // CommonCard 内部读 globalState.theme 拿文字缩放。它是 late 字段，必须在
  // 真正的界面构建之前就赋好——放在 MaterialApp.builder 里太晚，子树已经在建了。
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          globalState.theme = CommonTheme.of(context, 1.0);
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        extensions: <ThemeExtension<dynamic>>[AppStyleTokens.clashParty],
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();

  FlutterError.onError = previous;
  return errors;
}

/// 仪表盘卡片的真实形态：固定高度 + 顶部标题 + 一行数值。
Widget _dashboardCard() {
  return SizedBox(
    width: 180,
    height: _kCardHeight,
    child: CommonCard(
      info: const Info(label: '网络检测', iconData: Icons.wifi_tethering),
      onPressed: () {},
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        alignment: Alignment.bottomLeft,
        child: const Text('192.168.31.181'),
      ),
    ),
  );
}

void main() {
  group('Clash Party 卡片', () {
    for (final entry in _screens.entries) {
      testWidgets('仪表盘卡片在${entry.key}不溢出', (tester) async {
        final errors = await _renderAndCollectOverflows(
          tester,
          _dashboardCard(),
          entry.value,
        );
        expect(
          errors,
          isEmpty,
          reason: '${entry.key} 卡片溢出：\n${errors.join('\n')}',
        );
      });
    }

    // 真机上溢出的是「出站模式」那种多行卡片（三个单选项 + 固定两倍高度），
    // 单行卡片测不出来。
    testWidgets('多行内容的高卡片不溢出', (tester) async {
      final errors = await _renderAndCollectOverflows(
        tester,
        SizedBox(
          width: 180,
          height: _kTallCardHeight,
          child: CommonCard(
            info: const Info(label: '出站模式', iconData: Icons.call_split),
            onPressed: () {},
            // 每行 30，三行共 90，留给「头部 + 内边距」84。原排版（图标+标题
            // 一行）在这个预算内是够的，所以一旦某个风格挂了，就说明它比原
            // 排版多占了高度——那才是真正要拦的回归。
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 30, child: Text('规则')),
                SizedBox(height: 30, child: Text('全局')),
                SizedBox(height: 30, child: Text('直连')),
              ],
            ),
          ),
        ),
        const Size(390, 844),
      );
      expect(errors, isEmpty, reason: errors.join(' | '));
    });

    testWidgets('长文本不撑破卡片', (tester) async {
      final errors = await _renderAndCollectOverflows(
        tester,
        SizedBox(
          width: 160,
          height: _kCardHeight,
          child: CommonCard(
            info: const Info(
              label: '一个特别长的卡片标题用来测试截断',
              iconData: Icons.cloud_download,
            ),
            onPressed: () {},
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              alignment: Alignment.bottomLeft,
              child: const Text(
                '香港自动 → HK 03 一个很长的节点名字',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        const Size(390, 844),
      );
      expect(errors, isEmpty, reason: errors.join('\n'));
    });
  });
}
