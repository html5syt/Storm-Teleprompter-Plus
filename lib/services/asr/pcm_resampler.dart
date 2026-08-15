import 'dart:typed_data';

class PcmResampler {
  PcmResampler({required this.targetSampleRate});

  final int targetSampleRate;
  double _position = 0;
  double? _tail;

  Float32List process(Float32List source, int sourceSampleRate) {
    if (sourceSampleRate == targetSampleRate) return source;
    if (source.isEmpty || sourceSampleRate <= 0 || targetSampleRate <= 0) {
      return Float32List(0);
    }

    final input = Float32List(source.length + (_tail == null ? 0 : 1));
    var offset = 0;
    final tail = _tail;
    if (tail != null) {
      input[0] = tail;
      offset = 1;
    }
    input.setRange(offset, input.length, source);
    if (input.length < 2) {
      _tail = input.last;
      return Float32List(0);
    }

    final step = sourceSampleRate / targetSampleRate;
    final output = <double>[];
    var position = _position;
    while (position < input.length - 1) {
      final index = position.floor();
      final fraction = position - index;
      output.add(input[index] * (1 - fraction) + input[index + 1] * fraction);
      position += step;
    }
    _position = position - (input.length - 1);
    _tail = input.last;
    return Float32List.fromList(output);
  }

  void reset() {
    _position = 0;
    _tail = null;
  }
}
