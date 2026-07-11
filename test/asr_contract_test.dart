import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/backend/asr_session_service.dart';
import 'package:storm_teleprompter_plus/backend/ws_protocol.dart';
import 'package:storm_teleprompter_plus/models/app_settings.dart';
import 'package:storm_teleprompter_plus/services/alignment_engine.dart';

void main() {
  group('ASR settings', () {
    test('advanced recognizer parameters survive JSON round trip', () {
      final settings = const AppSettings().copyWith(
        asrModelId: 'streaming-model',
        asrModelName: 'Streaming model',
        asrMirrorUrl: 'https://mirror.example/',
        asrNumThreads: 6,
        asrRule1MinTrailingSilence: 1.8,
        asrRule2MinTrailingSilence: 0.8,
        asrRule3MinUtteranceLength: 16,
        asrUseSystemProxy: false,
        asrInputDeviceId: 'microphone-1',
        asrInputDeviceName: 'Studio microphone',
      );

      final restored = AppSettings.fromJson(settings.toJson());

      expect(restored.asrModelId, 'streaming-model');
      expect(restored.asrMirrorUrl, 'https://mirror.example/');
      expect(restored.asrNumThreads, 6);
      expect(restored.asrRule1MinTrailingSilence, 1.8);
      expect(restored.asrRule2MinTrailingSilence, 0.8);
      expect(restored.asrRule3MinUtteranceLength, 16);
      expect(restored.asrUseSystemProxy, isFalse);
      expect(restored.asrInputDeviceId, 'microphone-1');
      expect(restored.asrInputDeviceName, 'Studio microphone');
    });

    test('article overrides preserve server-only ASR settings', () {
      final settings = const AppSettings().copyWith(
        asrNumThreads: 8,
        asrRule1MinTrailingSilence: 1.5,
        asrUseSystemProxy: false,
        asrInputDeviceId: 'microphone-2',
      );

      final merged = settings.mergeOverrides({'fontSize': 80});

      expect(merged.fontSize, 80);
      expect(merged.asrNumThreads, 8);
      expect(merged.asrRule1MinTrailingSilence, 1.5);
      expect(merged.asrUseSystemProxy, isFalse);
      expect(merged.asrInputDeviceId, 'microphone-2');
    });
  });

  group('ASR websocket protocol', () {
    test('request and response message types are stable', () {
      expect(WsMessageType.fromString('asr:start'), WsMessageType.asrStart);
      expect(
        WsMessageType.fromString('asr:start_response'),
        WsMessageType.asrStartResponse,
      );
      expect(WsMessageType.fromString('asr:pause'), WsMessageType.asrPause);
      expect(WsMessageType.fromString('asr:result'), WsMessageType.asrResult);
      expect(WsMessageType.fromString('asr:status'), WsMessageType.asrStatus);
    });
  });

  group('server-side transcript alignment', () {
    test('partial results advance without moving backwards', () {
      final alignment = TeleprompterAlignment()..setScript('欢迎使用飓风提词器，现在开始测试。');

      final first = alignment.consumeTranscript('欢迎使用', false);
      final second = alignment.consumeTranscript('欢迎使用飓风', false);
      final noisy = alignment.consumeTranscript('完全无关内容', false);

      expect(first.index, greaterThanOrEqualTo(0));
      expect(second.index, greaterThanOrEqualTo(first.index));
      expect(noisy.index, greaterThanOrEqualTo(second.index));
    });

    test('final result commits the anchor for the next phrase', () {
      final alignment = TeleprompterAlignment()..setScript('第一句话结束。第二句话继续。');

      final first = alignment.consumeTranscript('第一句话结束', true);
      final second = alignment.consumeTranscript('第二句话继续', true);

      expect(second.index, greaterThan(first.index));
    });

    test('manual cursor move resets the matching anchor', () {
      final alignment = TeleprompterAlignment()..setScript('重复内容前段重复内容后段');

      alignment.setCurrentIndex(5);
      final result = alignment.consumeTranscript('重复内容后段', true);

      expect(result.index, 11);
    });

    test('script omissions and transcript hallucinations stay aligned', () {
      final alignment = TeleprompterAlignment()..setScript('今天我们一起测试语音跟随功能');

      final omitted = alignment.consumeTranscript('今天一起测试', false);
      final hallucinated = alignment.consumeTranscript('今天我们真的一起测试语音', false);

      expect(omitted.index, greaterThanOrEqualTo(5));
      expect(hallucinated.index, greaterThanOrEqualTo(omitted.index));
    });

    test('ASR advances are limited like the reference client', () {
      expect(
        AsrSessionService.limitAdvance(
          currentIndex: 10,
          requestedIndex: 100,
          isFinal: false,
        ),
        14,
      );
      expect(
        AsrSessionService.limitAdvance(
          currentIndex: 10,
          requestedIndex: 100,
          isFinal: true,
        ),
        16,
      );
      expect(
        AsrSessionService.limitAdvance(
          currentIndex: -1,
          requestedIndex: 20,
          isFinal: false,
        ),
        20,
      );
    });
  });
}
