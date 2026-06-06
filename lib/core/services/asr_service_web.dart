import 'dart:async';
import 'dart:typed_data';

import '../models/app_models.dart';
import 'asr_service_base.dart';

class UnsupportedAsrService implements TeleprompterAsrService {
  UnsupportedAsrService();

  final StreamController<AsrFrame> _frameController =
      StreamController<AsrFrame>.broadcast();

  @override
  Stream<AsrFrame> get frames => _frameController.stream;

  @override
  bool get isReady => true;

  @override
  String get statusMessage => 'Web 环境正在使用模拟识别服务';

  @override
  void acceptWaveform(Float32List samples, int sampleRate) {
    if (_frameController.isClosed) return;
  }

  @override
  Future<void> initialize({required ModelPackage model}) async {
    // _ready = true;
  }

  @override
  Future<void> start({required String scriptText}) async {
    // _running = true;
  }

  @override
  Future<void> stop() async {
    // _running = false;
  }
}

TeleprompterAsrService createAsrService() {
  return UnsupportedAsrService();
}
