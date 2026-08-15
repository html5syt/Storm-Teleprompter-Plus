import 'dart:math';

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

String appendAsrTranscript(String committed, String segment) {
  if (committed.isEmpty) return segment;
  if (segment.isEmpty) return committed;
  final overlap = _suffixPrefixOverlap(committed.replaceAll('\n', ''), segment);
  final remainder = _dropRunes(segment, overlap).trimLeft();
  if (remainder.isEmpty) return committed;
  return '$committed\n$remainder';
}

String composeAsrDisplayText(String committed, String partial) {
  if (committed.isEmpty) return partial;
  if (partial.isEmpty) return committed;
  final overlap = _suffixPrefixOverlap(committed.replaceAll('\n', ''), partial);
  final remainder = _dropRunes(partial, overlap).trimLeft();
  return remainder.isEmpty ? committed : '$committed\n$remainder';
}

int _suffixPrefixOverlap(String committed, String incoming) {
  final left = committed.runes.toList(growable: false);
  final right = incoming.runes.toList(growable: false);
  final maximum = min(left.length, right.length);
  for (var length = maximum; length >= 1; length--) {
    var matches = true;
    for (var offset = 0; offset < length; offset++) {
      if (left[left.length - length + offset] != right[offset]) {
        matches = false;
        break;
      }
    }
    if (matches && (length > 1 || !_isAsciiLetterOrDigit(right.first))) {
      return length;
    }
  }
  return 0;
}

bool _isAsciiLetterOrDigit(int rune) =>
    (rune >= 0x30 && rune <= 0x39) ||
    (rune >= 0x41 && rune <= 0x5A) ||
    (rune >= 0x61 && rune <= 0x7A);

String _dropRunes(String text, int count) {
  if (count <= 0) return text;
  final runes = text.runes.toList(growable: false);
  return count >= runes.length ? '' : String.fromCharCodes(runes.skip(count));
}

bool _rangesEqual(List<int> values, int first, int second, int length) {
  for (var offset = 0; offset < length; offset++) {
    if (values[first + offset] != values[second + offset]) return false;
  }
  return true;
}
