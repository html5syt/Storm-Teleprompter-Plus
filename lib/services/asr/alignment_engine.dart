/// 对齐引擎匹配结果
class AlignmentResult {
  /// 匹配到的原稿字符索引
  final int index;

  /// 匹配目标元素 ID（用于 DOM/Widget 查找）
  final String targetId;

  /// 元数据
  final AlignmentMeta meta;

  const AlignmentResult({
    required this.index,
    required this.targetId,
    required this.meta,
  });
}

/// 对齐元数据
class AlignmentMeta {
  /// 匹配策略
  final String strategy; // 'none' | 'anchor' | 'char_resync' | 'empty'

  /// 匹配字符数
  final int matchedLength;

  /// ASR 原始文本
  final String text;

  /// 是否为最终结果
  final bool isFinal;

  /// 是否为较长片段确认后的回读定位
  final bool allowBackward;

  const AlignmentMeta({
    required this.strategy,
    this.matchedLength = 0,
    required this.text,
    required this.isFinal,
    this.allowBackward = false,
  });
}

/// 内部匹配结果
class _MatchResult {
  final int matchedLength;
  final int scriptAdvance;
  final int transcriptAdvance;
  final int leadingScriptSkips;
  final int longestContiguousMatch;

  const _MatchResult({
    required this.matchedLength,
    required this.scriptAdvance,
    required this.transcriptAdvance,
    required this.leadingScriptSkips,
    required this.longestContiguousMatch,
  });
}

/// 带窗口偏移的匹配结果
class _WindowedMatchResult {
  final _MatchResult match;
  final int offset;

  const _WindowedMatchResult({required this.match, required this.offset});
}

class _SearchBounds {
  final int start;
  final int end;

  const _SearchBounds({required this.start, required this.end});
}

/// 提词器对齐引擎
///
/// 核心算法：双指针字符级匹配，支持 ASR 吞字和幻觉容错。
/// 直接从原始 TypeScript 实现移植。
///
/// 算法原理：
/// - anchorIndex：已确认匹配完成的最后位置（稳定锚点）
/// - currentIndex：当前最佳匹配位置（实时游标）
/// - 非 final 结果：始终从 anchorIndex 重算，不移动锚点
/// - final 结果：提交锚点 anchorIndex = currentIndex
/// - 游标只前进不后退
class TeleprompterAlignment {
  static final RegExp _cleanCharRegex = RegExp(r'[a-zA-Z0-9\u4e00-\u9fa5]');
  static final RegExp _latinOnlyRegex = RegExp(r'^[a-z0-9]+$');
  static const int _backwardSearchWindow = 240;
  static const int _surroundingSearchLines = 2;
  static const int _maxRepeatedTextResyncOffset = 8;
  static const int _maxRepeatedTextLeadingSkips = 3;

  String _script = '';
  String _cleanScript = '';
  final List<int> _indexMap = [];
  final List<int> _cleanLineIndices = [];
  final List<int> _firstCleanIndexByLine = [];
  final List<int> _lastCleanIndexByLine = [];
  int _anchorIndex = -1;
  int _currentIndex = -1;
  int? _searchBackwardSpan;
  int? _searchForwardSpan;
  int? _searchReferenceIndex;

