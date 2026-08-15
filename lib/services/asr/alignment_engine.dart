class AlignmentResult {
  final int index;

  final String targetId;

  final AlignmentMeta meta;

  const AlignmentResult({
    required this.index,
    required this.targetId,
    required this.meta,
  });
}

class AlignmentMeta {
  final String strategy; 

  final int matchedLength;

  final String text;

  final bool isFinal;

  final bool allowBackward;

  const AlignmentMeta({
    required this.strategy,
    this.matchedLength = 0,
    required this.text,
    required this.isFinal,
    this.allowBackward = false,
  });
}

class _MatchResult {
  final int matchedLength;
  final int scriptAdvance;
  final int transcriptAdvance;

  const _MatchResult({
    required this.matchedLength,
    required this.scriptAdvance,
    required this.transcriptAdvance,
  });
}

class _WindowedMatchResult {
  final _MatchResult match;
  final int offset;

  const _WindowedMatchResult({required this.match, required this.offset});
}

class TeleprompterAlignment {
  static final RegExp _cleanCharRegex = RegExp(r'[a-zA-Z0-9\u4e00-\u9fa5]');
  static final RegExp _latinOnlyRegex = RegExp(r'^[a-z0-9]+$');
  static const int _forwardSearchWindow = 64;
  static const int _backwardSearchWindow = 240;

  String _script = '';
  String _cleanScript = '';
  final List<int> _indexMap = [];
  int _anchorIndex = -1;
  int _currentIndex = -1;

