import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/features/overwrite/rule.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/providers/app.dart';
import 'package:clash_party/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the add/edit rule dialog releases its text controllers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;
    // CommonDialog 按 viewSizeProvider 算内容区高度，默认 Size.zero 会算出
    // 负的约束，页面根本渲染不出来。
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(900, 1200));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          builder: (context, child) {
            globalState.measure = Measure.of(context, 1);
            globalState.theme = CommonTheme.of(context, 1);
            return child!;
          },
          home: const Scaffold(body: AddOrEditRuleDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 内容输入框和规则目标的下拉框各自吃一个 TextEditingController，
    // 两个都是这个 State 自己 new 的，都必须由它释放。
    final controllers = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .map((widget) => widget.controller)
        .toList();
    expect(controllers, hasLength(2));

    // 关掉弹窗。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    for (final controller in controllers) {
      // 已释放的 ChangeNotifier 再挂监听器会抛 FlutterError；没释放的则安安静静
      // 挂上去。所以这一条就是「到底 dispose 了没有」的判据。
      expect(
        () => controller.addListener(() {}),
        throwsA(isA<FlutterError>()),
        reason: '弹窗关掉后两个 TextEditingController 都该已经释放',
      );
    }
  });
}
