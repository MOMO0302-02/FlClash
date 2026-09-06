import 'dart:async';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/plugins/service.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'desktop/model.dart';
import 'interface.dart';
import 'method.dart';

class CoreLib extends CoreHandlerInterface {
  static CoreLib? _instance;

  Completer<bool> _connectedCompleter = Completer<bool>();

  /// 此刻有几个「正在连内核服务」的操作在跑。
  ///
  /// [_connectedCompleter] 只有 [start] 会完成它，[_stop] 会把它换成新的空
  /// completer。所以「没连上」有两种截然不同的含义：**正在连**（等一下就有结果）
  /// 和**没人在连**（等到天荒地老也不会有结果）。不分开的话后者要白等十秒。
  ///
  /// 用计数器不用布尔值：[restart] 会在外层括一次（覆盖 stop 与 start 之间那段
  /// 空窗），[start] 自己还要括一次，布尔值会被内层的 finally 提前清掉。
  int _connectingDepth = 0;

  bool get _connecting => _connectingDepth > 0;

  /// 这次会话有没有尝试过连接。
  ///
  /// 应用刚起来、[start] 还没被调用的那一小段时间里，抢先发出的调用仍然该等——
  /// 启动链马上就会去连。只有「连过一轮、现在断着」才是注定等不到的情况。
  bool _everTriedConnect = false;

  Future<CoreLifecycleResult>? _closeOperation;
  int _lifecycleRevision = 0;
  int _methodCallId = 0;
  bool _closed = false;

  CoreLib._internal();

  factory CoreLib() {
    _instance ??= CoreLib._internal();
    return _instance!;
  }

  /// 丢掉单例，让每条测试从干净的连接状态开始。
  ///
  /// 「等还是不等」取决于 [_everTriedConnect] 这类跨调用的状态，单例留着的话
  /// 测试之间会互相影响，结果取决于声明顺序。`CoreController` 已有同名的钩子。
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  @override
  Future<CoreLifecycleResult> start() async {
    if (_closed) {
      throw StateError('Core lifecycle is closed');
    }
    final revision = ++_lifecycleRevision;
    if (_connectedCompleter.isCompleted) {
      return CoreLifecycleResult(
        revision: revision,
        outcome: CoreLifecycleOutcome.coalesced,
      );
    }
    // 抛错也要把标记撤下来，否则失败一次之后所有调用又开始白等（那正是要修的
    // 毛病），所以用 try/finally 而不是在末尾赋值。
    _connectingDepth++;
    _everTriedConnect = true;
    try {
      final initializationError = await service?.init() ?? '';
      if (initializationError.isNotEmpty) {
        throw StateError(initializationError);
      }
      _connectedCompleter.complete(true);
      final syncError =
          await service?.syncState(
            globalState.container.read(sharedStateProvider),
          ) ??
          '';
      if (syncError.isNotEmpty) {
        _connectedCompleter = Completer<bool>();
        await service?.shutdown();
        throw StateError(syncError);
      }
      return CoreLifecycleResult(
        revision: revision,
        outcome: CoreLifecycleOutcome.applied,
      );
    } finally {
      _connectingDepth--;
    }
  }

  @override
  Future<CoreLifecycleResult> restart() async {
    // stop() 会把 completer 换成新的空的，而 start() 还没开始——这中间有一小段
    // 「断着且没人在连」，会被 invokeMethod 的快速失败分支当成「等不到了」。
    // 把整个重启括起来，让这段空窗仍然算正在连。
    _connectingDepth++;
    try {
      await stop();
      return await start();
    } finally {
      _connectingDepth--;
    }
  }

  @override
  Future<CoreLifecycleResult> stop() => _stop();

  Future<CoreLifecycleResult> _stop({bool allowClosed = false}) async {
    if (_closed && !allowClosed) {
      throw StateError('Core lifecycle is closed');
    }
    final revision = ++_lifecycleRevision;
    if (!_connectedCompleter.isCompleted) {
      return CoreLifecycleResult(
        revision: revision,
        outcome: CoreLifecycleOutcome.coalesced,
      );
    }
    _connectedCompleter = Completer<bool>();
    final stopped = await service?.shutdown() ?? true;
    if (!stopped) {
      throw StateError('Android Core service shutdown failed');
    }
    return CoreLifecycleResult(
      revision: revision,
      outcome: CoreLifecycleOutcome.applied,
    );
  }

  @override
  Future<CoreLifecycleResult> close() {
    return _closeOperation ??= _close();
  }

  Future<CoreLifecycleResult> _close() async {
    _closed = true;
    return _stop(allowClosed: true);
  }

  @override
  Future<bool> startListener() async {
    final listenerStarted = await super.startListener();
    final serviceStarted = await service?.start() ?? false;
    return listenerStarted && serviceStarted;
  }

  @override
  Future<bool> stopListener() async {
    final serviceStopped = await service?.stop() ?? false;
    final listenerStopped = await super.stopListener();
    return serviceStopped && listenerStopped;
  }

  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    if (!_connectedCompleter.isCompleted && !_connecting && _everTriedConnect) {
      // 连过一轮、现在断着、也没人在连——这个 completer 不会再被完成了
      // （只有 start() 会完成它）。等满十秒的结果和现在立刻返回一模一样，
      // 都是 null，区别只是白花十秒。启动链上有两次这样的调用，加起来把
      // `attach()` 拖到 10.6 秒，界面在这段时间里一直停在加载态。
      commonPrint.log(
        'Invoke method ${method.name} skipped: core service is not connected',
      );
      return null;
    }
    try {
      await _connectedCompleter.future.timeout(const Duration(seconds: 10));
    } catch (error) {
      commonPrint.log(
        'Invoke method ${method.name} before connection timed out: $error',
        logLevel: coreFailureLogLevel(error),
      );
      return null;
    }
    final id = '${++_methodCallId}';
    final response = await service
        ?.invokeMethod(
          CoreMethodCall(id: id, method: method, arguments: arguments),
        )
        .withTimeout(timeout: timeout, onTimeout: () => null);
    if (response == null) {
      return null;
    }
    return response.unwrap<T>();
  }
}

CoreLib? get coreLib => system.isAndroid ? CoreLib() : null;
