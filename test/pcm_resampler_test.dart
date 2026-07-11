import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/services/pcm_resampler.dart';

void main() {
  test('resamples 48 kHz PCM to 16 kHz', () {
    final resampler = PcmResampler(targetSampleRate: 16000);
    final source = Float32List.fromList(
      List<double>.generate(480, (index) => index / 480),
    );

    final output = resampler.process(source, 48000);

    expect(output.length, closeTo(160, 1));
    expect(output.first, closeTo(source.first, 0.0001));
  });

  test('preserves continuity across audio chunks', () {
    final resampler = PcmResampler(targetSampleRate: 16000);
    final first = Float32List.fromList(
      List<double>.generate(241, (index) => index.toDouble()),
    );
    final second = Float32List.fromList(
      List<double>.generate(239, (index) => index + 241.0),
    );

    final combined = <double>[
      ...resampler.process(first, 48000),
      ...resampler.process(second, 48000),
    ];

    expect(combined.length, closeTo(160, 1));
    for (var index = 1; index < combined.length; index++) {
      expect(combined[index], greaterThan(combined[index - 1]));
    }
  });

  test('supports 44.1 kHz Windows capture formats', () {
    final resampler = PcmResampler(targetSampleRate: 16000);
    final source = Float32List.fromList(
      List<double>.generate(441, (index) => index / 441),
    );

    final output = resampler.process(source, 44100);

    expect(output.length, closeTo(160, 1));
  });
}
