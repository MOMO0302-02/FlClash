import 'dart:io';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/profiles/edit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  final String root;

  _FakePathProvider(this.root);

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => root;
}

class _NoopSetupAction extends SetupAction {
  @override
  void autoApplyProfile() {}
}

/// 记下「保存」到底有没有真的把订阅写回去。
class _SpyProfilesAction extends ProfilesAction {
  final List<Profile> saved = [];

  @override
  void putProfile(Profile profile) {
    saved.add(profile);
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('profile_edit_save_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDownAll(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('saving still works after clearing the interval and turning '
      'auto update off', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final spy = _SpyProfilesAction();
    final container = ProviderContainer(
      overrides: [
        setupActionProvider.overrideWith(() => _NoopSetupAction()),
        profilesActionProvider.overrideWith(() => spy),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
    });
    globalState.container = container;

    final profile = Profile.normal(
      label: 'test',
      url: 'https://example.com/sub',
    ).copyWith(autoUpdate: true);

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
          home: Navigator(
            pages: [
              MaterialPage(
                child: Builder(
                  builder: (context) => Scaffold(
                    body: EditProfileView(context: context, profile: profile),
                  ),
                ),
              ),
            ],
            onDidRemovePage: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // 间隔输入框是唯一一个初始内容全是数字的输入框。
    final intervalField = find.byWidgetPredicate((widget) {
      return widget is EditableText &&
          widget.controller.text.isNotEmpty &&
          int.tryParse(widget.controller.text) != null;
    });
    expect(intervalField, findsOneWidget, reason: '自动更新打开时应有间隔输入框');

    // 用户把间隔清空……
    await tester.enterText(intervalField, '');
    await tester.pump();

    // ……然后干脆把「自动更新」关掉。这一下会把间隔输入框从 Form 里摘掉，
    // 它的校验器随之停止运行，但控制器里还留着那个空串。
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(intervalField, findsNothing, reason: '关掉之后间隔输入框应当消失');

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(spy.saved, hasLength(1), reason: '点了保存就该真的保存');
    expect(spy.saved.single.autoUpdate, isFalse);
    expect(
      spy.saved.single.autoUpdateDuration,
      profile.autoUpdateDuration,
      reason: '间隔被清空时应当保留原值，而不是让整次保存炸掉',
    );
  });
}
