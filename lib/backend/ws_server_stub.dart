import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ws_protocol.dart';

class WsServer {
  final StreamController<WsRequest> _requestController =
      StreamController<WsRequest>.broadcast();

  bool get isRunning => false;
  int get port => 0;
  int get clientCount => 0;
  List<String> get clientIds => const [];
  Stream<WsRequest> get requests => _requestController.stream;

  Future<int> start({int port = 0}) async {
    debugPrint('[WsServer] Local backend server is not available on Web.');
    return 0;
  }

  Future<void> stop() async {}

  void respond(String clientId, WsMessage message) {}

  void broadcast(WsMessage message) {}

  void broadcastExcept(String excludedClientId, WsMessage message) {}

  void dispose() {
    _requestController.close();
  }
}

class WsRequest {
  final String clientId;
  final WsMessage message;

  const WsRequest({required this.clientId, required this.message});
}
