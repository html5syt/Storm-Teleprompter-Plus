part of 'editor_page.dart';

mixin EditorLogic on State<EditorPage> {
  late final TextEditingController titleController;
  late final TextEditingController contentController;
  late final quill.QuillController quillController;
  late ArticleProvider _articleProvider;

  Article? _savedArticle;
  Timer? _autosaveTimer;
  bool _syncingEditorContent = false;
  bool _saveQueued = false;

  bool isDirty = false;
  bool isSaving = false;

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
    quillController = quill.QuillController(
      document: quill.Document.fromDelta(
        _contentToDelta(widget.article?.content ?? ''),
      ),
      selection: const TextSelection.collapsed(offset: 0),
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
    quillController.dispose();
    super.dispose();
  }

  void _onQuillContentChanged() {
    if (_syncingEditorContent) return;

    final html = _deltaToStorageHtml(quillController.document.toDelta());
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
      try {
        final delta = HtmlToDelta().convert(content);
        if (delta.operations.isNotEmpty) return delta;
      } catch (e) {
        debugPrint('[Editor] HTML to Delta failed: $e');
      }
    }

    final normalized = content.endsWith('\n') ? content : '$content\n';
    return qd.Delta()..insert(normalized);
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
    final size = attributes['size'];
    if (background is String && background.isNotEmpty) {
      styles.add('background-color: $background');
    }
    if (size is String && size.isNotEmpty) {
      styles.add('font-size: ${_normalizeFontSize(size)}');
    }
    if (styles.isNotEmpty) {
      result = '<span style="${styles.join('; ')}">$result</span>';
    }

    return result;
  }

  String _normalizeFontSize(String value) {
    final parsed = double.tryParse(value);
    return parsed == null ? value : '${parsed.round()}px';
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
    final buffer = StringBuffer();
    var doubleOpen = true;
    var singleOpen = true;
    for (final codePoint in text.runes) {
      final char = String.fromCharCode(codePoint);
      if (char == '"') {
        buffer.write(doubleOpen ? '“' : '”');
        doubleOpen = !doubleOpen;
      } else if (char == "'") {
        buffer.write(singleOpen ? '‘' : '’');
        singleOpen = !singleOpen;
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }
}
