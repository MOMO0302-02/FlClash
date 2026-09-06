import 'package:clash_party/common/constant.dart';
import 'package:clash_party/plugins/app.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 「上次启动有没有走完」这条通道。
///
/// **判定口径换过一次。** 原来记的是「有没有正常退出」，而清除标记只发生在
/// `MainActivity.onDestroy()` 且 `isFinishing` 为真时——**覆盖安装新版本、系统
/// 回收后台进程、从最近任务里划掉**都不会走到那儿，于是每次启动都被判成崩溃。
/// 用户实际遇到的就是这个：装完新版一开就弹「检测到崩溃」。
///
/// 误报不是没代价的：判定为崩溃会**清掉用户当前选中的订阅**。
///
/// 现在记的是「启动有没有走完」，并且返回**连续**失败次数（调用方要求满 2 次才
/// 动配置）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('$packageName/app');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('从原生侧读连续失败次数', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return 2;
        });

    expect(await App().consumeStartupFailureStreak(), 2);
    expect(receivedCall, isNotNull);
    expect(receivedCall!.method, 'consumeStartupFailureStreak');
  });

  test('原生侧没给值时当作 0——没崩过', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);

    expect(await App().consumeStartupFailureStreak(), 0);
  });

  test('通道不可用时也当作 0', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'unavailable');
        });

    // 这道网是用来兜底的，它自己出问题不该反过来去清用户的配置。
    expect(await App().consumeStartupFailureStreak(), 0);
  });

  test('启动走完了要回报给原生侧', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return true;
        });

    await App().markStartupComplete();

    expect(receivedCall, isNotNull);
    expect(receivedCall!.method, 'markStartupComplete');
  });

  test('回报失败不抛出——最多下次多算一次，不该打断启动', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'unavailable');
        });

    await expectLater(App().markStartupComplete(), completes);
  });
}
