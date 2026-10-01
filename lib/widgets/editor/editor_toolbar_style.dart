import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// 编辑器所有工具共用尺寸、边框、颜色和交互状态。
abstract final class EditorToolbarStyle {
  static const double buttonSize = 36;

  /// 字号输入加宽以显示多位数字，高度仍与按钮一致。
  static const double fontSizeInputWidth = 72;
  static const double iconSize = 20;
  static const double spacing = 4;
  static const double radius = 6;

  /// 普通、选中和禁用状态保持相同几何尺寸，避免切换格式时跳动。
  static ButtonStyle buttonStyle(
    BuildContext context, {
    bool selected = false,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return IconButton.styleFrom(
      fixedSize: const Size.square(buttonSize),
      minimumSize: const Size.square(buttonSize),
      maximumSize: const Size.square(buttonSize),
      padding: EdgeInsets.zero,
      iconSize: iconSize,
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: selected ? primary : AppColors.textSecondaryFor(context),
      backgroundColor: selected
          ? primary.withValues(alpha: 0.16)
          : AppColors.surfaceElevatedFor(context),
      disabledForegroundColor: AppColors.textDisabledFor(context),
      disabledBackgroundColor: AppColors.surfaceElevatedFor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      side: BorderSide(
        color: selected
            ? primary.withValues(alpha: 0.65)
            : AppColors.borderFor(context),
      ),
    );
  }

  /// 字号输入与按钮共用底色和圆角，仅聚焦时强调边框。
  static InputDecoration fontSizeDecoration(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: AppColors.borderFor(context)),
    );
    return InputDecoration(
      constraints: const BoxConstraints.tightFor(
        width: fontSizeInputWidth,
        height: buttonSize,
      ),
      hintText: '字号',
      // 字号提示不继承主题字距，保持不同字体下的显示一致。
      hintStyle: TextStyle(
        fontSize: 11,
        letterSpacing: 0,
        color: AppColors.textMutedFor(context),
      ),
      // InputDecorator 会按内容高度而非外层最小高度绘制边框。
      // 非紧凑布局以最小交互高度撑满受约束的 36px，禁用桌面密度缩减。
      isDense: false,
      visualDensity: VisualDensity.standard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      filled: true,
      fillColor: AppColors.surfaceElevatedFor(context),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

/// 自定义工具按钮，与 Quill 内置格式按钮使用同一套样式。
class EditorToolbarButton extends StatelessWidget {
  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  const EditorToolbarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: EditorToolbarStyle.spacing),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: icon,
      style: EditorToolbarStyle.buttonStyle(context, selected: selected),
    ),
  );
}
