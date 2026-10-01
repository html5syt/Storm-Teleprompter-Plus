import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// 快速工作区的稿件管理和返回按钮，使用与应用亮暗模式匹配的底色与前景色。
class QuickModeActionButton extends StatelessWidget {
  final String heroTag;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const QuickModeActionButton({
    super.key,
    required this.heroTag,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return FloatingActionButton(
      heroTag: heroTag,
      tooltip: tooltip,
      onPressed: onPressed,
      backgroundColor: Color.alphaBlend(
        primary.withValues(alpha: AppColors.isLight(context) ? 0.12 : 0.2),
        AppColors.surfaceFor(context),
      ),
      foregroundColor: AppColors.textPrimaryFor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderFor(context)),
      ),
      child: Icon(icon),
    );
  }
}
