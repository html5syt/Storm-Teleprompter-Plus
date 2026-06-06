import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../providers/teleprompter_provider.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';

/// 提词器底部控制面板
///
/// 包含播放/暂停、滚动模式切换、字体大小、速度调节等控制。
/// 对应原始项目中 TeleprompterView 的控制栏。
class TeleprompterControls extends StatelessWidget {
  final TeleprompterProvider teleprompter;
  final AppSettings settings;
  final VoidCallback onPlayPause;
  final VoidCallback onReset;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<int> onWpmChanged;
  final ValueChanged<ScrollMode> onScrollModeChanged;

  const TeleprompterControls({
    super.key,
    required this.teleprompter,
    required this.settings,
    required this.onPlayPause,
    required this.onReset,
    required this.onFontSizeChanged,
    required this.onWpmChanged,
    required this.onScrollModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.teleprompterBackground.withOpacity(0.98),
            AppColors.teleprompterBackground.withOpacity(0.8),
            AppColors.teleprompterBackground.withOpacity(0.0),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 滚动进度指示
          _buildProgressBar(),
          const SizedBox(height: 12),

          // 模式切换行
          _buildModeSelector(),
          const SizedBox(height: 12),

          // 根据模式显示不同的控制面板
          if (settings.scrollMode == ScrollMode.auto)
            _buildAutoModeControls()
          else if (settings.scrollMode == ScrollMode.asr)
            _buildAsrModeControls(context)
          else
            _buildManualModeHint(),

          const SizedBox(height: 12),

          // 播放控制行
          _buildPlaybackControls(),
        ],
      ),
    );
  }

  /// 滚动进度条
  Widget _buildProgressBar() {
    final progress = teleprompter.totalChars > 0
        ? (teleprompter.currentIndex + 1) / teleprompter.totalChars
        : 0.0;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).round()}%  ·  ${teleprompter.currentIndex + 1} / ${teleprompter.totalChars} 字',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }

  /// 滚动模式选择器
  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          _buildModeChip(
            icon: Icons.pan_tool,
            label: '手动',
            mode: ScrollMode.manual,
          ),
          _buildModeChip(
            icon: Icons.play_circle,
            label: '自动',
            mode: ScrollMode.auto,
          ),
          _buildModeChip(icon: Icons.mic, label: '语音', mode: ScrollMode.asr),
        ],
      ),
    );
  }

  Widget _buildModeChip({
    required IconData icon,
    required String label,
    required ScrollMode mode,
  }) {
    final isSelected = settings.scrollMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            onScrollModeChanged(mode);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: AppColors.primary.withOpacity(0.5))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 手动模式提示
  Widget _buildManualModeHint() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 14, color: AppColors.textDisabled),
          SizedBox(width: 6),
          Text(
            '手动模式：拖动文本滚动阅读',
            style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }

  /// 自动模式控制面板
  Widget _buildAutoModeControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.speed, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          const Text(
            '速度',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          Expanded(
            child: Slider(
              value: settings.wpm.toDouble(),
              min: AppConstants.minWpm.toDouble(),
              max: AppConstants.maxWpm.toDouble(),
              divisions: 84,
              onChanged: (v) => onWpmChanged(v.round()),
            ),
          ),
          SizedBox(
            width: 55,
            child: Text(
              '${settings.wpm}字/分',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// ASR 模式控制面板
  Widget _buildAsrModeControls(BuildContext context) {
    final asrAvailable = settings.asrModelId.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          // 音量指示
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: teleprompter.isPlaying && teleprompter.rms > 0
                  ? AppColors.primary.withOpacity(0.2)
                  : AppColors.border,
              shape: BoxShape.circle,
            ),
            child: Icon(
              teleprompter.isPlaying && teleprompter.rms > 0
                  ? Icons.mic
                  : Icons.mic_off,
              size: 18,
              color: teleprompter.isPlaying && teleprompter.rms > 0
                  ? AppColors.primary
                  : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asrAvailable
                      ? '模型: ${settings.asrModelName}'
                      : '请先在设置中下载 ASR 模型',
                  style: TextStyle(
                    fontSize: 13,
                    color: asrAvailable
                        ? AppColors.textSecondary
                        : AppColors.warning,
                  ),
                ),
                if (teleprompter.isPlaying)
                  const Text(
                    '正在聆听...',
                    style: TextStyle(fontSize: 11, color: AppColors.primary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 播放控制行
  Widget _buildPlaybackControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 字体大小控制
        IconButton(
          icon: const Icon(Icons.text_decrease, size: 22),
          color: AppColors.textSecondary,
          onPressed: () {
            final newSize = (settings.fontSize - 4).clamp(24.0, 120.0);
            onFontSizeChanged(newSize);
          },
          tooltip: '减小字体',
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            '${settings.fontSize.round()}px',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.text_increase, size: 22),
          color: AppColors.textSecondary,
          onPressed: () {
            final newSize = (settings.fontSize + 4).clamp(24.0, 120.0);
            onFontSizeChanged(newSize);
          },
          tooltip: '增大字体',
        ),

        const Spacer(),

        // 重置按钮
        IconButton(
          icon: const Icon(Icons.replay, size: 28),
          color: AppColors.textSecondary,
          onPressed: onReset,
          tooltip: '重置到开头',
        ),

        const SizedBox(width: 16),

        // 播放/暂停按钮
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              teleprompter.isPlaying ? Icons.pause : Icons.play_arrow,
              size: 36,
            ),
            color: AppColors.background,
            onPressed: onPlayPause,
            iconSize: 36,
          ),
        ),

        const SizedBox(width: 16),
      ],
    );
  }
}
