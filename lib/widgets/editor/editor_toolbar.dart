import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../theme/app_colors.dart';
import 'editor_toolbar_style.dart';

/// 单一横向滚动工具栏；按内容自然排布，不给内置按钮预留空白宽度。
class EditorToolbar extends StatelessWidget {
  final quill.QuillController controller;
  final List<Widget> tools;
  const EditorToolbar({
    super.key,
    required this.controller,
    required this.tools,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    width: double.infinity,
    color: AppColors.surface,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...tools,
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              height: 24,
              child: VerticalDivider(width: 1, color: AppColors.border),
            ),
          ),
          _buildFormatToolbar(context),
        ],
      ),
    ),
  );

  /// 保留 Quill 原有撤销、重做和格式逻辑，只统一外观和间距。
  Widget _buildFormatToolbar(BuildContext context) => quill.QuillSimpleToolbar(
    controller: controller,
    config: quill.QuillSimpleToolbarConfig(
      toolbarIconAlignment: WrapAlignment.start,
      toolbarIconCrossAlignment: WrapCrossAlignment.center,
      toolbarSectionSpacing: EditorToolbarStyle.spacing,
      toolbarRunSpacing: 0,
      buttonOptions: quill.QuillSimpleToolbarButtonOptions(
        base: quill.QuillToolbarBaseButtonOptions(
          iconSize: EditorToolbarStyle.iconSize,
          iconButtonFactor: 1,
          iconTheme: quill.QuillIconTheme(
            iconButtonUnselectedData: quill.IconButtonData(
              style: EditorToolbarStyle.buttonStyle(context),
            ),
            iconButtonSelectedData: quill.IconButtonData(
              style: EditorToolbarStyle.buttonStyle(context, selected: true),
            ),
          ),
        ),
        undoHistory: const quill.QuillToolbarHistoryButtonOptions(
          tooltip: '撤销',
        ),
        redoHistory: const quill.QuillToolbarHistoryButtonOptions(
          tooltip: '重做',
        ),
        bold: const quill.QuillToolbarToggleStyleButtonOptions(tooltip: '加粗'),
        italic: const quill.QuillToolbarToggleStyleButtonOptions(tooltip: '斜体'),
        underLine: const quill.QuillToolbarToggleStyleButtonOptions(
          tooltip: '下划线',
        ),
        strikeThrough: const quill.QuillToolbarToggleStyleButtonOptions(
          tooltip: '删除线',
        ),
        clearFormat: const quill.QuillToolbarClearFormatButtonOptions(
          tooltip: '清除格式',
        ),
      ),
      showDividers: false,
      showFontFamily: false,
      showFontSize: false,
      showSmallButton: false,
      showInlineCode: false,
      showColorButton: false,
      showBackgroundColorButton: false,
      showAlignmentButtons: false,
      showHeaderStyle: false,
      showListNumbers: false,
      showListBullets: false,
      showListCheck: false,
      showCodeBlock: false,
      showQuote: false,
      showIndent: false,
      showLink: false,
      showDirection: false,
      showSearchButton: false,
      showSubscript: false,
      showSuperscript: false,
    ),
  );
}
