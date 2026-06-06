class AlignmentResult {
  const AlignmentResult({
    required this.index,
    required this.strategy,
    required this.matchedLength,
    required this.text,
    required this.isFinal,
  });

  final int index;
  final String strategy;
  final int matchedLength;
  final String text;
  final bool isFinal;
}

class TeleprompterAlignmentEngine {
  static final RegExp _cleanCharRegex = RegExp(r'[a-zA-Z0-9\u4e00-\u9fa5]');
  static const int _resyncWindow = 24;

  String _script = '';
  String _cleanScript = '';
  List<int> _indexMap = <int>[];
  int _anchorIndex = -1;
  int _currentIndex = -1;

  void setScript(String content) {
    _script = content;
    _cleanScript = '';
    _indexMap = <int>[];
    _anchorIndex = -1;
    _currentIndex = -1;
    for (var index = 0; index < content.length; index += 1) {
      final char = content[index];
      if (_cleanCharRegex.hasMatch(char)) {
        _cleanScript += char;
        _indexMap.add(index);
      }
    }
  }

  void reset() {
    _anchorIndex = -1;
    _currentIndex = -1;
  }

  void setCurrentIndex(int rawIndex) {
    if (rawIndex < 0) {
      reset();
      return;
    }
    var cleanIndex = _indexMap.indexWhere((value) => value >= rawIndex);
    if (cleanIndex < 0) {
      cleanIndex = _indexMap.length - 1;
    }
    _anchorIndex = cleanIndex;
    _currentIndex = cleanIndex;
  }

  int _toRawIndex(int cleanIndex) {
    if (cleanIndex < 0 || cleanIndex >= _indexMap.length) {
      return -1;
    }
    return _indexMap[cleanIndex];
  }

  String _normalizeTranscript(String text) {
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i += 1) {
      final char = text[i];
      if (_cleanCharRegex.hasMatch(char)) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  ({int matchedLength, int scriptAdvance, int transcriptAdvance}) _charMatch(
    int scriptStart,
    String transcript,
  ) {
    var scriptIndex = scriptStart;
    var transcriptIndex = 0;
    var lastMatchedScriptIndex = scriptStart - 1;
    var matchedLength = 0;

    while (scriptIndex < _cleanScript.length &&
        transcriptIndex < transcript.length) {
      final scriptChar = _cleanScript[scriptIndex];
      final transcriptChar = transcript[transcriptIndex];

      if (scriptChar == transcriptChar) {
        lastMatchedScriptIndex = scriptIndex;
        matchedLength += 1;
        scriptIndex += 1;
        transcriptIndex += 1;
        continue;
      }

      var aligned = false;
      for (var skip = 1; skip <= 3; skip += 1) {
        if (scriptIndex + skip >= _cleanScript.length) {
          break;
        }
        if (_cleanScript[scriptIndex + skip] == transcriptChar) {
          scriptIndex += skip;
          aligned = true;
          break;
        }
      }
      if (aligned) {
        continue;
      }

      for (var skip = 1; skip <= 3; skip += 1) {
        if (transcriptIndex + skip >= transcript.length) {
          break;
        }
        if (scriptChar == transcript[transcriptIndex + skip]) {
          transcriptIndex += skip;
          aligned = true;
          break;
        }
      }
      if (aligned) {
        continue;
      }

      scriptIndex += 1;
      transcriptIndex += 1;
    }

    return (
      matchedLength: matchedLength,
      scriptAdvance: lastMatchedScriptIndex < scriptStart
          ? 0
          : lastMatchedScriptIndex - scriptStart + 1,
      transcriptAdvance: transcriptIndex,
    );
  }

  ({
    ({int matchedLength, int scriptAdvance, int transcriptAdvance}) match,
    int offset,
  })
  _findBestMatch(int scriptStart, String transcript) {
    var bestMatch = _charMatch(scriptStart, transcript);
    var bestOffset = 0;

    if (bestMatch.matchedLength > 0) {
      return (match: bestMatch, offset: bestOffset);
    }

    final remaining = _cleanScript.length - scriptStart - 1;
    final maxOffset = remaining < _resyncWindow
        ? remaining.clamp(0, _resyncWindow)
        : _resyncWindow;

    for (var offset = 1; offset <= maxOffset; offset += 1) {
      final candidate = _charMatch(scriptStart + offset, transcript);
      if (candidate.matchedLength > bestMatch.matchedLength) {
        bestMatch = candidate;
        bestOffset = offset;
      }
      if (bestMatch.matchedLength >= 6) {
        break;
      }
    }

    return (match: bestMatch, offset: bestOffset);
  }

  AlignmentResult consumeTranscript(String text, {required bool isFinal}) {
    if (_script.isEmpty || _cleanScript.isEmpty) {
      return const AlignmentResult(
        index: -1,
        strategy: 'none',
        matchedLength: 0,
        text: '',
        isFinal: false,
      );
    }

    final cleanText = _normalizeTranscript(text);
    if (cleanText.isEmpty) {
      if (isFinal) {
        _anchorIndex = _currentIndex;
      }
      return AlignmentResult(
        index: _toRawIndex(_currentIndex),
        strategy: 'empty',
        matchedLength: 0,
        text: text,
        isFinal: isFinal,
      );
    }

    final anchorStart = _anchorIndex + 1 < 0 ? 0 : _anchorIndex + 1;
    final best = _findBestMatch(anchorStart, cleanText);
    if (best.match.matchedLength == 0) {
      if (isFinal) {
        _anchorIndex = _currentIndex;
      }
      return AlignmentResult(
        index: _toRawIndex(_currentIndex),
        strategy: 'none',
        matchedLength: 0,
        text: text,
        isFinal: isFinal,
      );
    }

    final resolvedAnchorStart = anchorStart + best.offset;
    final nextCurrentIndex = resolvedAnchorStart + best.match.scriptAdvance - 1;
    if (nextCurrentIndex > _currentIndex) {
      _currentIndex = nextCurrentIndex;
    }
    if (isFinal) {
      _anchorIndex = _currentIndex;
    }

    return AlignmentResult(
      index: _toRawIndex(_currentIndex),
      strategy: best.offset == 0 ? 'anchor' : 'char_resync',
      matchedLength: best.match.matchedLength,
      text: text,
      isFinal: isFinal,
    );
  }
}
