import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 「一开就崩」的自救网必须是接通的，**而且不能误伤**。
///
/// **第一段来历**：Firebase / Crashlytics 从本项目移除后，原生侧的崩溃检测被留成
/// 了一个恒返回 false 的空桩，整条恢复逻辑永远走不到——那不是多余功能，是一张
/// 坏掉的安全网。于是用「持久化标记」把它接了回来。
///
/// **第二段来历（更重要）**：接回来的第一版判定的是「**有没有正常退出**」，清除
/// 标记只发生在 `MainActivity.onDestroy()` 且 `isFinishing` 为真时。而安卓上
/// **覆盖安装新版本、系统回收后台进程、从最近任务里划掉**都不会走到那儿——对一个
/// 常驻后台的代理应用来说，这三种情况天天发生。结果就是**每次启动都被判成崩溃**。
/// 用户装完新版一开就弹「检测到崩溃」，正是这个。
///
/// 而误报是有代价的：判定为崩溃会**清掉用户当前选中的订阅**。当初的注释里写
/// 「代价只是一句提示」，那句话是错的。
///
/// **现在的判定是「上次启动有没有走完」**：启动时置位，Dart 侧走完 `attach()`
/// 才清除。后台被回收 / 覆盖安装 / 划掉任务都发生在启动早已走完之后，不会误报；
/// 而真正的死循环里启动永远走不完，一定抓得到。
///
/// 这条测试**扫原生源码**：判定逻辑在 Kotlin 里，Flutter 的 widget test 跑不到；
/// 而「有没有人又把它改回去」恰恰是一次文本检查就能钉死的事。
void main() {
  const globalState =
      'android/common/src/main/java/com/clashparty/app/common/GlobalState.kt';
  const mainActivity =
      'android/app/src/main/kotlin/com/clashparty/app/MainActivity.kt';
  const stateDart = 'lib/state.dart';

  test('检测不是空桩，而且基于持久化标记', () {
    final source = File(globalState).readAsStringSync();

    expect(
      source.contains('getSharedPreferences'),
      isTrue,
      reason: '检测应当基于持久化标记，没看到读写标记的代码',
    );
    expect(
      source.contains('fun consumeStartupFailureStreak(): Int'),
      isTrue,
      reason: '缺少「连续多少次启动没走完」的入口',
    );
    expect(
      source.contains('fun markStartupComplete()'),
      isTrue,
      reason: '缺少清除标记的入口。只置位不清除的话，每次启动都会被判成崩溃',
    );
  });

  test('判定的是「启动有没有走完」，不是「有没有正常退出」', () {
    final activity = File(mainActivity).readAsStringSync();

    // 这是那次误报的根：`onDestroy` 在覆盖安装、系统回收、划掉任务时都不会走到，
    // 用它清标记等于把这些全算成崩溃。
    expect(
      activity.contains('markCleanExit'),
      isFalse,
      reason:
          'MainActivity 又回到「正常退出才清标记」了。'
          '覆盖安装 / 系统回收后台 / 从最近任务划掉都不会走到 onDestroy，'
          '那样每次启动都被判成崩溃，用户每次都被清掉当前订阅。',
    );

    final state = File(stateDart).readAsStringSync();
    expect(
      state.contains('markStartupComplete'),
      isTrue,
      reason: '没有人在启动走完时清标记，下次启动一定会被算成失败',
    );
  });

  test('要连续两次启动没走完，才动用户的配置', () {
    final state = File(stateDart).readAsStringSync();

    // 一次不算：用户在启动头几秒手动强杀、系统正好那几秒回收进程，都会留下一次
    // 未完成的启动。而认定崩溃会清掉当前订阅，这个代价不该由一次偶发事件触发。
    // 真正的死循环十秒内就能满两次。
    expect(
      state.contains('consumeStartupFailureStreak() >= 2'),
      isTrue,
      reason:
          '门槛不是「连续两次」了。降到一次的话，用户在启动头几秒强杀一次应用，'
          '下次开就会被清掉订阅。',
    );
  });
}
