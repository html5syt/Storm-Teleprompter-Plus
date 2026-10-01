part of '../home_page.dart';

/// 管理本次启动的快速模式，浏览列表期间保持同一个编辑器实例。
mixin HomeQuickMode on State<HomePage> {
  final _quickEditorKey = GlobalKey<EditorPageState>();
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

  /// 两个视图共用首页路由，保留正文、选区和撤销栈。
  Widget _buildQuickWorkspace(Widget library) {
    if (!_startupReady)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_quickModeActive) return library;
    return IndexedStack(
      index: _showQuickEditor ? 1 : 0,
      children: [
        ExcludeFocus(excluding: _showQuickEditor, child: library),
        ExcludeFocus(
          excluding: !_showQuickEditor,
          child: EditorPage(
            key: _quickEditorKey,
            quickMode: true,
            isActive: _showQuickEditor,
            autoSave: _quickAutoSave,
            initialFolderId: _quickFolderId,
            onOpenLibrary: () => setState(() => _showQuickEditor = false),
            onExit: () => _checkMultiClientBeforeExit(context),
          ),
        ),
      ],
    );
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
