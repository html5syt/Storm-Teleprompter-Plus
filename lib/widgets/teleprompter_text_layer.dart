import 'package:flutter/material.dart';
import '../models/script_character.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';

/// 提词器文本渲染层
///
/// 逐字符渲染文本，支持格式保留、已读高亮、镜像翻转。
/// 使用空气垫设计确保首尾行可滚动到阅读线位置。
class TeleprompterTextLayer extends StatefulWidget {
  final ScrollController scrollController;
  final List<ScriptLine> lines;
  final int currentIndex;
  final double fontSize;
  final double lineHeight;
  final bool mirrorMode;

  const TeleprompterTextLayer({
    super.key,
    required this.scrollController,
    required this.lines,
    required this.currentIndex,
    required this.fontSize,
    required this.lineHeight,
    required this.mirrorMode,
  });

  @override
  State<TeleprompterTextLayer> createState() => _TeleprompterTextLayerState();
}

class _TeleprompterTextLayerState extends State<TeleprompterTextLayer> {
  // 用于记录每个字符的 GlobalKey，便于滚动定位
  final Map<int, GlobalKey> _charKeys = {};

  @override
  void didUpdateWidget(TeleprompterTextLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex &&
        widget.currentIndex >= 0) {
      // 当前索引变化时，滚动到对应位置
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentChar();
      });
    }
  }

  /// 滚动到当前高亮字符位置
  void _scrollToCurrentChar() {
    final key = _charKeys[widget.currentIndex];
    if (key == null) return;

    final context = key.currentContext;
    if (context == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return;

    final charPosition = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(this.context).size.height;
    final screenWidth = MediaQuery.of(this.context).size.width;
    final isMobile = screenWidth < 600;

    // 阅读线位置
    final readingLineY =
        screenHeight *
        (isMobile
            ? AppConstants.readingLineRatioMobile
            : AppConstants.readingLineRatioDesktop);

    final currentScrollOffset = widget.scrollController.offset;

    // 计算目标滚动位置
    final targetScrollOffset =
        currentScrollOffset + charPosition.dy - readingLineY;

    // 平滑滚动
    if (widget.scrollController.hasClients) {
      widget.scrollController.animateTo(
        targetScrollOffset.clamp(
          0.0,
          widget.scrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Transform(
      alignment: Alignment.center,
      transform: widget.mirrorMode
          ? (Matrix4.identity()..setEntry(0, 0, -1.0))
          : Matrix4.identity(),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          // 顶部空气垫：确保第一句可以滚动到阅读线
          top: screenHeight * (AppConstants.topPaddingVh / 100),
          // 底部空气垫：确保最后一句可以滚动到阅读线
          bottom: screenHeight * (AppConstants.bottomPaddingVh / 100),
          left: 24,
          right: 24,
        ),
        child: _buildTextContent(),
      ),
    );
  }

  /// 构建文本内容
  Widget _buildTextContent() {
    if (widget.lines.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).size.height * 0.2,
          ),
          child: const Text(
            '暂无内容',
            style: TextStyle(color: AppColors.textDisabled, fontSize: 18),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.lines.map((line) => _buildLine(line)).toList(),
    );
  }

  /// 构建单行文本
  Widget _buildLine(ScriptLine line) {
    if (line.characters.isEmpty) {
      return SizedBox(height: widget.fontSize * widget.lineHeight);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Wrap(
        children: line.characters.map((char) => _buildChar(char)).toList(),
      ),
    );
  }

  /// 构建单个字符
  Widget _buildChar(ScriptCharacter character) {
    final isRead = character.rawIndex <= widget.currentIndex;
    final isCurrent = character.rawIndex == widget.currentIndex;

    // 获取或创建该字符的 key
    final key = _charKeys.putIfAbsent(character.rawIndex, () => GlobalKey());

    final effectiveFontSize =
        widget.fontSize * (character.fontSizeRatio ?? 1.0);

    return GestureDetector(
      onTap: () {
        // 点击字符跳转到该位置
        // 通过回调通知 Provider 更新索引
      },
      child: Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Text(
          character.char,
          style: TextStyle(
            fontSize: effectiveFontSize,
            height: widget.lineHeight,
            fontWeight: character.bold ? FontWeight.w700 : FontWeight.w400,
            fontStyle: character.italic ? FontStyle.italic : FontStyle.normal,
            decoration: _getTextDecoration(character),
            decorationColor: AppColors.textPrimary,
            color: isCurrent
                ? AppColors.primary
                : isRead
                ? AppColors.textPrimary.withOpacity(0.7)
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  /// 获取文字装饰（下划线、删除线）
  TextDecoration? _getTextDecoration(ScriptCharacter character) {
    final decorations = <TextDecoration>[];
    if (character.underline) decorations.add(TextDecoration.underline);
    if (character.strikeThrough) decorations.add(TextDecoration.lineThrough);
    if (decorations.isEmpty) return null;
    if (decorations.length == 1) return decorations.first;
    return TextDecoration.combine(decorations);
  }
}
