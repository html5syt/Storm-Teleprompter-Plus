import 'app_log_persistence_base.dart';

class AppLogPersistence implements AppLogPersistenceBackend {
  @override
  String? get currentLogPath => null;

  @override
  List<String> get startupDetails => const [];

  @override
  Future<String?> startSession() async => null;

  @override
  void appendLines(Iterable<String> lines) {}

  @override
  void replaceLines(Iterable<String> lines) {}

  @override
  Future<void> close() async {}
}
