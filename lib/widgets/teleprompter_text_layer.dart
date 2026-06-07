import 'package:flutter/material.dart';
import '../models/script_character.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';

/// 按行吸附的滚动物理效果
///
/// 鼠标滚轮或触摸松手后，自动吸附到最近的行边界。
/// 行高 = fontSize * lineHeight。
class LineSnapScrollPhysics extends ScrollPhysics {
  final double lineHeight;

  const LineSnapScrollPhysics({required this.lineHeight, super.parent});

  @override
  LineSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return LineSnapScrollPhysics(
      lineHeight: lineHeight,
      parent: buildParent(ancestor),
    );
  }

  double _snapToLine(double offset) {
    if (lineHeight <= 0) return offset;
    return (offset / lineHeight).roundToDouble() * lineHeight;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // 如果行高无效，使用默认行为
    if (lineHeight <= 0) {
      return super.createBallisticSimulation(position, velocity);
    }

    final target = _snapToLine(position.pixels);

    // 如果已经在行边界附近，不需要动画
    if ((target - position.pixels).abs() < 1.0) {
      return null;
    }

    // 使用弹簧动画吸附到目标行
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity * 0.3, // 减小速度以避免跳过太多行
      tolerance: Tolerance(
        velocity: 1.0 / (0.05 * position.viewportDimension),
        distance: 1.0,
      ),
    );
  }
}

/// 提词器文本渲染层
///
/// 逐字符渲染文本，支持格式保留、已读高亮、镜像翻转。
/// 使用空气垫设计确保首尾行可滚动到阅读线位置。
/// 使用按行吸附的滚动物理效果。
class TeleprompterTextLayer extends StatefulWidget {
  final ScrollController scrollController;
  final List<ScriptLine> lines;
  final int currentIndex;
  final double fontSize;
  final double lineHeight;
  final bool mirrorMode;
  final double paddingX; // 水平边距百分比（0~40）
  final double readingLineOffset; // 阅读线偏移比例（0.0~1.0）
  final ScrollPhysics? physics; // 自定义物理效果，null 则使用默认 LineSnapScrollPhysics
  final void Function(int rawIndex)? onCharTap;

  // ─── 文字设置 ────────────────────────────────────────
  final String fontFamily;
  final bool grayReadChars;
  final int textColor; // 0 = 自动, 其他 = ARGB
  final double letterSpacing;
  final bool highlightCurrentChar;
  final bool defaultBold;

  const TeleprompterTextLayer({
    super.key,
    required this.scrollController,
    required this.lines,
    required this.currentIndex,
    required this.fontSize,
    required this.lineHeight,
    required this.mirrorMode,
    this.paddingX = 5.0,
    this.readingLineOffset = 0.25,
    this.physics,
    this.onCharTap,
    this.fontFamily = '',
    this.grayReadChars = true,
    this.textColor = 0,
    this.letterSpacing = 0.0,
    this.highlightCurrentChar = false,
    this.defaultBold = false,
  });

  @override
  State<TeleprompterTextLayer> createState() => _TeleprompterTextLayerState();
}

class _TeleprompterTextLayerState extends State<TeleprompterTextLayer> {
  // 当前字符的 GlobalKey（仅保存当前字符，不保存所有字符）
  final GlobalKey _currentCharKey = GlobalKey();