  void setScript(String content) {
    _script = content;
    _cleanScript = '';
    _indexMap.clear();
    _anchorIndex = -1;
    _currentIndex = -1;

    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      if (_cleanCharRegex.hasMatch(char)) {
        _cleanScript += _foldLatinCase(char);
        _indexMap.add(i);
      }
    }
  }

  void reset() {
    _anchorIndex = -1;
    _currentIndex = -1;
  }

  void setCurrentIndex(int rawIndex) {
    if (rawIndex < 0) {
      _anchorIndex = -1;
      _currentIndex = -1;
      return;
    }

    int cleanIndex = -1;
    for (int i = 0; i < _indexMap.length; i++) {
      if (_indexMap[i] >= rawIndex) {
        cleanIndex = i;
        break;
      }
    }

    if (cleanIndex == -1) {
      cleanIndex = _indexMap.length - 1;
    }

    _anchorIndex = cleanIndex;
    _currentIndex = cleanIndex;
  }

  int _toRawIndex(int cleanIndex) {
    if (cleanIndex < 0 || cleanIndex >= _indexMap.length) return -1;
    return _indexMap[cleanIndex];
  }

  String _normalizeTranscript(String text) {
    return text
        .split('')
        .where((c) => _cleanCharRegex.hasMatch(c))
        .map(_foldLatinCase)
        .join();
  }

  String _foldLatinCase(String char) {
    final code = char.codeUnitAt(0);
    return code >= 65 && code <= 90 ? String.fromCharCode(code + 32) : char;
  }

  _MatchResult _charLevelMatch(int scriptStart, String transcript) {
    int scriptIndex = scriptStart;
    int transcriptIndex = 0;
    int lastMatchedScriptIndex = scriptStart - 1;
    int matchedLength = 0;

    while (scriptIndex < _cleanScript.length &&
        transcriptIndex < transcript.length) {
      final scriptChar = _cleanScript[scriptIndex];
      final transcriptChar = transcript[transcriptIndex];

      if (scriptChar == transcriptChar) {
        lastMatchedScriptIndex = scriptIndex;
        matchedLength++;
        scriptIndex++;
        transcriptIndex++;
        continue;
      }

      bool aligned = false;

      for (int skip = 1; skip <= 3; skip++) {
        if (scriptIndex + skip >= _cleanScript.length) break;
        if (_cleanScript[scriptIndex + skip] == transcriptChar) {
          scriptIndex += skip;
          aligned = true;
          break;
        }
      }
      if (aligned) continue;

      for (int skip = 1; skip <= 3; skip++) {
        if (transcriptIndex + skip >= transcript.length) break;
        if (scriptChar == transcript[transcriptIndex + skip]) {
          transcriptIndex += skip;
          aligned = true;
          break;
        }
      }
      if (aligned) continue;

      scriptIndex++;
      transcriptIndex++;
    }

    return _MatchResult(
      matchedLength: matchedLength,
      scriptAdvance: (lastMatchedScriptIndex - scriptStart + 1).clamp(
        0,
        _cleanScript.length,
      ),
      transcriptAdvance: transcriptIndex,
    );
  }

  _WindowedMatchResult _findBestMatch(int scriptStart, String transcript) {
    var bestMatch = _charLevelMatch(scriptStart, transcript);
    int bestOffset = 0;

    final maxOffset = (_forwardSearchWindow).clamp(
      0,
      (_cleanScript.length - scriptStart - 1).clamp(0, 999),
    );
    for (int offset = 1; offset <= maxOffset; offset++) {
      final candidate = _charLevelMatch(scriptStart + offset, transcript);
      if (_isBetterMatch(candidate, offset, bestMatch, bestOffset)) {
        bestMatch = candidate;
        bestOffset = offset;
      }
    }

    return _WindowedMatchResult(match: bestMatch, offset: bestOffset);
  }

  bool _isBetterMatch(
    _MatchResult candidate,
    int candidateOffset,
    _MatchResult current,
    int currentOffset,
  ) {
    if (candidate.matchedLength != current.matchedLength) {
      return candidate.matchedLength > current.matchedLength;
    }
    if (candidate.scriptAdvance != current.scriptAdvance) {
      return candidate.scriptAdvance < current.scriptAdvance;
    }
    return candidateOffset < currentOffset;
  }

  bool _hasEnoughConfidence(String transcript, _MatchResult match) {
    if (match.matchedLength == 0) return false;
    if (_latinOnlyRegex.hasMatch(transcript)) {
      final minimum = transcript.length < 3 ? transcript.length : 3;
      return transcript.length >= 3 &&
          match.matchedLength >= minimum &&
          match.matchedLength / transcript.length >= 0.55;
    }
    final minimum = transcript.length >= 4 ? 2 : 1;
    return match.matchedLength >= minimum;
  }

  int? _confirmedBackwardIndex(String transcript) {
    if (_currentIndex < 0) return null;
    final latinOnly = _latinOnlyRegex.hasMatch(transcript);
    final minimumLength = latinOnly ? 12 : 8;
    if (transcript.length < minimumLength) return null;

    final searchStart = (_currentIndex - _backwardSearchWindow).clamp(
      0,
      _cleanScript.length,
    );
    final candidateStart = _cleanScript.lastIndexOf(transcript, _currentIndex);
    if (candidateStart < searchStart) return null;
    final candidateEnd = candidateStart + transcript.length - 1;
    return candidateEnd < _currentIndex ? candidateEnd : null;
  }

  AlignmentResult consumeTranscript(String text, bool isFinal) {
    if (_script.isEmpty || _cleanScript.isEmpty) {
      return AlignmentResult(
        index: -1,
        targetId: 'word_-1',
        meta: AlignmentMeta(strategy: 'none', text: text, isFinal: isFinal),
      );
    }

    final cleanText = _normalizeTranscript(text);
    if (cleanText.isEmpty) {
      final rawIndex = _toRawIndex(_currentIndex);
      if (isFinal) _anchorIndex = _currentIndex;
      return AlignmentResult(
        index: rawIndex,
        targetId: 'word_$rawIndex',
        meta: AlignmentMeta(strategy: 'empty', text: text, isFinal: isFinal),
      );
    }

    final backwardIndex = _confirmedBackwardIndex(cleanText);
    if (backwardIndex != null) {
      _currentIndex = backwardIndex;
      _anchorIndex = backwardIndex - cleanText.length;
      if (isFinal) _anchorIndex = _currentIndex;
      final rawIndex = _toRawIndex(_currentIndex);
      return AlignmentResult(
        index: rawIndex,
        targetId: 'word_$rawIndex',
        meta: AlignmentMeta(
          strategy: 'backward_resync',
          matchedLength: cleanText.length,
          text: text,
          isFinal: isFinal,
          allowBackward: true,
        ),
      );
    }

    final anchorStart = (_anchorIndex + 1).clamp(0, _cleanScript.length);
    final windowResult = _findBestMatch(anchorStart, cleanText);

    if (!_hasEnoughConfidence(cleanText, windowResult.match)) {
      final rawIndex = _toRawIndex(_currentIndex);
      if (isFinal) _anchorIndex = _currentIndex;
      return AlignmentResult(
        index: rawIndex,
        targetId: 'word_$rawIndex',
        meta: AlignmentMeta(strategy: 'none', text: text, isFinal: isFinal),
      );
    }

    final resolvedAnchorStart = anchorStart + windowResult.offset;
    final nextCurrentIndex =
        (resolvedAnchorStart + windowResult.match.scriptAdvance - 1).clamp(
          0,
          _cleanScript.length - 1,
        );

    _currentIndex = _currentIndex > nextCurrentIndex
        ? _currentIndex
        : nextCurrentIndex;

    if (isFinal) _anchorIndex = _currentIndex;

    final rawIndex = _toRawIndex(_currentIndex);
    final strategy = (anchorStart == 0 && windowResult.offset == 0)
        ? 'anchor'
        : 'char_resync';

    return AlignmentResult(
      index: rawIndex,
      targetId: 'word_$rawIndex',
      meta: AlignmentMeta(
        strategy: strategy,
        matchedLength: windowResult.match.matchedLength,
        text: text,
        isFinal: isFinal,
      ),
    );
  }

  int get cleanLength => _cleanScript.length;

  int get currentIndex => _currentIndex;
}
