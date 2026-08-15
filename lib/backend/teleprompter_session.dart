import 'dart:async';
import 'package:flutter/foundation.dart';
import 'ws_protocol.dart';
import 'ws_server.dart';
import 'asr_session_service.dart';

class TeleprompterSession {
  AsrSessionService? _asrSession;
  WsServer? _server;

  void bindAsrSession(AsrSessionService service) => _asrSession = service;

  String? _activeArticleId;

  int _currentIndex = -1;

  bool _isPlaying = false;

  Map<String, dynamic> _settingsOverride = {};

  Map<String, dynamic>? _articleSnapshot;

  int _revision = 0;

  final StreamController<TeleprompterSessionState> _stateController =
      StreamController<TeleprompterSessionState>.broadcast();

  Stream<TeleprompterSessionState> get stateStream => _stateController.stream;

  String? get activeArticleId => _activeArticleId;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  Map<String, dynamic> get settingsOverride =>
      Map.unmodifiable(_settingsOverride);

  void registerHandlers(WsServer server) {
    _server = server;
    server.requests.listen((request) {
      switch (request.message.type) {
        case WsMessageType.teleprompterStartSession:
          _handleStartSession(server, request);
          break;
        case WsMessageType.teleprompterEndSession:
          _handleEndSession(server, request);
          break;
        case WsMessageType.teleprompterSync:
          _handleSync(server, request);
          break;
        case WsMessageType.teleprompterSettingsUpdate:
          _handleSettingsUpdate(server, request);
          break;
        default:
          break;
      }
    });
  }

  void _handleStartSession(WsServer server, WsRequest request) {
    final data = request.message.data;
    _activeArticleId = data['articleId'] as String?;
    _currentIndex = data['currentIndex'] as int? ?? -1;
    _isPlaying = data['isPlaying'] as bool? ?? false;
    _settingsOverride = Map<String, dynamic>.from(
      data['settings'] as Map? ?? {},
    );
    _articleSnapshot = data['article'] == null
        ? null
        : Map<String, dynamic>.from(data['article'] as Map);
    _revision++;

    final content = _articleSnapshot?['content'] as String? ?? '';
    if (_activeArticleId != null && content.isNotEmpty) {
      _asrSession?.beginSession(
        articleId: _activeArticleId!,
        content: content,
        currentIndex: _currentIndex,
      );
    }

    debugPrint('[TeleprompterSession] 会话开始: $_activeArticleId');

    _emitState();

    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.teleprompterStartSessionResponse,
        id: request.message.id,
        data: {
          'success': true,
          'articleId': _activeArticleId,
          'revision': _revision,
        },
      ),
    );

    server.broadcastExcept(
      request.clientId,
      WsMessage(
        type: WsMessageType.teleprompterStartSession,
        data: _sessionData(),
      ),
    );
  }

  void _handleEndSession(WsServer server, WsRequest request) {
    debugPrint('[TeleprompterSession] 会话结束: $_activeArticleId');

    _activeArticleId = null;
    _currentIndex = -1;
    _isPlaying = false;
    _settingsOverride = {};
    _articleSnapshot = null;
    _revision++;
    unawaited(_asrSession?.endSession());

    _emitState();

    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.teleprompterEndSessionResponse,
        id: request.message.id,
        data: {'success': true, 'revision': _revision},
      ),
    );

    server.broadcastExcept(
      request.clientId,
      WsMessage(
        type: WsMessageType.teleprompterEndSession,
        data: _sessionData(),
      ),
    );
  }

  void _handleSync(WsServer server, WsRequest request) {
    final data = request.message.data;
    _currentIndex = data['currentIndex'] as int? ?? _currentIndex;
    _isPlaying = data['isPlaying'] as bool? ?? _isPlaying;
    _asrSession?.setCurrentIndex(_currentIndex);
    _revision++;

    _emitState();
    final sessionData = _sessionData();

    if (request.message.id != null) {
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.teleprompterSync,
          id: request.message.id,
          data: sessionData,
        ),
      );
    }

    server.broadcastExcept(
      request.clientId,
      WsMessage(type: WsMessageType.teleprompterSync, data: sessionData),
    );
  }

  void _handleSettingsUpdate(WsServer server, WsRequest request) {
    final data = request.message.data;
    _settingsOverride = Map<String, dynamic>.from(
      data['settings'] as Map? ?? {},
    );
    _revision++;

    _emitState();

    server.broadcastExcept(
      request.clientId,
      WsMessage(
        type: WsMessageType.teleprompterSettingsUpdate,
        data: _sessionData(),
      ),
    );
  }

  void updateCurrentIndexFromAsr(
    int currentIndex, {
    bool allowBackward = false,
  }) {
    if (_activeArticleId == null ||
        (!allowBackward && currentIndex < _currentIndex)) {
      return;
    }
    _currentIndex = currentIndex;
    _revision++;
    _emitState();
    _server?.broadcast(
      WsMessage(type: WsMessageType.teleprompterSync, data: _sessionData()),
    );
  }

  Map<String, dynamic> _sessionData() {
    return {
      'articleId': _activeArticleId,
      'currentIndex': _currentIndex,
      'isPlaying': _isPlaying,
      'settings': _settingsOverride,
      'revision': _revision,
      if (_articleSnapshot != null) 'article': _articleSnapshot,
    };
  }

  void _emitState() {
    _stateController.add(
      TeleprompterSessionState(
        articleId: _activeArticleId,
        currentIndex: _currentIndex,
        isPlaying: _isPlaying,
        settingsOverride: _settingsOverride,
      ),
    );
  }

  void reset() {
    unawaited(_asrSession?.endSession());
    _activeArticleId = null;
    _currentIndex = -1;
    _isPlaying = false;
    _settingsOverride = {};
    _articleSnapshot = null;
    _revision = 0;
  }

  void dispose() {
    _stateController.close();
  }
}

class TeleprompterSessionState {
  final String? articleId;
  final int currentIndex;
  final bool isPlaying;
  final Map<String, dynamic> settingsOverride;

  const TeleprompterSessionState({
    this.articleId,
    this.currentIndex = -1,
    this.isPlaying = false,
    this.settingsOverride = const {},
  });
}
