part of '../home_page.dart';

/// 管理本次启动的快速模式，浏览列表期间保持同一个编辑器实例。
mixin HomeQuickMode on State<HomePage> {
  final _quickEditorKey = GlobalKey<EditorPageState>();
  final _quickLibraryNavigatorKey = GlobalKey<NavigatorState>();
  bool _quickModeActive = false;
  bool _showQuickEditor = false;
  bool _startupReady = false;
  bool _quickAutoSave = false;
  String? _quickFolderId;

  /// 退出行为由首页统一处理，包含多端连接确认和服务关闭。
  Future<void> _checkMultiClientBeforeExit(BuildContext context);

  /// 等设置与目录加载完成后再选择初始页面，避免显示错误的启动页。
  void _initializeQuickMode() {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>().settings;
    final folders = context.read<FolderProvider>();
    setState(() {
      _quickModeActive =
          settings.quickModeEnabled &&
          !context.read<ConnectionProvider>().isRemote;
      _showQuickEditor = _quickModeActive;
      _quickAutoSave = settings.quickModeAutoSave;
      _quickFolderId = folders.getFolderById(settings.quickModeFolderId)?.id;
      _startupReady = true;
    });
  }

  /// 编辑器始终留在背景，稿件管理和应用设置均限制在带边距的面板中。
  Widget _buildQuickWorkspace(Widget library) {
    if (!_startupReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_quickModeActive) return library;
    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            excluding: !_showQuickEditor,
            child: ExcludeFocus(
              excluding: !_showQuickEditor,
              child: IgnorePointer(
                ignoring: !_showQuickEditor,
                child: EditorPage(
                  key: _quickEditorKey,
                  quickMode: true,
                  isActive: _showQuickEditor,
                  autoSave: _quickAutoSave,
                  initialFolderId: _quickFolderId,
                  onOpenLibrary: _openQuickLibrary,
                  onExit: () => _checkMultiClientBeforeExit(context),
                ),
              ),
            ),
          ),
        ),
        if (!_showQuickEditor)
          Positioned.fill(
            child: QuickLibraryOverlay(
              navigatorKey: _quickLibraryNavigatorKey,
              library: library,
              onClose: _closeQuickLibrary,
            ),
          ),
      ],
    );
  }

  /// 浏览稿件前收起编辑器输入焦点，避免键盘遮挡管理面板。
  void _openQuickLibrary() {
    FocusScope.of(context).unfocus();
    setState(() => _showQuickEditor = false);
  }

  /// 关闭面板只恢复原编辑器，正文、标题、选区与撤销栈均不重新创建。
  void _closeQuickLibrary() {
    if (!mounted || !_quickModeActive) return;
    setState(() => _showQuickEditor = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showQuickEditor)
        _quickEditorKey.currentState?.editorFocusNode.requestFocus();
    });
  }

  /// 关闭应用也检查隐藏在稿件管理视图后面的临时编辑器。
  Future<bool> _confirmQuickDraft() async {
    return await _quickEditorKey.currentState?.confirmLeave() ?? true;
  }

  /// 打开其他稿件后结束本次快速会话，不改变下次启动的全局设置。
  Future<bool> _finishQuickMode() async {
    if (!_quickModeActive) return true;
    if (!await _confirmQuickDraft() || !mounted) return false;
    setState(() {
      _quickModeActive = false;
      _showQuickEditor = false;
    });
    return true;
  }
}
