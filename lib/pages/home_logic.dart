part of 'home_page.dart';

/// 内容项（文件夹或稿件）
class _ContentItem {
  final String id;
  final String name;
  final bool isFolder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Folder? folder;
  final Article? article;

  _ContentItem.folder(this.folder)
    : id = folder!.id,
      name = folder.name,
      isFolder = true,
      createdAt = folder.createdAt,
      updatedAt = folder.createdAt,
      article = null;

  _ContentItem.article(this.article)
    : id = article!.id,
      name = article.title.isEmpty ? '无标题' : article.title,
      isFolder = false,
      createdAt = article.createdAt,
      updatedAt = article.updatedAt,
      folder = null;
}

/// 剪贴板操作类型
enum _ClipboardOp { cut, copy }

/// 首页逻辑 mixin
mixin HomeLogic on State<HomePage> {
  void _showFabMenu(BuildContext context, ConnectionProvider connection);

  // ─── 搜索 ─────────────────────────────────────────────
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  final ImportService _importService = ImportService();
  final ExportService _exportService = ExportService();
  bool _isDraggingImport = false;
  bool _isImporting = false;

  // ─── 文件夹导航 ───────────────────────────────────────
  String? _currentFolderId;
  final List<String?> _history = [];
  int _historyIndex = -1;

  // ─── 选择 ─────────────────────────────────────────────
  final Set<String> _selectedItems = {};
  int _lastGridCrossAxisCount = 1;

  // ─── 框选 ─────────────────────────────────────────────
  Offset? _selectionStart;
  Offset? _selectionEnd;
  bool _isSelecting = false;
  int? _selectionPointer;
  bool _suppressNextGridSelection = false;
  bool _isItemDragActive = false;
  Timer? _itemHoldMenuTimer;
  Offset? _itemHoldStartPosition;
  final double _selectionDragThreshold = 6.0;

  // ─── 面包屑滚动 ──────────────────────────────────────
  final ScrollController _breadcrumbScrollController = ScrollController();

  // ─── 网格滚动（框选用） ──────────────────────────────
  final ScrollController _gridScrollController = ScrollController();

  // ─── 视图/排序 ────────────────────────────────────────
  ViewMode _viewMode = ViewMode.largeIcons;
  SortBy _sortBy = SortBy.name;
  bool _sortAscending = true;

  // ─── 剪贴板 ───────────────────────────────────────────
  final List<_ContentItem> _clipboard = [];
  _ClipboardOp _clipboardOp = _ClipboardOp.copy;

  StreamSubscription<WsMessage>? _startSessionSubscription;
  StreamSubscription<WsMessage>? _syncSubscription;
  StreamSubscription<WsMessage>? _settingsSubscription;
  StreamSubscription<WsMessage>? _endSessionSubscription;
  bool _remoteTeleprompterRouteActive = false;
  int _lastRemoteSessionRevision = -1;
  bool _remoteLoadingDialogVisible = false;

  @override
  void initState() {
    super.initState();
    _history.add(null); // 根目录
    _historyIndex = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ArticleProvider>().init();
      context.read<FolderProvider>().init();
      context.read<SettingsProvider>().init();
      _bindTeleprompterSession();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _gridScrollController.dispose();
    _breadcrumbScrollController.dispose();
    _itemHoldMenuTimer?.cancel();
    _startSessionSubscription?.cancel();
    _syncSubscription?.cancel();
    _settingsSubscription?.cancel();
    _endSessionSubscription?.cancel();
    super.dispose();
  }

  // ─── 搜索 ─────────────────────────────────────────────
  void _bindTeleprompterSession() {
    final connection = context.read<ConnectionProvider>();
    _startSessionSubscription = connection
        .listenTo(WsMessageType.teleprompterStartSession)
        .listen(_handleRemoteStartSession);
    _syncSubscription = connection
        .listenTo(WsMessageType.teleprompterSync)
        .listen(_handleRemoteSync);
    _settingsSubscription = connection
        .listenTo(WsMessageType.teleprompterSettingsUpdate)
        .listen(_handleRemoteSettingsUpdate);
    _endSessionSubscription = connection
        .listenTo(WsMessageType.teleprompterEndSession)
        .listen(_handleRemoteEndSession);
  }

  Future<void> _handleRemoteStartSession(WsMessage message) async {
    if (!mounted || !context.read<ConnectionProvider>().isRemote) return;
    _lastRemoteSessionRevision = _remoteSessionRevision(message) ?? -1;
    _showRemoteSessionLoading();
    try {
      await _openRemoteTeleprompterSession(message);
    } finally {
      _hideRemoteSessionLoading();
    }
  }

  void _showRemoteSessionLoading() {
    if (_remoteLoadingDialogVisible || !mounted) return;
    _remoteLoadingDialogVisible = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text('正在加载稿件'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('正在从服务端下载稿件数据...'),
                SizedBox(height: 16),
                LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      ).whenComplete(() => _remoteLoadingDialogVisible = false),
    );
  }

  void _hideRemoteSessionLoading() {
    if (!_remoteLoadingDialogVisible || !mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) navigator.pop();
    _remoteLoadingDialogVisible = false;
  }

  Future<void> _openRemoteTeleprompterSession(WsMessage message) async {
    final articleId = message.data['articleId'] as String?;
    if (articleId == null || articleId.isEmpty) return;

    final articleProvider = context.read<ArticleProvider>();
    final articleSnapshot = message.data['article'] as Map?;
    final Article? article;
    if (articleSnapshot != null) {
      article = Article.fromJson(Map<String, dynamic>.from(articleSnapshot));
      articleProvider.upsertArticle(article);
    } else {
      article = await articleProvider.getArticleById(
        articleId,
        forceRefresh: true,
      );
    }
    if (!mounted || article == null) return;

    final settingsOverride = Map<String, dynamic>.from(
      message.data['settings'] as Map? ?? const {},
    );
    final settingsProvider = context.read<SettingsProvider>();
    final teleprompterProvider = context.read<TeleprompterProvider>();

    settingsProvider.applyRemoteTeleprompterSettings(settingsOverride);
    teleprompterProvider.loadScript(article.id, article.content);
    teleprompterProvider.applyRemoteSync(
      currentIndex: (message.data['currentIndex'] as num?)?.toInt() ?? -1,
      isPlaying: message.data['isPlaying'] as bool? ?? false,
      settings: settingsProvider.mergedSettings,
    );

    final sessionArticle = article.copyWith(
      teleprompterSettings: settingsOverride,
    );
    _hideRemoteSessionLoading();
    await _showRemoteTeleprompter(sessionArticle);
  }

  Future<void> _showRemoteTeleprompter(Article article) async {
    if (!mounted) return;
    final navigator = Navigator.of(context);

    if (_remoteTeleprompterRouteActive) {
      if (navigator.canPop()) {
        navigator.pop();
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }

    _remoteTeleprompterRouteActive = true;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(
              value: context.read<TeleprompterProvider>(),
            ),
            ChangeNotifierProvider.value(
              value: context.read<SettingsProvider>(),
            ),
            ChangeNotifierProvider.value(
              value: context.read<ArticleProvider>(),
            ),
          ],
          child: TeleprompterPage(article: article),
        ),
      ),
    );
    if (!mounted) return;
    _remoteTeleprompterRouteActive = false;
  }

  Future<void> _handleRemoteSync(WsMessage message) async {
    if (!mounted || !context.read<ConnectionProvider>().isRemote) return;
    if (!_acceptRemoteSessionUpdate(message)) return;

    final articleId = message.data['articleId'] as String?;
    final teleprompterProvider = context.read<TeleprompterProvider>();
    if (articleId != null &&
        articleId.isNotEmpty &&
        teleprompterProvider.articleId != articleId) {
      _showRemoteSessionLoading();
      try {
        await _openRemoteTeleprompterSession(message);
      } finally {
        _hideRemoteSessionLoading();
      }
      return;
    }

    teleprompterProvider.applyRemoteSync(
      currentIndex: (message.data['currentIndex'] as num?)?.toInt() ?? -1,
      isPlaying: message.data['isPlaying'] as bool? ?? false,
      settings: context.read<SettingsProvider>().mergedSettings,
    );
  }

  void _handleRemoteSettingsUpdate(WsMessage message) {
    if (!mounted || !context.read<ConnectionProvider>().isRemote) return;
    if (!_acceptRemoteSessionUpdate(message)) return;
    final settings = Map<String, dynamic>.from(
      message.data['settings'] as Map? ?? const {},
    );
    context.read<SettingsProvider>().applyRemoteSyncedRuntimeSettings(settings);
  }

  void _handleRemoteEndSession(WsMessage message) {
    if (!mounted || !context.read<ConnectionProvider>().isRemote) return;
    if (!_acceptRemoteSessionUpdate(message)) return;
    context.read<TeleprompterProvider>().stopAll();
    context.read<SettingsProvider>().clearArticleOverrides();
    if (_remoteTeleprompterRouteActive && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    _remoteTeleprompterRouteActive = false;
    _lastRemoteSessionRevision = -1;
  }

  int? _remoteSessionRevision(WsMessage message) {
    return (message.data['revision'] as num?)?.toInt();
  }

  bool _acceptRemoteSessionUpdate(WsMessage message) {
    final revision = _remoteSessionRevision(message);
    if (revision == null) return true;
    if (revision <= _lastRemoteSessionRevision) return false;
    _lastRemoteSessionRevision = revision;
    return true;
  }

  void onSearchChanged(String value) => setState(() => searchQuery = value);
  void clearSearch() {
    searchController.clear();
    setState(() => searchQuery = '');
  }

  // ─── 排序 ─────────────────────────────────────────────
  Set<String> _descendantFolderIds(String? rootId, List<Folder> folders) {
    final childrenByParent = <String?, List<Folder>>{};
    for (final folder in folders) {
      childrenByParent.putIfAbsent(folder.parentId, () => []).add(folder);
    }

    final result = <String>{};
    final pending = List<Folder>.from(
      childrenByParent[rootId] ?? const <Folder>[],
    );
    while (pending.isNotEmpty) {
      final folder = pending.removeLast();
      if (result.add(folder.id)) {
        pending.addAll(childrenByParent[folder.id] ?? const <Folder>[]);
      }
    }
    return result;
  }

  void _handleImportDragEntered(DropEventDetails details) {
    if (_isImporting) return;
    setState(() => _isDraggingImport = true);
  }

  void _handleImportDragExited(DropEventDetails details) {
    if (_isImporting) return;
    setState(() => _isDraggingImport = false);
  }

  Future<void> _handleImportDrop(DropDoneDetails details) async {
    final paths = details.files
        .map((file) => file.path)
        .where((path) => path.isNotEmpty)
        .toList();
    if (paths.isEmpty) {
      setState(() => _isDraggingImport = false);
      return;
    }
    await _importDroppedFiles(paths);
  }

  Future<void> _importDroppedFiles(List<String> paths) async {
    if (context.read<ConnectionProvider>().isRemote) {
      setState(() {
        _isDraggingImport = false;
        _isImporting = false;
      });
      _showImportSnackBar('远程模式下不能导入本机文件');
      return;
    }

    setState(() {
      _isDraggingImport = false;
      _isImporting = true;
    });

    final articleProvider = context.read<ArticleProvider>();
    var importedCount = 0;
    final errors = <String>[];

    for (final path in paths) {
      try {
        final draft = await _importService.importFile(path);
        if (draft == null) {
          errors.add('${_fileName(path)}: 不支持的文件格式');
          continue;
        }
        final article = await articleProvider.createArticle(
          title: draft.title.isEmpty ? '未命名稿件' : draft.title,
          content: draft.content,
          folderId: _currentFolderId,
        );
        if (article == null) {
          errors.add('${_fileName(path)}: 创建失败');
        } else {
          importedCount++;
        }
      } catch (error) {
        errors.add('${_fileName(path)}: $error');
      }
    }

    if (!mounted) return;
    setState(() => _isImporting = false);

    if (importedCount > 0 && errors.isEmpty) {
      _showImportSnackBar('已导入 $importedCount 篇稿件');
    } else if (importedCount > 0) {
      _showImportSnackBar('已导入 $importedCount 篇稿件，${errors.length} 个文件失败');
    } else if (errors.isNotEmpty) {
      _showImportSnackBar(errors.take(2).join('\n'));
    } else {
      _showImportSnackBar('没有可导入的文件');
    }
  }

  Future<void> _importFromMenu() async {
    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(label: '稿件文件', extensions: ['txt', 'docx']),
      ],
    );
    if (files.isEmpty) return;
    await _importDroppedFiles(files.map((file) => file.path).toList());
  }

  Future<void> _exportSelectedItems() async {
    if (_selectedItems.isEmpty) {
      _showImportSnackBar('请选择要导出的稿件或文件夹');
      return;
    }
    final articleProvider = context.read<ArticleProvider>();
    final folderProvider = context.read<FolderProvider>();
    final result = await _exportService.exportItems(
      articles: articleProvider.articles,
      folders: folderProvider.folders,
      selectedIds: Set<String>.from(_selectedItems),
    );
    if (result.message != null) {
      _showImportSnackBar(result.message!);
    } else if (result.count > 0 || result.folderCount > 0) {
      _showImportSnackBar('已导出 ${result.count} 篇稿件、${result.folderCount} 个文件夹');
    }
  }

  String _fileName(String path) => path.split(RegExp(r'[\\/]')).last;

  void _showImportSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildImportOverlay() {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: AppColors.primary.withValues(alpha: _isImporting ? 0.10 : 0.08),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceFor(context).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isImporting ? Icons.hourglass_top : Icons.upload_file,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _isImporting ? '正在导入稿件...' : '松开导入 txt/docx 稿件',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleSort(SortBy by) {
    setState(() {
      if (_sortBy == by) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = by;
        _sortAscending = true;
      }
    });
  }

  List<Folder> _sortFolders(List<Folder> folders) {
    final sorted = List<Folder>.from(folders);
    sorted.sort((a, b) {
      final cmp = _sortBy == SortBy.name
          ? a.name.compareTo(b.name)
          : a.createdAt.compareTo(b.createdAt);
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  List<Article> _sortArticles(List<Article> articles) {
    final sorted = List<Article>.from(articles);
    sorted.sort((a, b) {
      final cmp = _sortBy == SortBy.name
          ? a.title.compareTo(b.title)
          : a.updatedAt.compareTo(b.updatedAt);
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  // ─── 导航 ─────────────────────────────────────────────
  bool get _canGoBack => _historyIndex > 0;
  bool get _canGoForward => _historyIndex < _history.length - 1;

  void _resetBreadcrumbScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_breadcrumbScrollController.hasClients) return;
      _breadcrumbScrollController.jumpTo(0);
    });
  }

  void _navigateToFolder(String? folderId) {
    if (folderId == _currentFolderId) return;
    setState(() {
      // 截断前进历史
      if (_historyIndex < _history.length - 1) {
        _history.removeRange(_historyIndex + 1, _history.length);
      }
      _history.add(folderId);
      _historyIndex = _history.length - 1;
      _currentFolderId = folderId;
      _selectedItems.clear();
      searchController.clear();
      searchQuery = '';
    });
    _resetBreadcrumbScroll();
  }

  void _navigateUp() {
    if (_currentFolderId == null) return;
    final folder = context.read<FolderProvider>().getFolderById(
      _currentFolderId!,
    );
    _navigateToFolder(folder?.parentId);
  }

  void _navigateBack() {
    if (!_canGoBack) return;
    setState(() {
      _historyIndex--;
      _currentFolderId = _history[_historyIndex];
      _selectedItems.clear();
    });
    _resetBreadcrumbScroll();
  }

  void _navigateForward() {
    if (!_canGoForward) return;
    setState(() {
      _historyIndex++;
      _currentFolderId = _history[_historyIndex];
      _selectedItems.clear();
    });
    _resetBreadcrumbScroll();
  }

  // ─── 项目交互 ────────────────────────────────────────
  void _selectSingleItem(_ContentItem item) {
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    if (!ctrl &&
        !shift &&
        _selectedItems.length > 1 &&
        _selectedItems.contains(item.id)) {
      return;
    }

    setState(() {
      if (ctrl) {
        // Ctrl+点击：切换选中状态
        if (_selectedItems.contains(item.id)) {
          _selectedItems.remove(item.id);
        } else {
          _selectedItems.add(item.id);
        }
      } else if (shift && _selectedItems.isNotEmpty) {
        // Shift+点击：范围选择
        _handleRangeSelect(item);
      } else {
        // 普通点击：单选
        _selectedItems.clear();
        _selectedItems.add(item.id);
      }
    });
  }

  void _completeItemTap(_ContentItem item) {
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isShiftPressed ||
        _isItemDragActive ||
        _selectedItems.length <= 1 ||
        !_selectedItems.contains(item.id)) {
      return;
    }
    setState(() {
      _selectedItems
        ..clear()
        ..add(item.id);
    });
  }

  void _moveSelectionByKeyboard(int delta) {
    final items = _currentVisibleItems();
    if (items.isEmpty) return;

    final selectedId = _selectedItems.isEmpty ? null : _selectedItems.last;
    final currentIndex = selectedId == null
        ? -1
        : items.indexWhere((item) => item.id == selectedId);
    final targetIndex = (currentIndex < 0 ? 0 : currentIndex + delta)
        .clamp(0, items.length - 1)
        .toInt();

    setState(() {
      _selectedItems
        ..clear()
        ..add(items[targetIndex].id);
    });
  }

  List<_ContentItem> _currentVisibleItems() {
    final folderProvider = context.read<FolderProvider>();
    final articleProvider = context.read<ArticleProvider>();
    final currentId = _currentFolderId;
    List<Folder> folders;
    List<Article> articles;

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      final descendantFolderIds = _descendantFolderIds(
        currentId,
        folderProvider.folders,
      );
      final articleFolderScope = <String?>{currentId, ...descendantFolderIds};
      folders = folderProvider.folders
          .where(
            (f) =>
                (currentId == null || descendantFolderIds.contains(f.id)) &&
                f.name.toLowerCase().contains(query),
          )
          .toList();
      articles = articleProvider.articles
          .where(
            (a) =>
                articleFolderScope.contains(a.folderId) &&
                (a.title.toLowerCase().contains(query) ||
                    a.content.toLowerCase().contains(query)),
          )
          .toList();
    } else {
      folders = folderProvider.folders
          .where((f) => f.parentId == currentId)
          .toList();
      articles = articleProvider.articles
          .where((a) => a.folderId == currentId)
          .toList();
    }

    return [
      ..._sortFolders(folders).map((f) => _ContentItem.folder(f)),
      ..._sortArticles(articles).map((a) => _ContentItem.article(a)),
    ];
  }

  void _handleRangeSelect(_ContentItem item) {
    // 获取当前显示的所有项目
    final folderProvider = context.read<FolderProvider>();
    final articleProvider = context.read<ArticleProvider>();
    final subFolders = folderProvider.folders
        .where((f) => f.parentId == _currentFolderId)
        .toList();
    final articles = articleProvider.articles
        .where((a) => a.folderId == _currentFolderId)
        .toList();
    final allItems = <_ContentItem>[
      ..._sortFolders(subFolders).map((f) => _ContentItem.folder(f)),
      ..._sortArticles(articles).map((a) => _ContentItem.article(a)),
    ];

    // 找到最后选中的项目和当前项目的索引
    final lastSelectedId = _selectedItems.last;
    final fromIndex = allItems.indexWhere((i) => i.id == lastSelectedId);
    final toIndex = allItems.indexWhere((i) => i.id == item.id);

    if (fromIndex < 0 || toIndex < 0) return;

    final start = fromIndex < toIndex ? fromIndex : toIndex;
    final end = fromIndex < toIndex ? toIndex : fromIndex;

    for (int i = start; i <= end; i++) {
      _selectedItems.add(allItems[i].id);
    }
  }

  void _handleItemLongPress(_ContentItem item, Offset globalPosition) {
    // 长按：选中并显示上下文菜单
    if (!_selectedItems.contains(item.id)) {
      setState(() {
        _selectedItems.clear();
        _selectedItems.add(item.id);
      });
    }
    if (globalPosition != Offset.zero) {
      _showContextMenuAtPosition(globalPosition, item);
    }
  }

  bool _canDropItemOnFolder(_ContentItem dragged, String targetFolderId) {
    if (dragged.isFolder && dragged.id == targetFolderId) return false;
    if (!dragged.isFolder) return true;
    final folders = context.read<FolderProvider>().folders;
    var parentId = targetFolderId;
    while (parentId.isNotEmpty) {
      if (parentId == dragged.id) return false;
      final parent = folders.where((f) => f.id == parentId).firstOrNull;
      if (parent?.parentId == null) break;
      parentId = parent!.parentId!;
    }
    return true;
  }

  bool _canDropDraggedItemsOnFolder(
    _ContentItem dragged,
    String targetFolderId,
  ) {
    final items = _selectedItems.contains(dragged.id)
        ? _getContentItemsByIds(_selectedItems)
        : <_ContentItem>[dragged];
    return items.every((item) => _canDropItemOnFolder(item, targetFolderId));
  }

  Future<void> _moveDraggedItemsToFolder(
    _ContentItem dragged,
    String targetFolderId,
  ) async {
    if (!_canDropDraggedItemsOnFolder(dragged, targetFolderId)) return;

    final itemsToMove = _selectedItems.contains(dragged.id)
        ? _getContentItemsByIds(_selectedItems)
        : <_ContentItem>[dragged];
    final folderProvider = context.read<FolderProvider>();
    final articleProvider = context.read<ArticleProvider>();

    for (final item in itemsToMove) {
      if (item.isFolder) {
        if (!_canDropItemOnFolder(item, targetFolderId)) continue;
        await folderProvider.moveFolder(item.id, targetFolderId);
      } else if (item.article != null) {
        await articleProvider.moveArticleToFolder(item.id, targetFolderId);
      }
    }

    if (!mounted) return;
    setState(() => _selectedItems.clear());
  }

  void _handleItemDoubleTap(_ContentItem item) {
    if (item.isFolder) {
      _navigateToFolder(item.id);
    } else if (item.article != null) {
      _openTeleprompter(context, item.article!);
    }
  }

  // ─── 右键菜单 ────────────────────────────────────────
  void _showContextMenu(TapUpDetails details, _ContentItem item) {
    unawaited(_showContextMenuAtPosition(details.globalPosition, item));
  }

  Future<void> _showContextMenuAtPosition(
    Offset globalPosition,
    _ContentItem item,
  ) async {
    if (!_selectedItems.contains(item.id)) {
      setState(() {
        _selectedItems.clear();
        _selectedItems.add(item.id);
      });
    }

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: <PopupMenuEntry<String>>[
        if (item.isFolder) ...[
          const PopupMenuItem<String>(value: 'open', child: Text('打开')),
          const PopupMenuItem<String>(value: 'rename', child: Text('重命名')),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(value: 'cut', child: Text('剪切')),
          const PopupMenuItem<String>(value: 'copy', child: Text('复制')),
          const PopupMenuItem<String>(value: 'properties', child: Text('属性')),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(value: 'delete', child: Text('删除')),
        ] else ...[
          const PopupMenuItem<String>(value: 'open', child: Text('打开提词')),
          const PopupMenuItem<String>(value: 'edit', child: Text('编辑')),
          const PopupMenuItem<String>(value: 'rename', child: Text('重命名')),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(value: 'cut', child: Text('剪切')),
          const PopupMenuItem<String>(value: 'copy', child: Text('复制')),
          const PopupMenuItem<String>(value: 'properties', child: Text('属性')),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'moveToFolder',
            child: Text('移动到文件夹...'),
          ),
          const PopupMenuItem<String>(value: 'delete', child: Text('删除')),
        ],
      ],
    );
    if (!mounted || value == null) return;
    switch (value) {
      case 'open':
        if (item.isFolder) {
          _navigateToFolder(item.id);
        } else if (item.article != null) {
          _openTeleprompter(context, item.article!);
        }
        break;
      case 'edit':
        if (item.article != null) _editArticle(context, item.article!);
        break;
      case 'rename':
        _renameItemDialog(item);
        break;
      case 'cut':
        _clipboardOp = _ClipboardOp.cut;
        _clipboard.clear();
        _clipboard.add(item);
        break;
      case 'copy':
        _clipboardOp = _ClipboardOp.copy;
        _clipboard.clear();
        _clipboard.add(item);
        break;
      case 'properties':
        _showItemPropertiesDialog(item);
        break;
      case 'delete':
        _deleteItemDialog(item);
        break;
      case 'moveToFolder':
        if (item.article != null) _moveToFolderDialog(item.article!);
        break;
    }
  }

  // ─── 文件夹操作 ───────────────────────────────────────
  void _createFolderDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '输入文件夹名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context.read<FolderProvider>().createFolder(
                  name,
                  parentId: _currentFolderId,
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _renameItemDialog(_ContentItem item) {
    final controller = TextEditingController(text: item.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '输入新名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                if (item.isFolder) {
                  context.read<FolderProvider>().renameFolder(item.id, newName);
                } else if (item.article != null) {
                  context.read<ArticleProvider>().updateArticle(
                    item.id,
                    title: newName,
                  );
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _deleteItemDialog(_ContentItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除${item.isFolder ? "文件夹" : "稿件"}'),
        content: Text('确定要删除「${item.name}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (item.isFolder) {
                context.read<FolderProvider>().deleteFolder(item.id);
              } else {
                context.read<ArticleProvider>().deleteArticle(item.id);
              }
              setState(() => _selectedItems.remove(item.id));
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _moveToFolderDialog(Article article) {
    final folderProvider = context.read<FolderProvider>();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('移动到文件夹'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.home, size: 20),
                  title: const Text('根目录'),
                  dense: true,
                  onTap: () {
                    context.read<ArticleProvider>().moveArticleToFolder(
                      article.id,
                      null,
                    );
                    Navigator.pop(ctx);
                  },
                ),
                for (final folder in folderProvider.folders)
                  ListTile(
                    leading: const Icon(
                      Icons.folder,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    title: Text(folder.name),
                    dense: true,
                    onTap: () {
                      context.read<ArticleProvider>().moveArticleToFolder(
                        article.id,
                        folder.id,
                      );
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  // ─── 文章操作 ────────────────────────────────────────
  void _createArticle(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(
              value: context.read<ArticleProvider>(),
            ),
          ],
          child: EditorPage(initialFolderId: _currentFolderId),
        ),
      ),
    );
  }

  void _openTeleprompter(BuildContext context, Article article) {
    final teleprompterProvider = context.read<TeleprompterProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final connection = context.read<ConnectionProvider>();
    settingsProvider.loadArticleOverrides(article.teleprompterSettings);
    teleprompterProvider.loadScript(article.id, article.content);
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: teleprompterProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(
              value: context.read<ArticleProvider>(),
            ),
          ],
          child: TeleprompterPage(article: article),
        ),
      ),
    );
  }

  void _editArticle(BuildContext context, Article article) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(
              value: context.read<ArticleProvider>(),
            ),
          ],
          child: EditorPage(article: article),
        ),
      ),
    );
  }

  // ─── 剪贴板操作 ──────────────────────────────────────
  void _cutSelected() {
    final items = _getContentItemsByIds(_selectedItems);
    _clipboard.clear();
    _clipboard.addAll(items);
    _clipboardOp = _ClipboardOp.cut;
  }

  void _copySelected() {
    final items = _getContentItemsByIds(_selectedItems);
    _clipboard.clear();
    _clipboard.addAll(items);
    _clipboardOp = _ClipboardOp.copy;
  }

  void _pasteItems() {
    for (final item in _clipboard) {
      if (_clipboardOp == _ClipboardOp.cut) {
        if (item.isFolder) {
          context.read<FolderProvider>().moveFolder(item.id, _currentFolderId);
        } else if (item.article != null) {
          context.read<ArticleProvider>().moveArticleToFolder(
            item.id,
            _currentFolderId,
          );
        }
      } else {
        // 复制操作 - 创建副本
        if (!item.isFolder && item.article != null) {
          context.read<ArticleProvider>().createArticle(
            title: '${item.article!.title} - 副本',
            content: item.article!.content,
            folderId: _currentFolderId,
          );
        }
      }
    }
    if (_clipboardOp == _ClipboardOp.cut) {
      _clipboard.clear();
    }
    setState(() {});
  }

  List<_ContentItem> _getContentItemsByIds(Set<String> ids) {
    final items = <_ContentItem>[];
    final folderProvider = context.read<FolderProvider>();
    final articleProvider = context.read<ArticleProvider>();
    for (final id in ids) {
      final folder = folderProvider.getFolderById(id);
      if (folder != null) {
        items.add(_ContentItem.folder(folder));
      } else {
        final article = articleProvider.articles
            .where((a) => a.id == id)
            .firstOrNull;
        if (article != null) items.add(_ContentItem.article(article));
      }
    }
    return items;
  }

  void _renameSelected() {
    if (_selectedItems.length != 1) return;
    final item = _getContentItemsByIds(_selectedItems).firstOrNull;
    if (item != null) _renameItemDialog(item);
  }

  void _deleteSelected() {
    if (_selectedItems.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除'),
        content: Text('确定要删除选中的 ${_selectedItems.length} 个项目吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final folderProvider = context.read<FolderProvider>();
              final articleProvider = context.read<ArticleProvider>();
              for (final id in _selectedItems) {
                final folder = folderProvider.getFolderById(id);
                if (folder != null) {
                  folderProvider.deleteFolder(id);
                } else {
                  articleProvider.deleteArticle(id);
                }
              }
              setState(() => _selectedItems.clear());
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // ─── 设置 ─────────────────────────────────────────────
  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(
              value: context.read<SettingsProvider>(),
            ),
            ChangeNotifierProvider.value(
              value: context.read<ConnectionProvider>(),
            ),
          ],
          child: const SettingsPage(),
        ),
      ),
    );
  }

  // ─── 远程连接 ────────────────────────────────────────
  void _showRemoteConnectDialog(
    BuildContext context,
    ConnectionProvider connection,
  ) {
    final hostController = TextEditingController(
      text: connection.isRemote ? (connection.remoteHost ?? '') : '',
    );
    final portController = TextEditingController(
      text: connection.isRemote && connection.remotePort != null
          ? '${connection.remotePort}'
          : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('连接到远程服务端'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '注意：当前客户端需要和服务端处于同一内网下',
                style: TextStyle(
                  color: AppColors.textMutedFor(context),
                  fontSize: 13,
                ),
              ),
              if (connection.remoteConnectionHistory.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  '历史记录',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: connection.remoteConnectionHistory.map((record) {
                    return ActionChip(
                      label: Text(record.label),
                      onPressed: () {
                        hostController.text = record.host;
                        portController.text = '${record.port}';
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: hostController,
                decoration: const InputDecoration(
                  labelText: '服务端地址',
                  hintText: '服务端连接信息中的任一本机IP',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portController,
                decoration: const InputDecoration(
                  labelText: '服务端端口号',
                  hintText: '服务端连接信息中的端口号',
                ),
                keyboardType: TextInputType.number,
              ),
              if (connection.lastError != null &&
                  connection.lastError!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  connection.lastError!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (connection.isRemote)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _disconnectRemoteAndRestoreLocal(connection);
              },
              child: const Text('断开服务端'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final host = hostController.text.trim();
              final port = int.tryParse(portController.text.trim());
              if (host.isEmpty || port == null || port <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('请输入有效的服务器地址和端口'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              if (!await _confirmLocalBackendShutdown(
                context,
                actionLabel: '切换服务端',
              )) {
                return;
              }
              if (!context.mounted) return;
              final articleProvider = context.read<ArticleProvider>();
              final folderProvider = context.read<FolderProvider>();
              final messenger = ScaffoldMessenger.of(context);
              try {
                await connection.connectToRemote(host, port);
                if (mounted) {
                  articleProvider.loadArticles();
                  folderProvider.loadFolders();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('已连接服务端 $host:$port'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('连接服务端失败: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('连接'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreLocalBackend(ConnectionProvider connection) async {
    await connection.connectToBundledLocal();
    if (!mounted) return;
    if (connection.isConnected && connection.isLocal) {
      await Future.wait([
        context.read<ArticleProvider>().loadArticles(),
        context.read<FolderProvider>().loadFolders(),
        context.read<SettingsProvider>().init(),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已启动本机服务'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(connection.lastError ?? '本机服务连接失败'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _disconnectRemoteAndRestoreLocal(
    ConnectionProvider connection,
  ) async {
    await connection.disconnectRemoteAndReconnectLocal();
    if (!mounted) return;
    if (connection.isConnected && connection.isLocal) {
      await Future.wait([
        context.read<ArticleProvider>().loadArticles(),
        context.read<FolderProvider>().loadFolders(),
        context.read<SettingsProvider>().init(),
      ]);
    }
  }

  // ─── 键盘快捷键 ──────────────────────────────────────
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isTextInputFocused()) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;

    if (key == LogicalKeyboardKey.escape) {
      if (_selectedItems.isNotEmpty) setState(() => _selectedItems.clear());
    } else if (!ctrl &&
        !shift &&
        !alt &&
        key == LogicalKeyboardKey.backspace &&
        _currentFolderId != null) {
      _navigateUp();
    } else if (key == LogicalKeyboardKey.delete) {
      _deleteSelected();
    } else if (key == LogicalKeyboardKey.f2) {
      _renameSelected();
    } else if (!ctrl &&
        !shift &&
        !alt &&
        key == LogicalKeyboardKey.enter &&
        _selectedItems.isNotEmpty) {
      _handleEnterOnSelection();
    } else if (ctrl && key == LogicalKeyboardKey.keyA) {
      _selectAll();
    } else if (ctrl && key == LogicalKeyboardKey.keyN && shift) {
      _createFolderDialog(context);
    } else if (ctrl && key == LogicalKeyboardKey.keyX) {
      _cutSelected();
    } else if (ctrl && key == LogicalKeyboardKey.keyC) {
      _copySelected();
    } else if (ctrl && key == LogicalKeyboardKey.keyV) {
      _pasteItems();
    } else if (alt && key == LogicalKeyboardKey.arrowLeft) {
      _navigateBack();
    } else if (alt && key == LogicalKeyboardKey.arrowRight) {
      _navigateForward();
    } else if (alt && key == LogicalKeyboardKey.arrowUp) {
      _navigateUp();
    } else if (!ctrl && !shift && !alt && key == LogicalKeyboardKey.arrowLeft) {
      _moveSelectionByKeyboard(-1);
    } else if (!ctrl &&
        !shift &&
        !alt &&
        key == LogicalKeyboardKey.arrowRight) {
      _moveSelectionByKeyboard(1);
    } else if (!ctrl && !shift && !alt && key == LogicalKeyboardKey.arrowUp) {
      final step =
          _viewMode == ViewMode.largeIcons || _viewMode == ViewMode.smallIcons
          ? -_lastGridCrossAxisCount
          : -1;
      _moveSelectionByKeyboard(step);
    } else if (!ctrl && !shift && !alt && key == LogicalKeyboardKey.arrowDown) {
      final step =
          _viewMode == ViewMode.largeIcons || _viewMode == ViewMode.smallIcons
          ? _lastGridCrossAxisCount
          : 1;
      _moveSelectionByKeyboard(step);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  bool _isTextInputFocused() {
    var node = FocusManager.instance.primaryFocus;
    while (node != null) {
      final widget = node.context?.widget;
      if (widget is EditableText) return true;
      node = node.parent;
    }
    return false;
  }

  void _handleEnterOnSelection() {
    if (_selectedItems.isEmpty) return;
    if (_selectedItems.length > 1) {
      _showFabMenu(context, context.read<ConnectionProvider>());
      return;
    }

    final item = _getContentItemsByIds(_selectedItems).firstOrNull;
    if (item == null) return;
    if (item.isFolder) {
      _navigateToFolder(item.id);
    } else if (item.article != null) {
      _openTeleprompter(context, item.article!);
    }
  }

  void _selectAll() {
    final folderProvider = context.read<FolderProvider>();
    final articleProvider = context.read<ArticleProvider>();
    setState(() {
      _selectedItems.clear();
      for (final f in folderProvider.folders.where(
        (f) => f.parentId == _currentFolderId,
      )) {
        _selectedItems.add(f.id);
      }
      for (final a in articleProvider.articles.where(
        (a) => a.folderId == _currentFolderId,
      )) {
        _selectedItems.add(a.id);
      }
    });
  }

  // ─── 框选 ─────────────────────────────────────────────
  void _suppressGridSelectionForItem() {
    _suppressNextGridSelection = true;
  }

  void _startItemHoldMenuTimer(_ContentItem item, Offset globalPosition) {
    _itemHoldMenuTimer?.cancel();
    _itemHoldStartPosition = globalPosition;
    _itemHoldMenuTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || _itemHoldStartPosition == null) return;
      _endItemDrag();
      _handleItemLongPress(item, globalPosition);
    });
  }

  void _updateItemHoldPosition(Offset globalPosition) {
    final start = _itemHoldStartPosition;
    if (start == null) return;
    if ((globalPosition - start).distance > _selectionDragThreshold) {
      _cancelItemHoldMenuTimer();
    }
  }

  void _cancelItemHoldMenuTimer() {
    _itemHoldMenuTimer?.cancel();
    _itemHoldMenuTimer = null;
    _itemHoldStartPosition = null;
  }

  void _beginItemDrag(_ContentItem item) {
    setState(() {
      _isItemDragActive = true;
      _isSelecting = false;
      _selectionPointer = null;
      _selectionStart = null;
      _selectionEnd = null;
      if (!_selectedItems.contains(item.id)) {
        _selectedItems
          ..clear()
          ..add(item.id);
      }
    });
  }

  void _endItemDrag() {
    if (!_isItemDragActive) return;
    setState(() => _isItemDragActive = false);
  }

  void _clearGridSelectionGesture() {
    _isSelecting = false;
    _selectionPointer = null;
    _selectionStart = null;
    _selectionEnd = null;
  }

  // ─── 多客户端警告 ────────────────────────────────────
  Future<void> _checkMultiClientBeforeExit(BuildContext context) async {
    if (!mounted) return;
    final shouldExit = await _confirmLocalBackendShutdown(
      context,
      actionLabel: '退出服务端',
    );
    if (!mounted || !context.mounted || !shouldExit) return;
    Navigator.pop(context);
  }

  Future<bool> _confirmLocalBackendShutdown(
    BuildContext context, {
    required String actionLabel,
  }) async {
    if (!mounted) return false;
    final connection = context.read<ConnectionProvider>();
    if (!connection.isLocal || !connection.isConnected) return true;

    final clientCount = globalBackendServer.clientCount;
    if (clientCount < 2) return true;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text('确认$actionLabel'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('检测到有其他客户端连接到本机服务端。继续操作会中断客户端提词。'),
                const SizedBox(height: 8),
                Text(
                  '当前连接数: $clientCount',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMutedFor(ctx),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('继续运行'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ─── 工具 ─────────────────────────────────────────────
  String _itemTooltip(_ContentItem item) {
    return '${item.name}\n修改时间：${_formatDateTime(item.updatedAt)}';
  }

  void _showItemPropertiesDialog(_ContentItem item) {
    final parentFolderId = item.isFolder
        ? item.folder?.parentId
        : item.article?.folderId;
    final rows = <(String, String)>[
      ('名称', item.name),
      ('类型', item.isFolder ? '文件夹' : '稿件'),
      ('位置', _folderLocationLabel(parentFolderId)),
      ('创建时间', _formatDateTime(item.createdAt)),
      ('修改时间', _formatDateTime(item.updatedAt)),
    ];
    if (item.article != null) {
      final plainText = _articlePlainText(item.article!);
      rows.add(('字数', '${plainText.length}'));
      rows.add(('稿件 ID', item.id));
    } else {
      rows.add(('文件夹 ID', item.id));
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('属性'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            row.$1,
                            style: TextStyle(
                              color: AppColors.textMutedFor(ctx),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: SelectableText(
                            row.$2,
                            style: TextStyle(
                              color: AppColors.textPrimaryFor(ctx),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  String _articlePlainText(Article article) {
    return article.content
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
  }

  String _folderLocationLabel(String? folderId) {
    final breadcrumb = context.read<FolderProvider>().getBreadcrumbFrom(
      folderId,
    );
    if (breadcrumb.isEmpty) return '根目录';
    return breadcrumb.map((folder) => folder.name).join(' / ');
  }

  String _formatDateTime(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
