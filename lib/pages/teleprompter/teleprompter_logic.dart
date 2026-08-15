part of '../teleprompter_page.dart';

mixin TeleprompterPageLogic<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  final ScrollController scrollController = ScrollController();
  final GlobalKey<TeleprompterTextLayerState> textLayerKey =
      GlobalKey<TeleprompterTextLayerState>();
  bool isFullScreen = false;

  TeleprompterProvider? _teleprompterProvider;
  SettingsProvider? _settingsProvider;
  ConnectionProvider? _connectionProvider;
  ArticleProvider? _articleProvider;
  _WindowEventListener? _windowListener;
  bool _remoteSessionEndSent = false;
  bool _viewportProgressUpdateScheduled = false;
  double? _pendingViewportProgress;
  Timer? _articleSettingsSaveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _teleprompterProvider = context.read<TeleprompterProvider>();
    _settingsProvider = context.read<SettingsProvider>();
    _connectionProvider = context.read<ConnectionProvider>();
    _articleProvider = context.read<ArticleProvider>();
    _setupScrollListener();

    final article = (widget as TeleprompterPage).article;
    _settingsProvider!.loadArticleOverrides(
      article.teleprompterSettings,
      notify: false,
    );
    _settingsProvider!.addListener(_scheduleArticleSettingsSave);

    if (_isDesktop) {
      _initWindowListener();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = _settingsProvider!.mergedSettings;
      if (settings.fullScreenMode) {
        enterFullScreen();
      }
    });
  }

  void _initWindowListener() async {
    try {
      await windowManager.ensureInitialized();
      _windowListener = _WindowEventListener(this);
      windowManager.addListener(_windowListener!);
    } catch (e) {
      debugPrint('[WindowListener] 初始化失败: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settingsProvider?.removeListener(_scheduleArticleSettingsSave);
    _articleSettingsSaveTimer?.cancel();
    if (_windowListener != null) {
      windowManager.removeListener(_windowListener!);
    }
    if (isFullScreen) {
      unawaited(exitFullScreen(updateState: false));
    }
    unawaited(_saveArticleOverrides());
    _sendRemoteSessionEndIfMaster();
    _settingsProvider?.clearArticleOverrides();
    scrollController.dispose();
    _teleprompterProvider?.stopAll();
    super.dispose();
  }

  void _scheduleArticleSettingsSave() {
    final connection = _connectionProvider;
    if (connection == null || connection.isRemote || !connection.isConnected) {
      return;
    }
    _articleSettingsSaveTimer?.cancel();
    _articleSettingsSaveTimer = Timer(
      TeleprompterConstants.articleSettingsSaveDebounce,
      () => unawaited(_saveArticleOverrides()),
    );
  }

  Future<void> _saveArticleOverrides() async {
    final connection = _connectionProvider;
    if (connection == null) return;
    if (connection.isRemote || connection.canRetryRemoteConnection) return;

    final overrides = _settingsProvider?.articleOverrides;
    if (overrides != null && overrides.isNotEmpty) {
      try {
        final article = (widget as TeleprompterPage).article;
        await _articleProvider?.updateArticleTeleprompterSettings(
          article.id,
          Map<String, dynamic>.from(overrides),
        );
      } catch (e) {
        debugPrint('[TeleprompterLogic] 保存稿件设置失败: $e');
      }
    }
  }

  Map<String, dynamic> _sessionEndData() {
    return {'articleId': (widget as TeleprompterPage).article.id};
  }

  bool _canEndRemoteSession(ConnectionProvider connection) {
    return !_remoteSessionEndSent &&
        connection.isLocal &&
        connection.isConnected;
  }

  void _sendRemoteSessionEndIfMaster() {
    final connection = _connectionProvider;
    if (connection == null) return;
    if (!_canEndRemoteSession(connection)) return;
    _remoteSessionEndSent = true;
    connection.send(
      WsMessage(
        type: WsMessageType.teleprompterEndSession,
        data: _sessionEndData(),
      ),
    );
  }

  Future<void> _endRemoteSessionIfMaster() async {
    final connection = _connectionProvider;
    if (connection == null) return;
    if (!_canEndRemoteSession(connection)) return;
    _remoteSessionEndSent = true;
    try {
      await connection.request(
        WsMessageType.teleprompterEndSession,
        data: _sessionEndData(),
        timeout: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('[TeleprompterLogic] 结束远程会话确认失败: $e');
      connection.send(
        WsMessage(
          type: WsMessageType.teleprompterEndSession,
          data: _sessionEndData(),
        ),
      );
    }
  }


  bool get _isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  Future<void> enterFullScreen() async {
    if (isFullScreen) return;
    if (mounted) setState(() => isFullScreen = true);

    if (_isDesktop) {
      try {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
        await Future.delayed(const Duration(milliseconds: 50));
        await windowManager.setFullScreen(true);
      } catch (e) {
        debugPrint('[FullScreen] 全屏失败，降级处理: $e');
        try {
          await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
        } catch (_) {}
        try {
          await windowManager.setFullScreen(true);
        } catch (_) {}
      }
    } else if (!kIsWeb) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Future<void> exitFullScreen({bool updateState = true}) async {
    if (!isFullScreen && updateState) return;
    if (updateState && mounted) {
      setState(() => isFullScreen = false);
    } else {
      isFullScreen = false;
    }

    if (_isDesktop) {
      try {
        await windowManager.setFullScreen(false);
        await Future.delayed(const Duration(milliseconds: 50));
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      } catch (e) {
        debugPrint('[FullScreen] 退出全屏失败: $e');
      }
    } else if (!kIsWeb) {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  void toggleFullScreen() {
    if (isFullScreen) {
      exitFullScreen();
    } else {
      enterFullScreen();
    }
  }


  void handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    final teleprompter = context.read<TeleprompterProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final settings = settingsProvider.mergedSettings;
    if (context.read<ConnectionProvider>().isRemote) return;

    if (settings.scrollMode == ScrollMode.auto &&
        teleprompter.isPlaying &&
        settings.wpm > 0) {
      teleprompter.adjustSpeedByWheel(
        event.scrollDelta.dy,
        settingsProvider,
        stepMultiplier: _speedStepMultiplier(),
      );
      return;
    }

    if (settings.scrollMode == ScrollMode.auto &&
        teleprompter.isPlaying &&
        settings.wpm <= 0) {
      if (_speedModifierPressed()) {
        teleprompter.adjustSpeedByWheel(
          event.scrollDelta.dy,
          settingsProvider,
          stepMultiplier: _speedStepMultiplier(),
        );
        return;
      }

      final direction = event.scrollDelta.dy > 0 ? 1 : -1;
      final visualTarget = textLayerKey.currentState?.rawIndexForVisualLineMove(
        direction,
      );
      if (visualTarget != null) {
        teleprompter.setCurrentIndex(visualTarget);
      }
      return;
    }

  }

  int _speedStepMultiplier() {
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed) return 10;
    if (keyboard.isShiftPressed) return 4;
    return 1;
  }

  bool _speedModifierPressed() {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isControlPressed || keyboard.isShiftPressed;
  }


  void _setupScrollListener() {
    scrollController.addListener(_onScrollChanged);
  }

  void _onScrollChanged() {
    if (!mounted) return;
    if (!scrollController.hasClients) return;
    final maxScroll = scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPad = screenHeight * (TeleprompterConstants.topPaddingVh / 100);
    final bottomPad =
        screenHeight * (TeleprompterConstants.bottomPaddingVh / 100);
    final contentExtent = maxScroll - topPad - bottomPad;
    if (contentExtent <= 0) {
      _scheduleViewportProgressUpdate(0.0);
      return;
    }
    final contentOffset = (scrollController.offset - topPad).clamp(
      0.0,
      contentExtent,
    );
    final progress = (contentOffset / contentExtent).clamp(0.0, 1.0);
    _scheduleViewportProgressUpdate(progress);
  }

  void _scheduleViewportProgressUpdate(double progress) {
    _pendingViewportProgress = progress;
    if (_viewportProgressUpdateScheduled) return;
    _viewportProgressUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportProgressUpdateScheduled = false;
      if (!mounted) return;
      final value = _pendingViewportProgress;
      _pendingViewportProgress = null;
      if (value == null) return;
      context.read<TeleprompterProvider>().setViewportProgress(value);
    });
  }


  String formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}

class _WindowEventListener extends WindowListener {
  final TeleprompterPageLogic state;

  _WindowEventListener(this.state);

  @override
  void onWindowMaximize() {
    if (!state.isFullScreen) {
      windowManager.setTitleBarStyle(TitleBarStyle.normal);
    }
  }

  @override
  void onWindowUnmaximize() {
    if (!state.isFullScreen) {
      windowManager.setTitleBarStyle(TitleBarStyle.normal);
    }
  }
}
