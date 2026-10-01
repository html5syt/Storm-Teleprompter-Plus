import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/utils/single_flight_action.dart';

/// 验证退出/保存事务的重入共享与异常后的解锁，不依赖窗口原生插件。
void main() {
  test('同步重入也只执行一次，完成后允许下一次操作', () async {
    final gate = SingleFlightAction<bool>();
    final result = Completer<bool>();
    var executions = 0;
    Future<bool>? reentrant;
    final first = gate.run(() {
      executions++;
      reentrant = gate.run(() async {
        executions++;
        return false;
      });
      return result.future;
    });
    expect(first, same(reentrant));
    final second = gate.run(() async {
      executions++;
      return false;
    });
    expect(first, same(second));
    result.complete(true);
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(executions, 1);
    expect(gate.pending, isNull);
    expect(await gate.run(() async => false), isFalse);
  });

  test('失败不会留下永久锁', () async {
    final gate = SingleFlightAction<void>();
    await expectLater(
      gate.run(() async => throw StateError('failure')),
      throwsStateError,
    );
    expect(gate.pending, isNull);
    var completed = false;
    await gate.run(() async {
      completed = true;
    });
    expect(completed, isTrue);
  });
}
