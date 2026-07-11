import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/backend/ws_server.dart';

void main() {
  test('server stop tolerates client onDone removing connections', () async {
    final server = WsServer();
    final port = await server.start();
    final client = await WebSocket.connect('ws://127.0.0.1:$port');
    final connected = Completer<void>();
    final subscription = client.listen((_) {
      if (!connected.isCompleted) connected.complete();
    });
    await connected.future;

    await expectLater(server.stop(), completes);
    expect(server.clientCount, 0);
    await subscription.cancel();
  });
}
