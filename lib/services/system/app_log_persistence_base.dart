abstract interface class AppLogPersistenceBackend {
  String? get currentLogPath;

  List<String> get startupDetails;

  Future<String?> startSession();

  void appendLines(Iterable<String> lines);

  void replaceLines(Iterable<String> lines);

  Future<void> close();
}
