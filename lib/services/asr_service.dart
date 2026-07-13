/// 按平台选择语音识别服务实现。
export 'asr/asr_service_stub.dart'
    if (dart.library.io) 'asr/asr_service_native.dart';
