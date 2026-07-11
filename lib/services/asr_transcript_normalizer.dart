import 'dart:math';

/// Removes pathological repetitions commonly emitted by streaming ASR.
String normalizeAsrTranscript(String text) {
  if (text.isEmpty) return text;
  final source = text.runes.toList(growable: false);
  final collapsedRuns = <int>[];

  for (var index = 0; index < source.length;) {
    var end = index + 1;
    while (end < source.length && source[end] == source[index]) {
      end++;
    }
    final count = end - index;
    if (count >= 3) {
      collapsedRuns.add(source[index]);
    } else {
      collapsedRuns.addAll(source.sublist(index, end));
    }
    index = end;
  }

  final result = <int>[];
  for (var index = 0; index < collapsedRuns.length;) {
    var repeatedLength = 0;
    final maxLength = min(8, (collapsedRuns.length - index) ~/ 2);
    for (var length = maxLength; length >= 2; length--) {
      if (_rangesEqual(collapsedRuns, index, index + length, length)) {
        repeatedLength = length;
        break;
      }
    }
    if (repeatedLength == 0) {
      result.add(collapsedRuns[index++]);
      continue;
    }

    result.addAll(collapsedRuns.sublist(index, index + repeatedLength));
    index += repeatedLength;
    while (index + repeatedLength <= collapsedRuns.length &&
        _rangesEqual(
          collapsedRuns,
          index - repeatedLength,
          index,
          repeatedLength,
        )) {
      index += repeatedLength;
    }
  }

  return String.fromCharCodes(result);
}

bool _rangesEqual(List<int> values, int first, int second, int length) {
  for (var offset = 0; offset < length; offset++) {
    if (values[first + offset] != values[second + offset]) return false;
  }
  return true;
}
