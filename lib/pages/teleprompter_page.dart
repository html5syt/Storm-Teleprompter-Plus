import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../models/app_settings.dart';
import '../providers/teleprompter_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../widgets/teleprompter_text_layer.dart';
import '../widgets/teleprompter_controls.dart';

/// 提词器主页面
///
/// 整合控制栏、文本层、ASR 逻辑，是提词器的核心展示页面。
/// 支持全屏模式、镜像翻转、自动隐藏界面元素。
class TeleprompterPage extends StatefulWidget {
  final Article article;

  const TeleprompterPage({super.key, required this.article});

  @override
  State<TeleprompterPage> createState() => _TeleprompterPageState();
}

class _TeleprompterPageState extends State<TeleprompterPage>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _textLayerKey = GlobalKey();
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>().settings;
      if (settings.fullScreenMode) {
        _enterFullScreen();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _exitFullScreen();
    _scrollController.dispose();
    // 退出时停止提词器
    if (mounted) {
      final provider = context.read<TeleprompterProvider>();
      provider.pause(context.read<SettingsProvider>().settings);
    }
    super.dispose();
  }

  /// 进入全屏模式（隐藏系统 UI）
  void _enterFullScreen() {
    setState(() => _isFullScreen = true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
  }

  /// 退出全屏模式
  void _exitFullScreen() {
    if (_isFullScreen) {
      setState(() => _isFullScreen = false);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  /// 切换全屏
  void _toggleFullScreen() {
    if (_isFullScreen) {
      _exitFullScreen();
    } else {
      _enterFullScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TeleprompterProvider, SettingsProvider>(
      builder: (context, teleprompter, settingsProvider, _) {
        final settings = settingsProvider.settings;

        return Scaffold(
          backgroundColor: AppColors.teleprompterBackground,
          body: GestureDetector(
            // 全屏模式下点击屏幕显示控制面板
            onTap: () {
              if (_isFullScreen) {
                teleprompter.showControls(settings);
              }
            },
            child: Stack(
              children: [
                // 阅读线指示器
                _buildReadingLine(context, settings),

                // 文本层
                _buildTextLayer(context, teleprompter, settings),

                // 顶部工具栏（非全屏或控制面板可见时显示）
                if (teleprompter.controlsVisible || !_isFullScreen)
                  _buildTopBar(context, teleprompter, settings),

                // 底部控制面板
                if (teleprompter.controlsVisible || !_isFullScreen)
                  _buildBottomControls(context, teleprompter, settings),

                // ASR 音量指示器
                if (settings.scrollMode == ScrollMode.asr &&
                    teleprompter.isPlaying)
                  _buildRmsMeter(teleprompter),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 阅读线指示器
  Widget _buildReadingLine(BuildContext context, AppSettings settings) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final readingLineY =
        screenHeight *
        (isMobile
            ? AppConstants.readingLineRatioMobile
            : AppConstants.readingLineRatioDesktop);

    return Positioned(
      top: readingLineY - 1,
      left: 0,
      right: 0,
      child: Container(
        height: 2,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0),
              AppColors.primary.withOpacity(0.3),
              AppColors.primary.withOpacity(0.3),
              AppColors.primary.withOpacity(0),
            ],
          ),
        ),
      ),
    );
  }

  /// 文本层
  Widget _buildTextLayer(
    BuildContext context,
    TeleprompterProvider teleprompter,
    AppSettings settings,
  ) {
    return Positioned.fill(
      child: GestureDetector(
        // 点击空白区域跳转
        onTapUp: (details) {
          if (!teleprompter.isPlaying) return;
          // 触摸文本区域时在全屏模式下显示控制面板
          if (_isFullScreen) {
            teleprompter.showControls(settings);
          }
        },
        child: TeleprompterTextLayer(
          key: _textLayerKey,
          scrollController: _scrollController,
          lines: teleprompter.lines,
          currentIndex: teleprompter.currentIndex,
          fontSize: settings.fontSize,
          lineHeight: settings.lineHeight,
          mirrorMode: settings.mirrorMode,
        ),
      ),
    );
  }

  /// 顶部工具栏
  Widget _buildTopBar(
    BuildContext context,
    TeleprompterProvider teleprompter,
    AppSettings settings,
  ) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.teleprompterBackground.withOpacity(0.95),
              AppColors.teleprompterBackground.withOpacity(0.0),
            ],
          ),
        ),
        child: Row(
          children: [
            // 返回按钮
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            // 稿件标题
            Expanded(
              child: Text(
                widget.article.title.isEmpty ? '无标题' : widget.article.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 全屏按钮
            IconButton(
              icon: Icon(
                _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: AppColors.textPrimary,
              ),
              onPressed: _toggleFullScreen,
              tooltip: _isFullScreen ? '退出全屏' : '全屏',
            ),
            // 更多选项
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
              onSelected: (value) =>
                  _handleMenuAction(value, teleprompter, settings),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'mirror',
                  child: Row(
                    children: [
                      Icon(
                        Icons.flip,
                        size: 18,
                        color: settings.mirrorMode
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                      const SizedBox(width: 12),
                      Text(settings.mirrorMode ? '关闭镜像' : '镜像翻转'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.replay, size: 18),
                      SizedBox(width: 12),
                      Text('重置到开头'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 底部控制面板
  Widget _buildBottomControls(
    BuildContext context,
    TeleprompterProvider teleprompter,
    AppSettings settings,
  ) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      bottom: 0,
      left: 0,
      right: 0,
      child: TeleprompterControls(
        teleprompter: teleprompter,
        settings: settings,
        onPlayPause: () => teleprompter.togglePlayPause(settings),
        onReset: () => teleprompter.reset(),
        onFontSizeChanged: (v) =>
            context.read<SettingsProvider>().setFontSize(v),
        onWpmChanged: (v) => context.read<SettingsProvider>().setWpm(v),
        onScrollModeChanged: (mode) =>
            context.read<SettingsProvider>().setScrollMode(mode),
      ),
    );
  }

  /// ASR 音量指示器
  Widget _buildRmsMeter(TeleprompterProvider teleprompter) {
    // 将 RMS (0.0~1.0) 映射到 0.0~1.0 的显示比例
    final normalizedRms = (teleprompter.rms * 3).clamp(0.0, 1.0);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      right: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 6,
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            height: 60 * normalizedRms,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  /// 处理菜单操作
  void _handleMenuAction(
    String action,
    TeleprompterProvider teleprompter,
    AppSettings settings,
  ) {
    switch (action) {
      case 'mirror':
        context.read<SettingsProvider>().toggleMirrorMode();
        break;
      case 'reset':
        teleprompter.reset();
        break;
    }
  }
}
