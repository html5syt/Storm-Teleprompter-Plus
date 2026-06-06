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

  const AlignmentMeta({
    required this.strategy,
    this.matchedLength = 0,
    required this.text,
    required this.isFinal,
  });
}

/// 内部匹配结果
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

/// 带窗口偏移的匹配结果
class _WindowedMatchResult {
  final _MatchResult match;
  final int offset;

  const _WindowedMatchResult({required this.match, required this.offset});
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

  String _script = '';
  String _cleanScript = '';
  final List<int> _indexMap = [];
  int _anchorIndex = -1;
  int _currentIndex = -1;

  /// 设置原稿文本并构建干净文本和索引映射
  ///
  /// 只保留中文、英文、数字等有效字符，过滤标点。
  void setScript(String content) {
    _script = content;
    _cleanScript = '';
    _indexMap.clear();
    _anchorIndex = -1;
    _currentIndex = -1;

    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      if (_cleanCharRegex.hasMatch(char)) {
        _cleanScript += char;
        _indexMap.add(i);
      }
    }
  }

  /// 重置双指针到起始位置
  void reset() {
    _anchorIndex = -1;
    _currentIndex = -1;
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

  /// 干净文本索引 → 原稿索引
  int _toRawIndex(int cleanIndex) {
    if (cleanIndex < 0 || cleanIndex >= _indexMap.length) return -1;
    return _indexMap[cleanIndex];
  }

  /// 过滤 ASR 文本中的标点，只保留有效字符
  String _normalizeTranscript(String text) {
    return text.split('').where((c) => _cleanCharRegex.hasMatch(c)).join();
  }

  /// 字符级匹配（跳字容错）
  ///
  /// ASR 识别可能吞字或产生幻觉，允许双向最多跳过 3 个字符进行容错匹配。
  /// 优先跳原稿再跳 ASR，更符合实际 ASR 错误分布。
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

      // 尝试跳原稿（ASR 吞字容错）
      for (int skip = 1; skip <= 3; skip++) {
        if (scriptIndex + skip >= _cleanScript.length) break;
        if (_cleanScript[scriptIndex + skip] == transcriptChar) {
          scriptIndex += skip;
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
          aligned = true;
          break;
        }
      }
      if (aligned) continue;

      // 都不匹配，双方各进一步
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

  /// 带窗口搜索的最佳匹配
  _WindowedMatchResult _findBestMatch(int scriptStart, String transcript) {
    var bestMatch = _charLevelMatch(scriptStart, transcript);
    int bestOffset = 0;

    if (bestMatch.matchedLength > 0) {
      return _WindowedMatchResult(match: bestMatch, offset: bestOffset);
    }

    // 向前搜索窗口内更好的匹配
    final maxOffset = (24).clamp(
      0,
      (_cleanScript.length - scriptStart - 1).clamp(0, 999),
    );
    for (int offset = 1; offset <= maxOffset; offset++) {
      final candidate = _charLevelMatch(scriptStart + offset, transcript);
      if (candidate.matchedLength > bestMatch.matchedLength) {
        bestMatch = candidate;
        bestOffset = offset;
      }
      if (bestMatch.matchedLength >= (6).clamp(0, transcript.length)) break;
    }

    return _WindowedMatchResult(match: bestMatch, offset: bestOffset);
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

    final anchorStart = (_anchorIndex + 1).clamp(0, _cleanScript.length);
    final windowResult = _findBestMatch(anchorStart, cleanText);

    if (windowResult.match.matchedLength == 0) {
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

    // 游标只前进不后退
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

  /// 获取当前干净文本长度
  int get cleanLength => _cleanScript.length;

  /// 获取当前索引
  int get currentIndex => _currentIndex;
}
