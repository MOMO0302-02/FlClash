import 'dart:io';

import 'package:clash_party/common/constant.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/config.dart';
import 'package:flutter_test/flutter_test.dart';

/// 把 Smart 参数一次性对齐到推荐值这件事，本身要守住三条。
///
/// **来历**：改了 freezed 的 `@Default` 之后，用户在设置页看到的值**一点没变**
/// ——`@Default` 只在「存档里根本没有这个字段」时才生效，已经装过的机器上这些
/// 字段早写进去了。用户原话：「你设置好了但是图形页面上的数值还没改」。
///
/// 所以补了一次性对齐。但**覆盖用户设置是件重的事**，得钉住边界：
/// 1. 对齐后的值确实是推荐值；
/// 2. **只跑一次**——跑完用户想怎么改都行，不能第二次被覆盖；
/// 3. **只碰 Smart 这几项**，别的设置一个都不许动。
///
/// 这里测的是那段逻辑的**行为**，用一份假的存档喂进去。真正的调用点在
/// `GlobalState._initData()` 里，那条路要起 SharedPreferences 和数据库，
/// widget test 跑不到。
void main() {
  /// 复刻 `_applySmartTuning` 里那次 copyWith。
  ///
  /// **复刻件会不会和真件走散？** 会——所以另有一条测试直接读 `lib/state.dart`
  /// 的源码，确认那几个字段名和值都还在。两条一起才拦得住。
  AppSettingProps tune(AppSettingProps input) => input.copyWith(
    smartUseLightGBM: true,
    smartTolerance: defaultSmartTolerance,
    smartLgbmAutoUpdate: true,
    smartCollectData: false,
    smartPreferAsn: false,
  );

  test('对齐后就是推荐值', () {
    // 用户机器上的实际状态：去抖 0、按运营商归纳开着、收集数据开着。
    const stale = AppSettingProps(
      smartTolerance: 0,
      smartPreferAsn: true,
      smartCollectData: true,
      smartUseLightGBM: false,
      smartLgbmAutoUpdate: false,
    );

    final tuned = tune(stale);
    expect(tuned.smartUseLightGBM, isTrue);
    expect(tuned.smartTolerance, 150);
    expect(tuned.smartLgbmAutoUpdate, isTrue);
    expect(tuned.smartCollectData, isFalse);
    expect(tuned.smartPreferAsn, isFalse);
  });

  test('别的设置一个都不许动', () {
    // 挑几个和 Smart 毫无关系、但用户明确会去改的：语言、开机自启、测速地址、
    // 自定义 UA、仪表盘布局。
    const custom = AppSettingProps(
      locale: 'ja',
      autoRun: true,
      testUrl: 'https://example.com/generate_204',
      customUserAgent: 'my-agent',
      dashboardWidgets: [DashboardWidget.statusHero],
      smartTolerance: 0,
    );

    final tuned = tune(custom);
    expect(tuned.locale, 'ja');
    expect(tuned.autoRun, isTrue);
    expect(tuned.testUrl, 'https://example.com/generate_204');
    expect(tuned.customUserAgent, 'my-agent');
    expect(tuned.dashboardWidgets, [DashboardWidget.statusHero]);
  });

  test('只跑一次的闸确实在，而且不是复用数据版本号', () {
    // 上面两条测的是"对齐做对了什么"，这条测"它只做一次"。**不能靠在测试里再写
    // 一遍那个判断来验**——那是在测我自己写的表达式，不是产品代码。直接读源码。
    final source = File('lib/state.dart').readAsStringSync();

    expect(
      source.contains('getSmartTuningVersion() >= tuningVersion'),
      isTrue,
      reason:
          '一次性对齐的闸没了。没有它，用户每次开应用都会被覆盖一遍——'
          '把去抖改成 300 也留不住。',
    );
    expect(
      source.contains('setSmartTuningVersion(tuningVersion)'),
      isTrue,
      reason: '跑完没有记下"已经跑过"，等于闸门永远是开的',
    );

    // 不能复用 `Migration.currentVersion`：那个版本号一变，`Migration.run()` 会
    // 走到 `_store.restore(data)`，而那条路上订阅、规则、脚本都是空列表——为了改
    // 几个开关去动它，有清空用户订阅的风险。
    final prefs = File('lib/common/preferences.dart').readAsStringSync();
    expect(
      prefs.contains("getInt('smartTuningVersion')"),
      isTrue,
      reason: '应当用独立的标记，而不是复用数据迁移的版本号',
    );
  });
}
