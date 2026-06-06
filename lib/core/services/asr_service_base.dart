import 'dart:async';
import 'dart:typed_data';

import '../models/app_models.dart';

class AsrFrame {
  const AsrFrame({
    required this.text,
    required this.isFinal,
    required this.rms,
  });

  final String text;
  final bool isFinal;
  final double rms;
}

abstract class TeleprompterAsrService {
  Future<void> initialize({required ModelPackage model});

  Future<void> start({required String scriptText});

  Future<void> stop();

  Stream<AsrFrame> get frames;

  bool get isReady;

  String get statusMessage;

  void acceptWaveform(Float32List samples, int sampleRate) {}
}
