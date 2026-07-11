part of 'editor_page.dart';

mixin EditorLogic on State<EditorPage> {
  late final TextEditingController titleController;
  late final TextEditingController contentController;
  late final TextEditingController findController;
  late final TextEditingController replaceController;
  late final quill.QuillController quillController;
  late final FocusNode editorFocusNode;
  late final FocusNode findFocusNode;
  late ArticleProvider _articleProvider;

  Article? _savedArticle;
  Timer? _autosaveTimer;
  bool _syncingEditorContent = false;
  bool _saveQueued = false;

  bool isDirty = false;
  bool isSaving = false;
  bool isFindReplaceVisible = false;
  bool isReplaceMode = false;
  String findReplaceStatus = '';

  Article? get currentArticle => _savedArticle;

  int get plainTextLength {
    final text = quillController.document.toPlainText().trim();
    return text.isEmpty ? 0 : text.length;
  }

  String get saveStatusText {
    if (isSaving) return '保存中';
    if (isDirty) return '等待自动保存';
    return _savedArticle == null ? '尚未保存' : '已保存';
  }

  @override
  void initState() {
    super.initState();
    _savedArticle = widget.article;
    titleController = TextEditingController(text: widget.article?.title ?? '');
    contentController = TextEditingController(
      text: widget.article?.content ?? '',
    );
    findController = TextEditingController();
    replaceController = TextEditingController();
    editorFocusNode = FocusNode(debugLabel: 'ArticleEditor');
    findFocusNode = FocusNode(debugLabel: 'FindReplace');
    quillController = quill.QuillController(
      document: quill.Document.fromDelta(
        _contentToDelta(widget.article?.content ?? ''),
      ),
      selection: const TextSelection.collapsed(offset: 0),
      config: quill_config.QuillControllerConfig(
        // flutter_quill 目前仅通过实验 API 暴露自定义粘贴清理回调。
        // ignore: experimental_member_use
        clipboardConfig: quill_config.QuillClipboardConfig(
          // ignore: experimental_member_use
          onPlainTextPaste: (plainText) async => _cleanPastedText(plainText),
          // ignore: experimental_member_use
          onRichTextPaste: (delta, isExternal) async =>
              _cleanPastedDelta(delta),
        ),
      ),
    );

    titleController.addListener(_markChanged);
    quillController.addListener(_onQuillContentChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _articleProvider = context.read<ArticleProvider>();
  }

  @override
  void dispose() {
    flushAutosave();
    _autosaveTimer?.cancel();
    titleController.dispose();
    contentController.dispose();
    findController.dispose();
    replaceController.dispose();
    editorFocusNode.dispose();
    findFocusNode.dispose();
    quillController.dispose();
    super.dispose();
  }

  void _onQuillContentChanged() {
    if (_syncingEditorContent) return;

    final rawHtml = _deltaToStorageHtml(quillController.document.toDelta());
    final html = _sanitizeStorageHtml(rawHtml);
    if (html != rawHtml) {
      _replaceEditorHtml(html);
      return;
    }
    if (html == contentController.text) {
      if (mounted) setState(() {});
      return;
    }

    _syncingEditorContent = true;
    contentController.value = TextEditingValue(
      text: html,
      selection: TextSelection.collapsed(offset: html.length),
    );
    _syncingEditorContent = false;
    _markChanged();
  }

  void _markChanged() {
    if (!mounted) return;
    setState(() => isDirty = true);
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(
      const Duration(milliseconds: 700),
      () => unawaited(save()),
    );
  }

  void flushAutosave() {
    _autosaveTimer?.cancel();
    if (isDirty) unawaited(save());
  }

  Future<Article?> save({bool force = false}) async {
    if (!force && !isDirty) return _savedArticle;
    if (isSaving) {
      _saveQueued = true;
      return _savedArticle;
    }

    if (mounted) setState(() => isSaving = true);

    try {
      do {
        _saveQueued = false;
        final plainText = quillController.document.toPlainText().trim();
        final content = contentController.text.trim();
        if (plainText.isEmpty && titleController.text.trim().isEmpty) {
          return _savedArticle;
        }

        final title = _effectiveTitle(plainText);
        final article = _savedArticle;
        Article? savedArticle;
        if (article == null) {
          savedArticle = await _articleProvider.createArticle(
            title: title,
            content: content,
            folderId: widget.initialFolderId,
          );
        } else {
          savedArticle = await _articleProvider.updateArticle(
            article.id,
            title: title,
            content: content,
          );
        }

        if (savedArticle == null) {
          if (mounted) setState(() => isDirty = true);
          return _savedArticle;
        }
        _savedArticle = savedArticle;
      } while (_saveQueued);

      if (mounted) setState(() => isDirty = false);
      return _savedArticle;
    } catch (e) {
      debugPrint('[Editor] autosave failed: $e');
      return _savedArticle;
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  String _effectiveTitle(String plainText) {
    final explicit = titleController.text.trim();
    if (explicit.isNotEmpty) return explicit;
    final fallback = plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (fallback.isEmpty) return '无标题';
    return fallback.length > 30 ? fallback.substring(0, 30) : fallback;
  }

  Future<void> quickStartTeleprompter() async {
    final article = await save(force: true);
    if (!mounted) return;

    if (article == null || article.content.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入稿件正文')));
      return;
    }

    final teleprompterProvider = context.read<TeleprompterProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    settingsProvider.loadArticleOverrides(article.teleprompterSettings);
    teleprompterProvider.loadScript(article.id, article.content);
    final connection = context.read<ConnectionProvider>();
    if (connection.isLocal && connection.isConnected) {
      connection.send(
        WsMessage(
          type: WsMessageType.teleprompterStartSession,
          data: {
            'articleId': article.id,
            'currentIndex': teleprompterProvider.currentIndex,
            'isPlaying': teleprompterProvider.isPlaying,
            'article': article.toJson(),
            'settings': settingsProvider.mergedSettings.toTeleprompterMap(),
          },
        ),
      );
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: teleprompterProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: _articleProvider),
          ],
          child: TeleprompterPage(article: article),
        ),
      ),
    );
  }

  void removeEmptyLines() {
    final updated = contentController.text
        .replaceAll(RegExp(r'<p>\s*</p>\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'(\r?\n)\s*(\r?\n)+'), '\n')
        .trim();
    _replaceEditorHtml(updated);
  }

  void addParagraphIndentation() {
    _replaceEditorHtml(
      _mapParagraphs(contentController.text, (body) {
        final clean = _removeLeadingIndent(body);
        return clean.trim().isEmpty ? clean : '\u3000\u3000$clean';
      }),
    );
  }

  void removeParagraphIndentation() {
    _replaceEditorHtml(
      _mapParagraphs(contentController.text, _removeLeadingIndent),
    );
  }

  void normalizeQuotePairs() {
    _replaceEditorHtml(_mapTextOutsideTags(contentController.text, _quoteText));
  }

  void applyFontSize(String value) {
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed <= 0) return;
    quillController.formatSelection(
      quill.Attribute.fromKeyValue(quill.Attribute.size.key, parsed)!,
    );
    _onQuillContentChanged();
  }

  void showFindReplaceDialog({required bool replaceMode}) {
    setState(() {
      isFindReplaceVisible = true;
      isReplaceMode = replaceMode;
      findReplaceStatus = '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) findFocusNode.requestFocus();
    });
  }

  void closeFindReplaceBar() {
    setState(() {
      isFindReplaceVisible = false;
      findReplaceStatus = '';
    });
    editorFocusNode.requestFocus();
  }

  void findNextMatch() {
    final index = _findNext(findController.text);
    setState(() {
      findReplaceStatus = index >= 0 ? '已定位到匹配项' : '没有找到匹配项';
    });
  }

  void replaceCurrentMatch() {
    final replaced = _replaceCurrent(
      findController.text,
      replaceController.text,
    );
    setState(() {
      findReplaceStatus = replaced ? '已替换当前匹配项' : '没有可替换的匹配项';
    });
  }

  void replaceAllMatches() {
    final count = _replaceAll(findController.text, replaceController.text);
    setState(() {
      findReplaceStatus = count > 0 ? '已替换 $count 处' : '没有可替换的匹配项';
    });
  }

  int _findNext(String query) {
    if (query.isEmpty) return -1;
    final text = quillController.document.toPlainText();
    final selection = quillController.selection;
    final start = selection.isValid ? selection.extentOffset : 0;
    var index = text.indexOf(query, start.clamp(0, text.length));
    if (index < 0 && start > 0) index = text.indexOf(query);
    if (index >= 0) {
      quillController.updateSelection(
        TextSelection(baseOffset: index, extentOffset: index + query.length),
        quill.ChangeSource.local,
      );
      editorFocusNode.requestFocus();
    }
    return index;
  }

  bool _replaceCurrent(String query, String replacement) {
    if (query.isEmpty) return false;
    final selection = quillController.selection;
    final text = quillController.document.toPlainText();
    final selected = selection.isValid && !selection.isCollapsed
        ? text.substring(
            selection.start.clamp(0, text.length),
            selection.end.clamp(0, text.length),
          )
        : '';
    if (selected != query && _findNext(query) < 0) return false;
    final current = quillController.selection;
    quillController.replaceText(
      current.start,
      current.end - current.start,
      replacement,
      TextSelection.collapsed(offset: current.start + replacement.length),
    );
    _onQuillContentChanged();
    return true;
  }

  int _replaceAll(String query, String replacement) {
    if (query.isEmpty) return 0;
    final text = quillController.document.toPlainText();
    final matches = query.allMatches(text).toList(growable: false);
    if (matches.isEmpty) return 0;
    for (final match in matches.reversed) {
      quillController.replaceText(
        match.start,
        match.end - match.start,
        replacement,
        TextSelection.collapsed(offset: match.start + replacement.length),
      );
    }
    _onQuillContentChanged();
    return matches.length;
  }

  void _replaceEditorHtml(String html) {
    _syncingEditorContent = true;
    quillController.document = quill.Document.fromDelta(_contentToDelta(html));
    contentController.value = TextEditingValue(
      text: html,
      selection: TextSelection.collapsed(offset: html.length),
    );
    _syncingEditorContent = false;
    _markChanged();
  }

  qd.Delta _contentToDelta(String content) {
    if (content.trim().isEmpty) {
      return qd.Delta()..insert('\n');
    }

    if (TextParser.isHtml(content)) {
      final storageDelta = _storageHtmlToDelta(content);
      if (storageDelta.operations.isNotEmpty) return storageDelta;
      try {
        final delta = HtmlToDelta().convert(content);
        if (delta.operations.isNotEmpty) return _sanitizeEditorDelta(delta);
      } catch (e) {
        debugPrint('[Editor] HTML to Delta failed: $e');
      }
    }

    final normalized = content.endsWith('\n') ? content : '$content\n';
    return qd.Delta()..insert(normalized);
  }

  qd.Delta _storageHtmlToDelta(String html) {
    final delta = qd.Delta();
    final paragraphPattern = RegExp(
      r'<(?:p|div|h[1-6])[^>]*>(.*?)</(?:p|div|h[1-6])>',
      caseSensitive: false,
      dotAll: true,
    );
    final matches = paragraphPattern.allMatches(html).toList();
    if (matches.isEmpty) return delta;

    for (final match in matches) {
      _appendInlineHtmlToDelta(delta, match.group(1) ?? '');
      delta.insert('\n');
    }
    return delta;
  }

  void _appendInlineHtmlToDelta(qd.Delta delta, String html) {
    final attributes = <String, dynamic>{};
    var cursor = 0;
    for (final match in RegExp(r'<[^>]+>').allMatches(html)) {
      if (match.start > cursor) {
        _insertDeltaText(
          delta,
          html.substring(cursor, match.start),
          attributes,
        );
      }
      final tag = match.group(0) ?? '';
      _applyInlineTagToAttributes(tag, attributes);
      cursor = match.end;
    }
    if (cursor < html.length) {
      _insertDeltaText(delta, html.substring(cursor), attributes);
    }
  }

  void _insertDeltaText(
    qd.Delta delta,
    String text,
    Map<String, dynamic> attributes,
  ) {
    final normalized = _decodeHtml(text).replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    if (normalized.isEmpty) return;
    delta.insert(
      normalized,
      attributes.isEmpty ? null : Map<String, dynamic>.from(attributes),
    );
  }

  void _applyInlineTagToAttributes(
    String rawTag,
    Map<String, dynamic> attributes,
  ) {
    final tag = rawTag.toLowerCase();
    final isClosing = tag.startsWith('</');
    final nameMatch = RegExp(r'</?\s*([a-z0-9]+)').firstMatch(tag);
    final name = nameMatch?.group(1);
    if (name == null) return;

    switch (name) {
      case 'br':
        return;
      case 'b':
      case 'strong':
        isClosing ? attributes.remove('bold') : attributes['bold'] = true;
        return;
      case 'i':
      case 'em':
        isClosing ? attributes.remove('italic') : attributes['italic'] = true;
        return;
      case 'u':
        isClosing
            ? attributes.remove('underline')
            : attributes['underline'] = true;
        return;
      case 's':
      case 'strike':
      case 'del':
        isClosing ? attributes.remove('strike') : attributes['strike'] = true;
        return;
      case 'span':
        if (isClosing) {
          attributes.remove('background');
          attributes.remove('color');
          attributes.remove('size');
        } else {
          final style = RegExp(
            r'''style\s*=\s*["']([^"']+)["']''',
            caseSensitive: false,
          ).firstMatch(rawTag)?.group(1);
          if (style != null) {
            final background =
                InlineStyleParser.color(style, 'background-color') ??
                InlineStyleParser.color(style, 'background');
            final color = InlineStyleParser.color(style, 'color');
            final size = RegExp(
              r'font-size\s*:\s*([^;]+)',
              caseSensitive: false,
            ).firstMatch(style)?.group(1)?.trim();
            if (background != null) attributes['background'] = background;
            if (color != null) attributes['color'] = color;
            final parsedSize = _fontSizeAttributeValue(size);
            if (parsedSize != null) attributes['size'] = parsedSize;
          }
        }
    }
  }

  String _deltaToStorageHtml(qd.Delta delta) {
    final paragraphs = <String>[];
    final current = StringBuffer();

    for (final operation in delta.operations) {
      if (!operation.isInsert || operation.data is! String) continue;

      final attributes = operation.attributes ?? const <String, dynamic>{};
      final text = operation.data as String;
      final parts = text.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) {
          current.write(_formatInlineHtml(parts[i], attributes));
        }
        if (i < parts.length - 1) {
          paragraphs.add('<p>${current.toString()}</p>');
          current.clear();
        }
      }
    }

    if (current.isNotEmpty) paragraphs.add('<p>${current.toString()}</p>');
    return paragraphs.join('\n').trim();
  }

  String _formatInlineHtml(String text, Map<String, dynamic> attributes) {
    var result = const HtmlEscape(HtmlEscapeMode.element).convert(text);

    if (attributes['bold'] == true) result = '<b>$result</b>';
    if (attributes['italic'] == true) result = '<i>$result</i>';
    if (attributes['underline'] == true) result = '<u>$result</u>';
    if (attributes['strike'] == true) result = '<s>$result</s>';

    final styles = <String>[];
    final background = attributes['background'];
    final color = attributes['color'];
    final size = attributes['size'];
    if (background is String && background.isNotEmpty) {
      styles.add('background-color: $background');
    }
    if (color is String && color.isNotEmpty) {
      styles.add('color: $color');
    }
    if (size is num) {
      styles.add('font-size: ${_normalizeFontSize(size.toString())}');
    } else if (size is String && size.isNotEmpty) {
      styles.add('font-size: ${_normalizeFontSize(size)}');
    }
    if (styles.isNotEmpty) {
      result = '<span style="${styles.join('; ')}">$result</span>';
    }

    return result;
  }

  String _cleanPastedText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .where((line) => !_isSourceUrlLine(line))
        .join('\n');
  }

  qd.Delta _cleanPastedDelta(qd.Delta delta) {
    final cleaned = qd.Delta();
    for (final operation in delta.operations) {
      if (operation.isInsert && operation.data is String) {
        final text = _cleanPastedText(operation.data as String);
        if (text.isEmpty) continue;
        cleaned.insert(text, _sanitizeDeltaAttributes(operation.attributes));
      } else if (operation.isInsert) {
        cleaned.insert(
          operation.data,
          _sanitizeDeltaAttributes(operation.attributes),
        );
      } else {
        cleaned.push(operation);
      }
    }
    return cleaned;
  }

  String _sanitizeStorageHtml(String html) {
    final withoutParagraphs = html.replaceAll(
      RegExp(
        r'<p[^>]*>\s*(?:sourceurl|source url)\s*:?.*?</p>\s*',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );
    return withoutParagraphs
        .split(RegExp(r'\r?\n'))
        .where(
          (line) => !_isSourceUrlLine(line.replaceAll(RegExp(r'<[^>]+>'), '')),
        )
        .join('\n')
        .trim();
  }

  bool _isSourceUrlLine(String line) {
    return RegExp(
      r'^\s*(?:sourceurl|source\s+url)\s*:?.*$',
      caseSensitive: false,
    ).hasMatch(line.trim());
  }

  qd.Delta _sanitizeEditorDelta(qd.Delta delta) {
    final sanitized = qd.Delta();
    for (final operation in delta.operations) {
      if (operation.isInsert) {
        sanitized.insert(
          operation.data,
          _sanitizeDeltaAttributes(operation.attributes),
        );
      } else {
        sanitized.push(operation);
      }
    }
    return sanitized;
  }

  Map<String, dynamic>? _sanitizeDeltaAttributes(
    Map<String, dynamic>? attributes,
  ) {
    if (attributes == null || attributes.isEmpty) return attributes;
    final sanitized = Map<String, dynamic>.from(attributes);
    final size = sanitized['size'];
    if (size != null) {
      final normalized = size is num
          ? size.toDouble()
          : _fontSizeAttributeValue(size.toString());
      if (normalized == null || normalized <= 0) {
        sanitized.remove('size');
      } else {
        sanitized['size'] = normalized;
      }
    }
    return sanitized.isEmpty ? null : sanitized;
  }

  String _decodeHtml(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&');
  }

  String _normalizeFontSize(String value) {
    final trimmed = value.trim().toLowerCase();
    final match = RegExp(
      r'^(\d+(?:\.\d+)?)(px|pt|em|rem)?$',
    ).firstMatch(trimmed);
    if (match == null) return value;
    final parsed = double.tryParse(match.group(1) ?? '');
    if (parsed == null || parsed <= 0) return value;
    final unit = match.group(2) ?? 'px';
    final display = parsed.truncateToDouble() == parsed
        ? parsed.toStringAsFixed(0)
        : parsed.toStringAsFixed(1);
    return '$display$unit';
  }

  double? _fontSizeAttributeValue(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'small':
        return 13;
      case 'normal':
        return 16;
      case 'large':
        return 24;
      case 'huge':
        return 32;
    }

    final match = RegExp(
      r'^(\d+(?:\.\d+)?)(px|pt|em|rem)?$',
    ).firstMatch(normalized);
    if (match == null) return null;
    final number = double.tryParse(match.group(1) ?? '');
    if (number == null || number <= 0) return null;
    final unit = match.group(2);
    if (unit == 'pt') return number * 96 / 72;
    if (unit == 'em' || unit == 'rem') return number * 16;
    return number;
  }

  String _mapParagraphs(String html, String Function(String body) mapper) {
    final pattern = RegExp(r'<p>(.*?)</p>', caseSensitive: false, dotAll: true);
    if (!pattern.hasMatch(html)) {
      return html.split('\n').map(mapper).join('\n');
    }
    return html.replaceAllMapped(
      pattern,
      (match) => '<p>${mapper(match.group(1) ?? '')}</p>',
    );
  }

  String _removeLeadingIndent(String text) {
    return text.replaceFirst(RegExp(r'^(?:\s|　|&nbsp;)+'), '');
  }

  String _mapTextOutsideTags(String html, String Function(String text) mapper) {
    final buffer = StringBuffer();
    var cursor = 0;
    for (final match in RegExp(r'<[^>]+>').allMatches(html)) {
      if (match.start > cursor) {
        buffer.write(mapper(html.substring(cursor, match.start)));
      }
      buffer.write(match.group(0));
      cursor = match.end;
    }
    if (cursor < html.length) buffer.write(mapper(html.substring(cursor)));
    return buffer.toString();
  }

  String _quoteText(String text) {
    final decoded = TextParser.decodeHtmlEntities(text);
    final normalized = TextParser.normalizeQuotePairs(decoded);
    return TextParser.encodeHtmlEntities(normalized);
  }
}