  /// 设置原稿文本并构建干净文本和索引映射
  ///
  /// 只保留中文、英文、数字等有效字符，过滤标点。
  void setScript(String content, {List<int>? rawIndexMap}) {
    if (rawIndexMap != null && rawIndexMap.length != content.length) {
      throw ArgumentError.value(
        rawIndexMap.length,
        'rawIndexMap.length',
        'must match content.length',
      );
    }

    _script = content;
    _cleanScript = '';
    _indexMap.clear();
    _cleanLineIndices.clear();
    _firstCleanIndexByLine
      ..clear()
      ..add(-1);
    _lastCleanIndexByLine
      ..clear()
      ..add(-1);
    _anchorIndex = -1;
    _currentIndex = -1;
    _clearSearchWindow();

    var lineIndex = 0;
    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      if (char == '\n') {
        lineIndex++;
        _firstCleanIndexByLine.add(-1);
        _lastCleanIndexByLine.add(-1);
        continue;
      }
      if (_cleanCharRegex.hasMatch(char)) {
        _cleanScript += _foldLatinCase(char);
        final cleanIndex = _indexMap.length;
        _indexMap.add(rawIndexMap?[i] ?? i);
        _cleanLineIndices.add(lineIndex);
        if (_firstCleanIndexByLine[lineIndex] == -1) {
          _firstCleanIndexByLine[lineIndex] = cleanIndex;
        }
        _lastCleanIndexByLine[lineIndex] = cleanIndex;
      }
    }
  }

  /// 重置双指针到起始位置
  void reset() {
    _anchorIndex = -1;
    _currentIndex = -1;
    _clearSearchWindow();
  }

  /// 手动设置当前索引（跳转时同步覆盖锚点）
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

  /// 设置由界面层在识别开始前计算出的原稿索引范围。
  ///
  /// 后端将该范围转换为相对当前字的前后跨度，并在本地随锚点平移。
  /// 这样无需在识别过程中重新测量客户端排版或同步范围。
  void setSearchWindow(int startRawIndex, int endRawIndex) {
    if (startRawIndex < 0 || endRawIndex < startRawIndex) {
      _clearSearchWindow();
      return;
    }

    final start = _firstCleanIndexAtOrAfterRaw(startRawIndex);
    final end = _lastCleanIndexAtOrBeforeRaw(endRawIndex);
    if (start == null || end == null || start > end) {
      _clearSearchWindow();
      return;
    }

    final reference = (_currentIndex >= 0 ? _currentIndex : start)
        .clamp(start, end)
        .toInt();
    _searchBackwardSpan = reference - start;
    _searchForwardSpan = end - reference;
    _searchReferenceIndex = reference;
  }

  void _clearSearchWindow() {
    _searchBackwardSpan = null;
    _searchForwardSpan = null;
    _searchReferenceIndex = null;
  }

  /// 干净文本索引 → 原稿索引
  int _toRawIndex(int cleanIndex) {
    if (cleanIndex < 0 || cleanIndex >= _indexMap.length) return -1;
    return _indexMap[cleanIndex];
  }

  int? _firstCleanIndexAtOrAfterRaw(int rawIndex) {
    var low = 0;
    var high = _indexMap.length - 1;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      if (_indexMap[middle] < rawIndex) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return low < _indexMap.length ? low : null;
  }

  int? _lastCleanIndexAtOrBeforeRaw(int rawIndex) {
    var low = 0;
    var high = _indexMap.length - 1;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      if (_indexMap[middle] <= rawIndex) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return high >= 0 ? high : null;
  }

  _SearchBounds _searchBoundsFor(int referenceIndex) {
    final backwardSpan = _searchBackwardSpan;
    final forwardSpan = _searchForwardSpan;
    if (backwardSpan != null && forwardSpan != null) {
      final explicitReference = referenceIndex >= 0
          ? referenceIndex
          : (_searchReferenceIndex ?? 0);
      final safeReference = explicitReference
          .clamp(0, _cleanScript.length - 1)
          .toInt();
      return _SearchBounds(
        start: (safeReference - backwardSpan)
            .clamp(0, _cleanScript.length - 1)
            .toInt(),
        end: (safeReference + forwardSpan)
            .clamp(0, _cleanScript.length - 1)
            .toInt(),
      );
    }

    final safeReference = referenceIndex
        .clamp(0, _cleanScript.length - 1)
        .toInt();
    final currentLine = _cleanLineIndices[safeReference];
    final firstLine = (currentLine - _surroundingSearchLines)
        .clamp(0, _firstCleanIndexByLine.length - 1)
        .toInt();
    final lastLine = (currentLine + _surroundingSearchLines)
        .clamp(0, _lastCleanIndexByLine.length - 1)
        .toInt();

    var start = -1;
    for (var line = firstLine; line <= lastLine; line++) {
      if (_firstCleanIndexByLine[line] >= 0) {
        start = _firstCleanIndexByLine[line];
        break;
      }
    }
    var end = -1;
    for (var line = lastLine; line >= firstLine; line--) {
      if (_lastCleanIndexByLine[line] >= 0) {
        end = _lastCleanIndexByLine[line];
        break;
      }
    }

    if (start < 0 || end < start) {
      return _SearchBounds(start: safeReference, end: safeReference);
    }
    return _SearchBounds(start: start, end: end);
  }

  /// 过滤 ASR 文本中的标点，只保留有效字符
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

  /// 字符级匹配（跳字容错）
  ///
  /// ASR 识别可能吞字或产生幻觉，允许双向最多跳过 3 个字符进行容错匹配。
  /// 优先跳原稿再跳 ASR，更符合实际 ASR 错误分布。
  _MatchResult _charLevelMatch(
    int scriptStart,
    String transcript,
    int scriptEnd,
  ) {
    int scriptIndex = scriptStart;
    int transcriptIndex = 0;
    int lastMatchedScriptIndex = scriptStart - 1;
    int firstMatchedScriptIndex = -1;
    int matchedLength = 0;
    int contiguousMatchLength = 0;
    int longestContiguousMatch = 0;

    while (scriptIndex <= scriptEnd && transcriptIndex < transcript.length) {
      final scriptChar = _cleanScript[scriptIndex];
      final transcriptChar = transcript[transcriptIndex];

      if (scriptChar == transcriptChar) {
        if (firstMatchedScriptIndex == -1) {
          firstMatchedScriptIndex = scriptIndex;
        }
        lastMatchedScriptIndex = scriptIndex;
        matchedLength++;
        contiguousMatchLength++;
        if (contiguousMatchLength > longestContiguousMatch) {
          longestContiguousMatch = contiguousMatchLength;
        }
        scriptIndex++;
        transcriptIndex++;
        continue;
      }

      bool aligned = false;

      // 尝试跳原稿（ASR 吞字容错）
      for (int skip = 1; skip <= 3; skip++) {
        if (scriptIndex + skip > scriptEnd) break;
        if (_cleanScript[scriptIndex + skip] == transcriptChar) {
          scriptIndex += skip;
          contiguousMatchLength = 0;
          aligned = true;
          break;
        }
      }
      if (aligned) continue;

      // 尝试跳 ASR（ASR 幻觉容错）
      for (int skip = 1; skip <= 3; skip++) {
        if (transcriptIndex + skip >= transcript.length) break;
        if (scriptChar == transcript[transcriptIndex + skip]) {
          transcriptIndex += skip;
          contiguousMatchLength = 0;
          aligned = true;
          break;
        }
      }
      if (aligned) continue;

      // 都不匹配，双方各进一步
      scriptIndex++;
      transcriptIndex++;
      contiguousMatchLength = 0;
    }

    return _MatchResult(
      matchedLength: matchedLength,
      scriptAdvance: (lastMatchedScriptIndex - scriptStart + 1).clamp(
        0,
        scriptEnd - scriptStart + 1,
      ),
      transcriptAdvance: transcriptIndex,
      leadingScriptSkips: firstMatchedScriptIndex == -1
          ? scriptEnd - scriptStart + 1
          : firstMatchedScriptIndex - scriptStart,
      longestContiguousMatch: longestContiguousMatch,
    );
  }

  /// 带窗口搜索的最佳匹配
  _WindowedMatchResult _findBestMatch(
    int scriptStart,
    int scriptEnd,
    String transcript,
    bool denseRepeatedText,
  ) {
    var bestMatch = _charLevelMatch(scriptStart, transcript, scriptEnd);
    int bestOffset = 0;
    var bestMatchIsEligible =
        !denseRepeatedText || _isRepeatedTextCandidateEligible(bestMatch, 0);

    final maxOffset = scriptEnd - scriptStart;
    for (int offset = 1; offset <= maxOffset; offset++) {
      final candidate = _charLevelMatch(
        scriptStart + offset,
        transcript,
        scriptEnd,
      );
      final candidateIsEligible =
          !denseRepeatedText ||
          _isRepeatedTextCandidateEligible(candidate, offset);
      if (candidateIsEligible &&
          (!bestMatchIsEligible ||
              _isBetterMatch(
                candidate,
                offset,
                bestMatch,
                bestOffset,
                denseRepeatedText,
              ))) {
        bestMatch = candidate;
        bestOffset = offset;
        bestMatchIsEligible = true;
      }
    }

    return _WindowedMatchResult(match: bestMatch, offset: bestOffset);
  }

  bool _isBetterMatch(
    _MatchResult candidate,
    int candidateOffset,
    _MatchResult current,
    int currentOffset,
    bool denseRepeatedText,
  ) {
    if (denseRepeatedText) {
      if (candidate.longestContiguousMatch != current.longestContiguousMatch) {
        return candidate.longestContiguousMatch >
            current.longestContiguousMatch;
      }
      if (candidate.leadingScriptSkips != current.leadingScriptSkips) {
        return candidate.leadingScriptSkips < current.leadingScriptSkips;
      }
      if (candidateOffset != currentOffset) {
        return candidateOffset < currentOffset;
      }
    }
    if (candidate.matchedLength != current.matchedLength) {
      return candidate.matchedLength > current.matchedLength;
    }
    if (candidate.scriptAdvance != current.scriptAdvance) {
      return candidate.scriptAdvance < current.scriptAdvance;
    }
    return candidateOffset < currentOffset;
  }

  bool _isRepeatedTextCandidateEligible(_MatchResult match, int offset) {
    return offset <= _maxRepeatedTextResyncOffset &&
        match.leadingScriptSkips <= _maxRepeatedTextLeadingSkips;
  }

  bool _hasEnoughConfidence(
    String transcript,
    _MatchResult match,
    bool denseRepeatedText,
  ) {
    if (match.matchedLength == 0) return false;
    if (denseRepeatedText) {
      if (transcript.length < 2) return false;
      final requiredRunLength = transcript.length >= 3 ? 2 : transcript.length;
      if (match.longestContiguousMatch < requiredRunLength) return false;
    }
    if (_latinOnlyRegex.hasMatch(transcript)) {
      final minimum = transcript.length < 3 ? transcript.length : 3;
      return transcript.length >= 3 &&
          match.matchedLength >= minimum &&
          match.matchedLength / transcript.length >= 0.55;
    }
    final minimum = transcript.length >= 4 ? 2 : 1;
    return match.matchedLength >= minimum;
  }

  bool _hasDenseRepeatedText(String transcript, _SearchBounds bounds) {
    final phraseLength = transcript.length < 3 ? transcript.length : 3;
    if (phraseLength == 0) return false;
    final phrase = transcript.substring(0, phraseLength);
    var occurrences = 0;
    final lastStart = bounds.end - phraseLength + 1;
    for (var index = bounds.start; index <= lastStart; index++) {
      if (_cleanScript.startsWith(phrase, index)) {
        occurrences++;
        if (occurrences >= 3) return true;
      }
    }
    return false;
  }

  int? _confirmedBackwardIndex(String transcript, _SearchBounds bounds) {
    if (_currentIndex < 0) return null;
    final latinOnly = _latinOnlyRegex.hasMatch(transcript);
    final minimumLength = latinOnly ? 12 : 8;
    if (transcript.length < minimumLength) return null;

    final searchStart = (_currentIndex - _backwardSearchWindow)
        .clamp(bounds.start, bounds.end)
        .toInt();
    final candidateStart = _cleanScript.lastIndexOf(transcript, _currentIndex);
    if (candidateStart < searchStart) return null;
    final candidateEnd = candidateStart + transcript.length - 1;
    return candidateEnd < _currentIndex && candidateEnd <= bounds.end
        ? candidateEnd
        : null;
  }

  /// 消费 ASR 转录文本，计算匹配位置
  ///
  /// [text] ASR 识别的文本
  /// [isFinal] 是否为最终结果（句子结束）
  /// 返回匹配到的原稿位置信息
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

    final referenceIndex = _currentIndex >= 0 ? _currentIndex : 0;
    final bounds = _searchBoundsFor(referenceIndex);
    final backwardIndex = _confirmedBackwardIndex(cleanText, bounds);
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

    final anchorStart = (_anchorIndex + 1)
        .clamp(0, _cleanScript.length)
        .toInt();
    if (anchorStart > bounds.end) {
      final rawIndex = _toRawIndex(_currentIndex);
      if (isFinal) _anchorIndex = _currentIndex;
      return AlignmentResult(
        index: rawIndex,
        targetId: 'word_$rawIndex',
        meta: AlignmentMeta(strategy: 'none', text: text, isFinal: isFinal),
      );
    }

    final searchStart = anchorStart < bounds.start ? bounds.start : anchorStart;
    final denseRepeatedText = _hasDenseRepeatedText(cleanText, bounds);
    final windowResult = _findBestMatch(
      searchStart,
      bounds.end,
      cleanText,
      denseRepeatedText,
    );

    if (!_hasEnoughConfidence(
      cleanText,
      windowResult.match,
      denseRepeatedText,
    )) {
      final rawIndex = _toRawIndex(_currentIndex);
      if (isFinal) _anchorIndex = _currentIndex;
      return AlignmentResult(
        index: rawIndex,
        targetId: 'word_$rawIndex',
        meta: AlignmentMeta(strategy: 'none', text: text, isFinal: isFinal),
      );
    }

    final resolvedAnchorStart = searchStart + windowResult.offset;
    final nextCurrentIndex =
        (resolvedAnchorStart + windowResult.match.scriptAdvance - 1).clamp(
          0,
          _cleanScript.length - 1,
        );

    // 游标只前进不后退
    _currentIndex = _currentIndex > nextCurrentIndex
        ? _currentIndex
        : nextCurrentIndex;

    if (isFinal) _anchorIndex = _currentIndex;

    final rawIndex = _toRawIndex(_currentIndex);
    final strategy = (searchStart == 0 && windowResult.offset == 0)
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

  /// 获取当前干净文本长度
  int get cleanLength => _cleanScript.length;

  /// 获取当前索引
  int get currentIndex => _currentIndex;
}
