import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/backend/teleprompter_session.dart';
import 'package:storm_teleprompter_plus/backend/ws_protocol.dart';
import 'package:storm_teleprompter_plus/backend/ws_server.dart';
import 'package:storm_teleprompter_plus/models/app_settings.dart';
import 'package:storm_teleprompter_plus/providers/teleprompter_provider.dart';

/// 用真实 WebSocket 验证匀速设置与视口数据能穿过会话服务。
void main() {
  test('匀速会话同步像素速度与视口进度，旧消息仍兼容', () async {
    final server = WsServer();
    final session = TeleprompterSession()..registerHandlers(server);
    final port = await server.start();
    final master = await WebSocket.connect('ws://127.0.0.1:$port');
    final follower = await WebSocket.connect('ws://127.0.0.1:$port');
    final messages = follower
        .map((raw) => WsMessage.fromString(raw as String))
        .asBroadcastStream();
    final masterSubscription = master.listen((_) {});
    const settings = AppSettings(
      autoScrollMode: AutoScrollMode.continuous,
      pixelsPerSecond: -12.5,
    );
    final started = messages.firstWhere(
      (m) => m.type == WsMessageType.teleprompterStartSession,
    );
    master.add(
      WsMessage(
        type: WsMessageType.teleprompterStartSession,
        data: {'articleId': 'draft', 'settings': settings.toTeleprompterMap()},
      ).encode(),
    );
    final start = await started.timeout(const Duration(seconds: 3));
    expect(start.data['settings']['pixelsPerSecond'], -12.5);
    final synced = messages.firstWhere(
      (m) => m.type == WsMessageType.teleprompterSync,
    );
    master.add(
      const WsMessage(
        type: WsMessageType.teleprompterSync,
        data: {'currentIndex': -1, 'isPlaying': true, 'scrollProgress': 0.375},
      ).encode(),
    );
    final message = await synced.timeout(const Duration(seconds: 3));
    expect(message.data['scrollProgress'], 0.375);
    final provider = TeleprompterProvider()..loadScript('draft', '正文');
    provider.applyRemoteSync(
      currentIndex: -1,
      isPlaying: true,
      settings: settings,
      scrollProgress: (message.data['scrollProgress'] as num).toDouble(),
    );
    expect(provider.progress, 0.375);
    expect(provider.isPlaying, isTrue);
    provider.applyRemoteSync(
      currentIndex: 0,
      isPlaying: false,
      settings: const AppSettings(),
    );
    expect(provider.currentIndex, 0);
    provider.dispose();
    await master.close();
    await follower.close();
    await masterSubscription.cancel();
    await server.stop();
    session.dispose();
  });
}
