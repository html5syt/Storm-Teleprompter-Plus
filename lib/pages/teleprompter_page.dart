import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../models/article.dart';
import '../models/app_settings.dart';
import '../providers/article_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/teleprompter_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../widgets/teleprompter_text_layer.dart';
import '../widgets/teleprompter_settings_panel.dart';

part 'teleprompter_logic.dart';

/// 提词器主页面
///
/// 整合控制栏、文本层、ASR 逻辑，是提词器的核心展示页面。
/// 支持全屏模式、镜像翻转、自动隐藏界面元素。
///
/// 需求实现：
/// - 顶部全幅进度条 + 右侧已用时间/速度
/// - 浮动工具栏（可隐藏）
/// - 鼠标滚轮动态调速（自动模式）
/// - 按行滚动（snap physics）
/// - 全屏模式修复
class TeleprompterPage extends StatefulWidget {
  final Article article;

  const TeleprompterPage({super.key, required this.article});

  @override
  State<TeleprompterPage> createState() => _TeleprompterPageState();
}

class _TeleprompterPageState extends State<TeleprompterPage>
    with WidgetsBindingObserver, TeleprompterPageLogic {
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<TeleprompterProvider, SettingsProvider>(
      builder: (context, teleprompter, settingsProvider, _) {
        final settings = settingsProvider.mergedSettings;

        return Scaffold(
          backgroundColor: AppColors.teleprompterBgFromSettings(
            settings.teleprompterBgColor,
          ),
          body: CallbackShortcuts(
            bindings: {
              // F11 / Ctrl+Shift+F 全屏切换
              const SingleActivator(LogicalKeyboardKey.f11): toggleFullScreen,
              const SingleActivator(
                LogicalKeyboardKey.keyF,
                control: true,
                shift: true,
              ): toggleFullScreen,
              // Esc 退出提词器
              LogicalKeySet(LogicalKeyboardKey.escape): () =>
                  _exitTeleprompter(context),
              // Enter 切换全屏
              const SingleActivator(LogicalKeyboardKey.enter): toggleFullScreen,
              // Space 开始/暂停
              const SingleActivator(LogicalKeyboardKey.space): () =>
                  teleprompter.togglePlayPause(settings),
              // ↑ 上移一行（未开始时）
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  _handleVerticalMove(context, settings, -1),
              // ↓ 下移一行（未开始时）
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  _handleVerticalMove(context, settings, 1),
              // ← 后退一个字
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                  _handleHorizontalMove(context, settings, -1),
              // → 前进一个字
              const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                  _handleHorizontalMove(context, settings, 1),
            },
            child: Focus(
              autofocus: true,
              child: Listener(
                onPointerSignal: handlePointerSignal,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    // 任何模式下点击空白区域都切换控制面板
                    if (teleprompter.controlsVisible) {
                      teleprompter.toggleControls();
                    } else {
                      teleprompter.showControls(settings);
                    }
                  },
                  child: Stack(
                    children: [
                      // ── 1. 文本层（占据全屏，可滚动） ──
                      _buildTextLayer(context, teleprompter, settings),

                      // ── 2. 阅读线指示器 ──
                      _buildReadingLine(context, settings),

                      // ── 3. 顶部进度条（全幅 + 右侧信息） ──
                      if (teleprompter.isPlaying ||
                          (settings.scrollMode == ScrollMode.auto &&
                              teleprompter.state == TeleprompterState.paused))
                        _buildTopProgressBar(context, teleprompter, settings),

                      // ── 4. 顶部导航栏（浮动、可隐藏） ──
                      if (teleprompter.controlsVisible)
                        _buildTopNavBar(context, teleprompter, settings),

                      // ── 5. 底部浮动工具栏（可隐藏） ──
                      if (teleprompter.controlsVisible)
                        _buildBottomToolbar(
                          context,
                          teleprompter,
                          settingsProvider,
                        ),

                      // ── 6. ASR 音量指示器 ──
                      if (settings.scrollMode == ScrollMode.asr &&
                          teleprompter.isPlaying)
                        _buildRmsMeter(teleprompter, settings),

                      // ── 7. 设置抽屉面板 ──
                      if (_showSettings)
                        Positioned(
                          top: 0,
                          right: 0,
                          bottom: 0,
                          child: TeleprompterSettingsPanel(
                            onClose: () =>
                                setState(() => _showSettings = false),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── 动态颜色辅助 ──────────────────────────────────────
  /// 从设置中获取当前主题色
  Color _primaryFromSettings(AppSettings s) =>
      AppColors.primaryFromSettings(s.uiPrimaryColor);

  /// 从设置中获取当前提词器背景色
  Color _bgFromSettings(AppSettings s) =>
      AppColors.teleprompterBgFromSettings(s.teleprompterBgColor);

  // ─── 顶部进度条（全幅，右侧显示时间+速度） ──────────

  Widget _buildTopProgressBar(
    BuildContext context,
    TeleprompterProvider teleprompter,
    AppSettings settings,
  ) {
    final progress = teleprompter.progress;
    final elapsed = teleprompter.elapsed;
    // 进度条右侧文字大小 = 正文的 settings.progressInfoSizeRatio (默认 60%)
    final infoFontSize = settings.fontSize * settings.progressInfoSizeRatio;
    final clampedFontSize = infoFontSize.clamp(11.0, 48.0);
    final barHeight = _progressBarHeight(settings);

    // 构建信息文本（根据各项开关动态显示）
    final infoChildren = <Widget>[
      // 已用时间
      if (settings.progressShowTime) ...[
        Text(
          formatDuration(elapsed),
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: clampedFontSize,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 8),
      ],
      // 速度（阅读模式且允许显示）
      if (settings.scrollMode != ScrollMode.asr &&
          settings.progressShowSpeed) ...[
        Text(
          '${settings.wpm}字/分',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: clampedFontSize,
            fontWeight: FontWeight.w700,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 8),
      ],
      // 百分比
      if (settings.progressShowPercentage) ...[
        Text(
          '${(progress * 100).round()}%',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: clampedFontSize,
            fontWeight: FontWeight.w700,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 8),
      ],
      // 当前时间
      if (settings.progressShowCurrentTime) ...[
        Text(
          _formatCurrentTime(),
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: clampedFontSize,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
      ],
    ];

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () {}, // 拦截点击，不触发父级
        child: SizedBox(
          height: barHeight,
          child: Stack(
            children: [
              // 进度条背景
              Positioned.fill(
                child: Container(
                  color: AppColors.background.withValues(alpha: 0.6),
                ),
              ),
              // 进度条填充
              Positioned(
                top: 0,
                left: 0,
                bottom: 0,
                width: MediaQuery.of(context).size.width * progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _primaryFromSettings(settings).withValues(alpha: 0.8),
                        _primaryFromSettings(settings),
                      ],
                    ),
                  ),
                ),
              ),
              // 右侧信息（自动根据文本宽度调整）
              Positioned(
                top: 0,
                right: 12,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: infoChildren,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 顶部导航栏（浮动样式，可隐藏） ──────────────────

  /// 计算进度条尺寸，供导航栏定位
  double _progressBarHeight(AppSettings settings) {
    final infoFontSize = settings.fontSize * settings.progressInfoSizeRatio;
    final clampedFontSize = infoFontSize.clamp(11.0, 48.0);
    return (clampedFontSize + 12).clamp(32.0, 60.0);
  }

  Widget _buildTopNavBar(
    BuildContext context,
    TeleprompterProvider teleprompter,
    AppSettings settings,
  ) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      top: _progressBarHeight(settings) + 4, // 进度条下方
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () {}, // 拦截点击
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _bgFromSettings(settings).withValues(alpha: 0.9),
                _bgFromSettings(settings).withValues(alpha: 0.0),
              ],
            ),
          ),
          child: Row(
            children: [
              // 返回按钮（先退出全屏再返回）
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
                onPressed: () async {
                  if (isFullScreen) {
                    await exitFullScreen();
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 4),
              // 稿件标题
              Expanded(
                child: Text(
                  widget.article.title.isEmpty ? '无标题' : widget.article.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 全屏按钮
              IconButton(
                icon: Icon(
                  isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
                onPressed: toggleFullScreen,
                tooltip: isFullScreen ? '退出全屏' : '全屏',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              // 快速滚动到尾部
              IconButton(
                icon: const Icon(
                  Icons.vertical_align_bottom,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
                onPressed: () => _scrollToEnd(),
                tooltip: '快速滚动到尾部',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              // 重置
              IconButton(
                icon: const Icon(
                  Icons.replay,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
                onPressed: () => _resetAndScrollToTop(teleprompter),
                tooltip: '重置到开头',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 底部浮动工具栏 ──────────────────────────────────

  Widget _buildBottomToolbar(
    BuildContext context,
    TeleprompterProvider teleprompter,
    SettingsProvider settingsProvider,
  ) {
    final settings = settingsProvider.settings;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      bottom: MediaQuery.of(context).padding.bottom + 16,
      left: 32,
      right: 32,
      child: GestureDetector(
        onTap: () {}, // 拦截点击
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _bgFromSettings(settings).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── 模式选择 ──
              _buildModeSelector(settings, settingsProvider),
              const SizedBox(width: 12),

              // ── 播放控制 ──
              _buildCompactPlaybackControls(teleprompter, settings),

              // ── 速度/信息 ──
              if (settings.scrollMode != ScrollMode.asr) ...[
                const SizedBox(width: 12),
                _buildSpeedDisplay(settings, settingsProvider),
              ],

              // ── 设置齿轮 ──
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.settings,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
                onPressed: () => setState(() => _showSettings = true),
                tooltip: '设置',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 紧凑播放控制（源版本风格）
  Widget _buildCompactPlaybackControls(
    TeleprompterProvider teleprompter,
    AppSettings settings,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 后退一个字（长按：重置到开头）
        GestureDetector(
          onTap: () => teleprompter.rewind(settings),
          onLongPress: () {
            teleprompter.resetToStart();
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.skip_previous,
              color: AppColors.textSecondary,
              size: 26,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 开始/暂停
        GestureDetector(
          onTap: () => teleprompter.togglePlayPause(settings),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primaryFromSettings(settings),
              boxShadow: [
                BoxShadow(
                  color: _primaryFromSettings(settings).withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              teleprompter.isPlaying
                  ? Icons.pause
                  : teleprompter.state == TeleprompterState.completed
                  ? Icons.replay
                  : Icons.play_arrow,
              color: AppColors.background,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 前进一个字（长按：重置到结尾）
        GestureDetector(
          onTap: () => teleprompter.forward(settings),
          onLongPress: () => teleprompter.resetToEnd(),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.skip_next,
              color: AppColors.textSecondary,
              size: 26,
            ),
          ),
        ),
      ],
    );
  }

  /// 速度显示（源版本风格）
  Widget _buildSpeedDisplay(
    AppSettings settings,
    SettingsProvider settingsProvider,
  ) {
    return GestureDetector(
      onTap: () => _showSpeedPresets(settingsProvider, settings.wpm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${settings.wpm}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _primaryFromSettings(settings),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '字/分',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示速度预设菜单
  void _showSpeedPresets(SettingsProvider settingsProvider, int currentWpm) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final presets = [60, 80, 100, 120, 150, 180, 200, 250, 300, 400];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '选择速度',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const Divider(height: 1),
              ...presets.map(
                (wpm) => ListTile(
                  title: Text('$wpm 字/分'),
                  trailing: wpm == currentWpm ? const Icon(Icons.check) : null,
                  onTap: () {
                    settingsProvider.setWpm(wpm);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── 模式选择器 ──────────────────────────────────────

  Widget _buildModeSelector(
    AppSettings settings,
    SettingsProvider settingsProvider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          _buildModeChip(
            icon: Icons.menu_book,
            label: '自动',
            mode: ScrollMode.auto, // 合并手动/自动为"自动"模式
            settings: settings,
            settingsProvider: settingsProvider,
          ),
          _buildModeChip(
            icon: Icons.mic,
            label: '语音',
            mode: ScrollMode.asr,
            settings: settings,
            settingsProvider: settingsProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip({
    required IconData icon,
    required String label,
    required ScrollMode mode,
    required AppSettings settings,
    required SettingsProvider settingsProvider,
  }) {
    // "阅读"模式包含 manual 和 auto
    final isSelected = mode == ScrollMode.auto
        ? (settings.scrollMode == ScrollMode.auto ||
              settings.scrollMode == ScrollMode.manual)
        : settings.scrollMode == mode;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          settingsProvider.setScrollMode(mode);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? _primaryFromSettings(settings).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(
                  color: _primaryFromSettings(settings).withValues(alpha: 0.5),
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? _primaryFromSettings(settings)
                  : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? _primaryFromSettings(settings)
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 处理上下键：上下移动n行（未开始时）
  ///
  /// 思维导图描述：
  /// - 未开始：相对于当前字位置，将当前字位置上下移动n行
  /// - 自动滚动模式已开始：调速（由滚轮处理，键盘不触发）
  void _handleVerticalMove(
    BuildContext context,
    AppSettings settings,
    int direction,
  ) {
    if (direction == 0) return;
    final teleprompter = context.read<TeleprompterProvider>();

    // 自动滚动播放中：上键减速/下键加速
    if (settings.scrollMode == ScrollMode.auto && teleprompter.isPlaying) {
      final step = direction > 0 ? 10 : -10;
      final newWpm = (settings.wpm + step).clamp(
        AppConstants.minWpm,
        AppConstants.maxWpm,
      );
      context.read<SettingsProvider>().setWpm(newWpm);
      return;
    }

    // 未开始/暂停：上下移动当前字位置n行
    final current = teleprompter.currentIndex;
    final lines = teleprompter.lines;
    if (lines.isEmpty) return;

    final currentPosition = current >= 0
        ? teleprompter.getCharPosition(current)
        : null;
    final currentLine = currentPosition?.$1 ?? 0;
    final inLineOffset = currentPosition?.$2 ?? 0;
    final step = direction > 0 ? 1 : -1;
    var targetLine = currentPosition == null
        ? 0
        : (currentLine + direction).clamp(0, lines.length - 1).toInt();

    while (targetLine >= 0 && targetLine < lines.length) {
      final targetChars = lines[targetLine].characters;
      if (targetChars.isNotEmpty) {
        final newOffset = inLineOffset.clamp(0, targetChars.length - 1).toInt();
        teleprompter.setCurrentIndex(targetChars[newOffset].rawIndex);
        return;
      }
      targetLine += step;
    }
  }

  /// 处理左右键：移动当前字到前后n个字
  ///
  /// 思维导图描述：左右滑动/键盘左右键 → 移动当前字选择到前后n个字
  void _handleHorizontalMove(
    BuildContext context,
    AppSettings settings,
    int direction,
  ) {
    if (direction == 0) return;
    final teleprompter = context.read<TeleprompterProvider>();
    if (direction > 0) {
      teleprompter.forward(settings);
    } else if (teleprompter.currentIndex < 0) {
      teleprompter.resetToStart();
    } else {
      teleprompter.rewind(settings);
    }
  }

  /// 退出提词器（Esc 键）
  void _exitTeleprompter(BuildContext context) {
    if (isFullScreen) {
      exitFullScreen();
    }
    Navigator.pop(context);
  }

  // ─── 文本层 ──────────────────────────────────────────

  Widget _buildTextLayer(
    BuildContext context,
    TeleprompterProvider teleprompter,
    AppSettings settings,
  ) {
    // 自动滚动播放中阻止滚轮手动滚动
    final bool blockScroll =
        settings.scrollMode == ScrollMode.auto && teleprompter.isPlaying;
    final ScrollPhysics? physics = blockScroll
        ? const NeverScrollableScrollPhysics()
        : null;

    return Positioned.fill(
      child: TeleprompterTextLayer(
        key: textLayerKey,
        scrollController: scrollController,
        lines: teleprompter.lines,
        currentIndex: teleprompter.currentIndex,
        fontSize: settings.fontSize,
        lineHeight: settings.lineHeight,
        mirrorMode: settings.mirrorMode,
        paddingX: settings.paddingX,
        readingLineOffset: settings.readingLineOffset,
        physics: physics,
        onCharTap: (rawIndex) {
          teleprompter.setCurrentIndex(rawIndex);
        },
        onReadingLineChanged: (rawIndex) {
          if (blockScroll) return;
          teleprompter.setCurrentIndex(rawIndex);
        },
        teleprompterFontFamily: settings.teleprompterFontFamily,
        grayReadChars: settings.grayReadChars,
        textColor: settings.textColor,
        letterSpacing: settings.letterSpacing,
        highlightCurrentChar: settings.highlightCurrentChar,
        defaultBold: settings.defaultBold,
        underlineCurrentChar: settings.underlineCurrentChar,
      ),
    );
  }

  // ─── 阅读区域框（主体样式） ────────────────────────────

  /// 阅读线固定金色（与原版 fdc800 一致）
  static const Color _readingLineGold = Color(0xFFFDC800);

  Widget _buildReadingLine(BuildContext context, AppSettings settings) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    // 使用可配置的阅读线偏移，默认 0.25（桌面）或 0.30（移动）
    final defaultRatio = isMobile ? 0.30 : 0.25;
    final readingLineY =
        screenHeight *
        (settings.readingLineOffset > 0
            ? settings.readingLineOffset
            : defaultRatio);
    // 每行实际高度 = fontSize * lineHeight（文本） + 4（Padding vertical:2 上下各2px）
    final perLineHeight = settings.fontSize * settings.lineHeight + 4;
    // 阅读区域高度 = 3 行（与原版一致，修正 padding 的影响）
    final areaHeight = perLineHeight * 3 - 2; // 略减2px避免与上下行边界重叠
    // 水平边距计算（与文本层一致）
    final basePadding = isMobile ? 16.0 : 64.0;
    final extraPadding = screenWidth * settings.paddingX / 100;
    final horizontalPadding = basePadding + extraPadding;

    return Positioned(
      top: readingLineY - areaHeight / 2,
      left: horizontalPadding,
      right: horizontalPadding,
      child: IgnorePointer(
        child: SizedBox(
          height: areaHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 金色边框（与原版 #fdc800 一致）
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _readingLineGold.withValues(alpha: 0.9),
                      width: settings.readingAreaBorderWidth,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // "Reading Area" 标签
              Positioned(
                top: -10,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  color: AppColors.teleprompterBgFromSettings(
                    settings.teleprompterBgColor,
                  ),
                  child: Text(
                    'READING AREA',
                    style: TextStyle(
                      fontSize: 10,
                      color: _readingLineGold.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── ASR 音量指示器 ──────────────────────────────────

  Widget _buildRmsMeter(
    TeleprompterProvider teleprompter,
    AppSettings settings,
  ) {
    final normalizedRms = (teleprompter.rms * 3).clamp(0.0, 1.0);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      right: 16,
      child: IgnorePointer(
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
                color: _primaryFromSettings(settings),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