  @override
  void didUpdateWidget(TeleprompterTextLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex &&
        widget.currentIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentChar();
      });
    } else if (widget.readingLineOffset != oldWidget.readingLineOffset &&
        widget.currentIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentChar();
      });
    }
  }

  /// 滚动到当前高亮字符位置
  ///
  /// 使用阅读线位置作为目标，将当前字符所在行滚动到阅读线处。
  void _scrollToCurrentChar() {
    if (!widget.scrollController.hasClients) return;
    if (widget.currentIndex < 0) return;

    // 找到当前字符所在的行号
    int charCount = 0;
    int targetLine = 0;
    for (int i = 0; i < widget.lines.length; i++) {
      final lineLen = widget.lines[i].characters.length;
      if (widget.currentIndex < charCount + lineLen) {
        targetLine = i;
        break;
      }
      charCount += lineLen;
    }

    // 每行的实际高度：文本 fontSize * lineHeight + Padding(vertical:2) 上下各2px
    final perLineHeight = widget.fontSize * widget.lineHeight + 4;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final defaultRatio = isMobile ? 0.30 : 0.25;
    final readingLineY =
        screenHeight *
        (widget.readingLineOffset > 0
            ? widget.readingLineOffset
            : defaultRatio);

    final topPad = screenHeight * (AppConstants.topPaddingVh / 100);

    // 计算目标滚动位置：
    // 目标行在全局滚动视图中的位置 = topPad + targetLine * perLineHeight
    // 要使该行对齐到阅读线：scrollOffset = topPad + targetLine * perLineHeight - readingLineY
    final targetScrollOffset =
        topPad + targetLine * perLineHeight - readingLineY;

    // 按行吸附
    final snappedOffset =
        (targetScrollOffset / perLineHeight).roundToDouble() * perLineHeight;

    widget.scrollController.animateTo(
      snappedOffset.clamp(
        0.0,
        widget.scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveLineHeight = widget.fontSize * widget.lineHeight;
    // 每行实际高度（含 Padding vertical:2）
    final perLineHeight = effectiveLineHeight + 4;
    // 水平边距：基准 + paddingX%
    final isMobile = screenWidth < 600;
    final basePadding = isMobile ? 16.0 : 64.0;
    final extraPadding = screenWidth * widget.paddingX / 100;
    final horizontalPadding = basePadding + extraPadding;

    return Transform(
      alignment: Alignment.center,
      transform: widget.mirrorMode
          ? (Matrix4.identity()..setEntry(0, 0, -1.0))
          : Matrix4.identity(),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          controller: widget.scrollController,
          physics:
              widget.physics ??
              LineSnapScrollPhysics(lineHeight: perLineHeight),
          padding: EdgeInsets.only(
            // 顶部空气垫：确保第一句可以滚动到阅读线
            top: screenHeight * (AppConstants.topPaddingVh / 100),
            // 底部空气垫：确保最后一句可以滚动到阅读线
            bottom: screenHeight * (AppConstants.bottomPaddingVh / 100),
            left: horizontalPadding,
            right: horizontalPadding,
          ),
          child: _buildTextContent(),
        ),
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
      children: List.generate(widget.lines.length, (i) {
        final line = widget.lines[i];
        return _buildLine(line);
      }),
    );
  }

  /// 构建单行文本（使用 RichText + TextSpan 提升性能）
  Widget _buildLine(ScriptLine line) {
    if (line.characters.isEmpty) {
      return SizedBox(height: widget.fontSize * widget.lineHeight);
    }

    final textColor = widget.textColor != 0
        ? Color(widget.textColor)
        : AppColors.textPrimary;
    final readColor = widget.grayReadChars
        ? textColor.withValues(alpha: 0.6)
        : textColor;
    final baseWeight = widget.defaultBold ? FontWeight.w700 : FontWeight.w400;
    final boldWeight = widget.defaultBold ? FontWeight.w900 : FontWeight.w700;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        onTap: () {
          // RichText 不支持逐字点击，点击行定位到该行第一个字符
          if (line.characters.isNotEmpty) {
            widget.onCharTap?.call(line.characters.first.rawIndex);
          }
        },
        child: RichText(
          text: TextSpan(
            children: line.characters.map((char) {
              final isRead = char.rawIndex <= widget.currentIndex;
              final isCurrent = char.rawIndex == widget.currentIndex;
              final doHighlight = isCurrent && widget.highlightCurrentChar;
              final effectiveFontSize =
                  widget.fontSize * (char.fontSizeRatio ?? 1.0);

              // 为当前字符设置 key 用于滚动定位
              if (isCurrent) {
                _currentCharKey; // 保持引用触发重建
              }

              final style = TextStyle(
                fontSize: effectiveFontSize,
                height: widget.lineHeight,
                fontWeight: doHighlight
                    ? boldWeight
                    : (char.bold ? boldWeight : baseWeight),
                fontStyle: char.italic ? FontStyle.italic : FontStyle.normal,
                decoration: TextDecoration.none,
                color: doHighlight
                    ? textColor
                    : (isRead ? readColor : textColor),
                fontFamily: widget.fontFamily.isNotEmpty
                    ? widget.fontFamily
                    : null,
                letterSpacing: widget.letterSpacing,
                backgroundColor: char.backgroundColor != null
                    ? Color(char.backgroundColor!).withValues(alpha: 0.3)
                    : null,
              );

              return TextSpan(text: char.char, style: style);
            }).toList(),
          ),
        ),
      ),
    );
  }

}
