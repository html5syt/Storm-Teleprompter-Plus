import 'dart:async';

/// 同一异步操作未结束时复用其结果，锁在执行回调前建立以避免同步重入。
class SingleFlightAction<T> {
  Future<T>? _pending;

  /// 当前尚未完成的操作，供退出流程等待已经打开的手动保存操作。
  Future<T>? get pending => _pending;

  /// 重复调用不会再次执行回调；成功、取消和异常均释放本轮锁。
  Future<T> run(Future<T> Function() action) {
    final current = _pending;
    if (current != null) return current;
    final completer = Completer<T>();
    _pending = completer.future;
    unawaited(_execute(action, completer));
    return completer.future;
  }

  /// 捕获异步错误传给所有调用方，避免未处理异常导致永久锁定。
  Future<void> _execute(
    Future<T> Function() action,
    Completer<T> completer,
  ) async {
    try {
      completer.complete(await action());
    } catch (error, stack) {
      completer.completeError(error, stack);
    } finally {
      _pending = null;
    }
  }
}
