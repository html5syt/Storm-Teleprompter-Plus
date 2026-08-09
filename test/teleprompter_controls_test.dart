import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/backend/ws_protocol.dart';
import 'package:storm_teleprompter_plus/models/app_settings.dart';
import 'package:storm_teleprompter_plus/providers/connection_provider.dart';
import 'package:storm_teleprompter_plus/providers/teleprompter_provider.dart';

void main() {
  testWidgets('pinned overlays ignore auto-hide until unpinned', (
    tester,
  ) async {
    const settings = AppSettings(wpm: 0, autoHideDelaySeconds: 1);
    final provider = TeleprompterProvider()..loadScript('article', '测试正文');
    void listener() {}

    provider.addListener(listener);
    addTearDown(() {
      provider.removeListener(listener);
      provider.dispose();
    });

    provider.play(settings);
    provider.toggleControlsPinned(settings);
    await tester.pump(const Duration(seconds: 2));

    expect(provider.controlsPinned, isTrue);
    expect(provider.controlsVisible, isTrue);

    provider.toggleControls();
    expect(provider.controlsVisible, isTrue);

    provider.toggleControlsPinned(settings);
    await tester.pump(const Duration(seconds: 2));

    expect(provider.controlsPinned, isFalse);
    expect(provider.controlsVisible, isFalse);
    provider.stopAll();
  });

  test('ASR resume keeps a manually reset cursor at the start', () async {
    const settings = AppSettings(scrollMode: ScrollMode.asr);
    final connection = _FakeConnectionProvider();
    final provider = TeleprompterProvider()
      ..bindConnection(connection)
      ..loadScript('article', 'abcdef');
    addTearDown(() {
      provider.dispose();
      connection.dispose();
    });

    provider.play(settings);
    await _flushAsyncWork();
    connection.emit(
      const WsMessage(
        type: WsMessageType.asrResult,
        data: {'articleId': 'article', 'status': 'running', 'currentIndex': 4},
      ),
    );
    await _flushAsyncWork();
    expect(provider.currentIndex, 4);

    provider.pause(settings);
    provider.resetToStart();
    await _flushAsyncWork();
    expect(provider.currentIndex, -1);
    expect(connection.sentSyncIndices, contains(-1));

    // 晚到的暂停状态仍携带旧位置，但状态消息不能覆盖手动游标。
    connection.emit(
      const WsMessage(
        type: WsMessageType.asrStatus,
        data: {'articleId': 'article', 'status': 'paused', 'currentIndex': 4},
      ),
    );
    await _flushAsyncWork();
    expect(provider.currentIndex, -1);

    connection.requestTypes.clear();
    provider.play(settings);
    await _flushAsyncWork();

    expect(provider.currentIndex, -1);
    final firstStart = connection.requestTypes.indexOf(WsMessageType.asrStart);
    final firstSync = connection.requestTypes.indexOf(
      WsMessageType.teleprompterSync,
    );
    expect(firstSync, greaterThanOrEqualTo(0));
    expect(firstStart, greaterThan(firstSync));
  });

  test('ASR start sends the locally measured search window once', () async {
    const settings = AppSettings(scrollMode: ScrollMode.asr);
    final connection = _FakeConnectionProvider();
    final provider = TeleprompterProvider()
      ..bindConnection(connection)
      ..loadScript('article', '第一行\n第二行\n第三行');
    addTearDown(() {
      provider.dispose();
      connection.dispose();
    });

    provider.play(
      settings,
      asrSearchWindow: (startRawIndex: 0, endRawIndex: 8),
    );
    await _flushAsyncWork();

    final startRequest = connection.requestTypes.indexOf(
      WsMessageType.asrStart,
    );
    expect(startRequest, greaterThanOrEqualTo(0));
    expect(connection.requestData[startRequest], {
      'asrSearchStart': 0,
      'asrSearchEnd': 8,
    });
  });
}

Future<void> _flushAsyncWork() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

class _FakeConnectionProvider extends ConnectionProvider {
  final StreamController<WsMessage> _messages =
      StreamController<WsMessage>.broadcast();
  final List<WsMessageType> requestTypes = <WsMessageType>[];
  final List<Map<String, dynamic>> requestData = <Map<String, dynamic>>[];
  final List<int> sentSyncIndices = <int>[];

  @override
  bool get isConnected => true;

  @override
  bool get isLocal => true;

  @override
  List<String> get remoteDeviceIds => const <String>[];

  void emit(WsMessage message) => _messages.add(message);

  @override
  Stream<WsMessage> listenTo(WsMessageType type) {
    return _messages.stream.where((message) => message.type == type);
  }

  @override
  Future<WsMessage> request(
    WsMessageType type, {
    Map<String, dynamic> data = const {},
    Duration timeout = const Duration(seconds: 10),
  }) async {
    requestTypes.add(type);
    requestData.add(data);
    await Future<void>.delayed(Duration.zero);
    return WsMessage(
      type: switch (type) {
        WsMessageType.asrStart => WsMessageType.asrStartResponse,
        WsMessageType.asrPause => WsMessageType.asrPauseResponse,
        _ => type,
      },
      data: {
        ...data,
        if (type == WsMessageType.asrStart || type == WsMessageType.asrPause)
          'articleId': 'article',
        if (type == WsMessageType.asrStart || type == WsMessageType.asrPause)
          'status': type == WsMessageType.asrStart ? 'running' : 'paused',
        if (type == WsMessageType.asrStart || type == WsMessageType.asrPause)
          'currentIndex': 4,
      },
    );
  }

  @override
  void send(WsMessage message) {
    if (message.type == WsMessageType.teleprompterSync) {
      sentSyncIndices.add((message.data['currentIndex'] as num).toInt());
    }
  }

  @override
  void dispose() {
    _messages.close();
    super.dispose();
  }
}
