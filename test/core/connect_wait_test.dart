import 'dart:async';

import 'package:clash_party/core/lib.dart';
import 'package:clash_party/core/method.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// 内核没连上的时候，到底该不该等。
///
/// **来历**：真机实测 `globalState.attach()` 要 10.6 秒才走完，其中约 10 秒耗在
/// 「等内核连上」这个 await 上，等了两次。`attach()` 走完之前 `initProvider`
/// 一直是 false，界面停在加载态，深链和快捷方式也还没接上。
///
/// 那个等待本身没错——安卓端内核跑在另一个进程里，连接要时间。错的是它**分不清
/// 两种「没连上」**：正在连（等一下就有结果）和没人在连（等到天荒地老也不会有
/// 结果）。那个 completer 只有 `start()` 会完成，而 `stop()` 会把它换成一个新的
/// 空的，于是「停过内核之后」和「start() 抛错之后」的每一次调用都白等满十秒，
/// 再返回和立刻返回一模一样的 null。
///
/// 这里钉三件事，**必须同时成立**才算修对：
/// 1. 断着且没人在连 → 直接跳过，不等；
/// 2. 还没连过（应用刚起来，启动链马上就要去连）→ 仍然等；
/// 3. 重启途中（stop 与 start 之间那段空窗）→ 仍然等。
///
/// 只钉第 1 条是不够的：把等待整个砍掉也能让它变绿，而那会让重启期间用户手点的
/// 动作（比如测延迟）变成静默无反应。
void main() {
  /// 测的是**真的 `CoreLib`**，不是复刻件。
  ///
  /// 能这么测是因为宿主机上 `service` 取值为 null（那个 getter 只在安卓上给实例），
  /// 于是 `start()` / `stop()` 里所有平台通道调用都被 `?.` 短路掉，只剩下要测的
  /// 那套连接状态判断。Dart 的 `?.` 连实参都不会求值，所以 `syncState` 里那句
  /// `globalState.container.read(...)` 也不会跑。
  setUp(CoreLib.resetInstance);
  tearDown(CoreLib.resetInstance);

  /// 发一个调用出去，回答「它被跳过了吗、它完成了吗」。
  ///
  /// **判定「跳过」看的是日志，不是耗时。** 耗时区分不出「被丢掉」和「正好赶上
  /// 连接完成」——宿主机上 `restart()` 几乎瞬间跑完，两种情况都是「很快就有结果」。
  /// 而跳过分支会打一行专门的日志，那才是唯一能把两者分开的证据。
  ///
  /// 50 毫秒离那个十秒的超时差着两个数量级，够判断「还在等」，又不拖慢测试。
  Future<({bool skipped, bool completed})> probe(CoreLib core) async {
    final lines = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) {
        lines.add(message);
      }
    };

    var completed = false;
    unawaited(
      core.invokeMethod<bool>(method: CoreMethod.getIsInit).then((_) {
        completed = true;
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    debugPrint = original;

    return (
      skipped: lines.any((item) => item.contains('skipped')),
      completed: completed,
    );
  }

  test('还没连过的时候仍然等——启动链马上就要去连', () async {
    final result = await probe(CoreLib());
    expect(result.skipped, isFalse, reason: '应用刚起来时抢先发出的调用不该被丢掉');
    expect(result.completed, isFalse, reason: '应该还挂在那儿等连接');
  });

  test('连过一轮又停了之后，直接跳过，不再白等十秒', () async {
    final core = CoreLib();
    await core.start();
    await core.stop();

    final result = await probe(core);
    expect(
      result.skipped,
      isTrue,
      reason: '停了内核之后没人会再完成那个 completer，等下去只是白等',
    );
    expect(result.completed, isTrue, reason: '跳过就该当场返回');
  });

  test('重启途中仍然等：stop 与 start 之间那段空窗不算「等不到」', () async {
    final core = CoreLib();
    await core.start();

    // 重启内部是 stop 之后再 start。`restart()` 同步跑到第一个 await 才让出控制权，
    // 所以这时候正卡在那段空窗里——不把整个重启括进「正在连」的话，这一发调用会
    // 被当成「等不到」直接丢掉。
    final restart = core.restart();
    final result = await probe(core);
    await restart;

    expect(
      result.skipped,
      isFalse,
      reason: '重启途中把调用丢掉，用户手点的动作会变成静默无反应',
    );
  });

  test('连上之后正常放行', () async {
    final core = CoreLib();
    await core.start();

    final result = await probe(core);
    expect(result.skipped, isFalse);
    expect(result.completed, isTrue, reason: '已经连上了还等，那就白等了');
  });
}
