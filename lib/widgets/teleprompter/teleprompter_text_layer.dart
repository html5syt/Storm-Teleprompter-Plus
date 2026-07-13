import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../models/script_character.dart';
import '../../theme/app_colors.dart';
import '../../utils/constants.dart';

/// 提词器文本渲染层（懒加载 + 实际行高定位）。
///
/// - [SliverList.builder] 只构建可见正文行，控制大型稿件 Widget 数量。
/// - 用 [TextPainter] 按当前宽度和文字样式缓存每个逻辑行的实际高度。
/// - 当前字滚动定位使用累计实际高度，避免长行换行、富文本字号、空行导致
///   当前字偏离阅读区域框中心行。
class TeleprompterTextLayer extends StatefulWidget {
  final ScrollController scrollController;
  final List<ScriptLine> lines;
  final int currentIndex;
  final double fontSize;
  final double lineHeight;
  final bool mirrorMode;
  final double paddingX;
  final double readingLineOffset;
  final bool autoFollow;
  final ScrollPhysics? physics;
  final void Function(int rawIndex)? onCharTap;
  final void Function(int rawIndex)? onReadingLineChanged;

  final String teleprompterFontFamily;
  final bool grayReadChars;
  final int textColor;
  final double letterSpacing;
  final bool highlightCurrentChar;
  final bool defaultBold;
  final bool underlineCurrentChar;

  const TeleprompterTextLayer({
    super.key,
    required this.scrollController,
    required this.lines,
    required this.currentIndex,
    required this.fontSize,
    required this.lineHeight,
    required this.mirrorMode,
    this.autoFollow = false,
    this.paddingX = 5.0,
    this.readingLineOffset = 0.5,
    this.physics,
    this.onCharTap,
    this.onReadingLineChanged,
    this.teleprompterFontFamily = '',
    this.grayReadChars = true,
    this.textColor = 0,
    this.letterSpacing = 0.0,
    this.highlightCurrentChar = false,
    this.defaultBold = false,
    this.underlineCurrentChar = false,
  });

  @override
  State<TeleprompterTextLayer> createState() => TeleprompterTextLayerState();
}

class TeleprompterTextLayerState extends State<TeleprompterTextLayer> {
  static const double _lineVerticalPadding = 2.0;

  int _lastScrolledToIndex = -2;
  int _lastReportedReadingLine = -2;
  int _scrollRequestId = 0;
  bool _isProgrammaticScroll = false;

  bool _metricsDirty = true;
  double? _lastTextWidth;
  TextDirection? _lastTextDirection;
  final List<double> _lineHeights = <double>[];
  final List<double> _lineTops = <double>[];
  double _contentHeight = 0;

  @override
  void didUpdateWidget(TeleprompterTextLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final metricsChanged =
        widget.lines != oldWidget.lines ||
        widget.fontSize != oldWidget.fontSize ||
        widget.lineHeight != oldWidget.lineHeight ||
        widget.letterSpacing != oldWidget.letterSpacing ||
        widget.paddingX != oldWidget.paddingX ||
        widget.defaultBold != oldWidget.defaultBold ||
        widget.teleprompterFontFamily != oldWidget.teleprompterFontFamily;

    if (metricsChanged) {
      _metricsDirty = true;
      _lastScrolledToIndex = -2;
      _lastReportedReadingLine = -2;
    }

    final indexChanged = widget.currentIndex != oldWidget.currentIndex;
    final offsetChanged =
        widget.readingLineOffset != oldWidget.readingLineOffset;

    if (indexChanged || offsetChanged || metricsChanged) {
      if (widget.currentIndex != _lastScrolledToIndex ||
          offsetChanged ||
          metricsChanged) {
        _lastScrolledToIndex = widget.currentIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollToCurrentChar(animate: true);
            if (metricsChanged) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _scrollToCurrentChar(animate: true);
              });
            }
          }
        });
      }
    }
  }

  double _horizontalPadding(double viewportWidth) {
    final isMobile = viewportWidth < LayoutConstants.compactBreakpoint;
    final basePadding = isMobile
        ? TeleprompterConstants.mobileHorizontalPadding
        : TeleprompterConstants.desktopHorizontalPadding;
    final extraPadding = viewportWidth * widget.paddingX / 100;
    return basePadding + extraPadding;
  }

  double _textWidthForViewport(double viewportWidth) {
    final horizontalPadding = _horizontalPadding(viewportWidth);
    return (viewportWidth - horizontalPadding * 2)
        .clamp(0.0, viewportWidth)
        .toDouble();
  }

  double _effectiveReadingLineRatio(double viewportWidth) {
    if (widget.readingLineOffset > 0) {
      return widget.readingLineOffset.clamp(0.0, 1.0).toDouble();
    }
    return viewportWidth < LayoutConstants.compactBreakpoint
        ? TeleprompterConstants.readingLineRatioMobile
        : TeleprompterConstants.readingLineRatioDesktop;
  }

  double _topPad(double viewportHeight) =>
      viewportHeight * (TeleprompterConstants.topPaddingVh / 100);

  double _bottomPad(double viewportHeight) =>
      viewportHeight * (TeleprompterConstants.bottomPaddingVh / 100);

  double _readingLineY(double viewportHeight, double viewportWidth) =>
      viewportHeight * _effectiveReadingLineRatio(viewportWidth);

  int _findLineForRawIndex(int rawIndex) {
    if (rawIndex < 0 || widget.lines.isEmpty) return 0;

    var lastNonEmpty = 0;
    for (var i = 0; i < widget.lines.length; i++) {
      final chars = widget.lines[i].characters;
      if (chars.isEmpty) continue;

      lastNonEmpty = i;
      if (rawIndex <= chars.last.rawIndex) return i;
    }
    return lastNonEmpty;
  }

  int _charOffsetInLine(int lineIndex, int rawIndex) {
    final chars = widget.lines[lineIndex].characters;
    if (chars.isEmpty) return 0;

    for (var i = 0; i < chars.length; i++) {
      if (rawIndex <= chars[i].rawIndex) return i;
    }
    return chars.length - 1;
  }

  TextPainter _layoutLinePainter(
    ScriptLine line,
    double textWidth,
    TextDirection textDirection,
  ) {
    return TextPainter(
      text: TextSpan(children: _buildTextSpans(line, forMeasurement: true)),
      textDirection: textDirection,
    )..layout(maxWidth: textWidth);
  }

  double _visualRowCenterForRawIndex(
    int lineIndex,
    int rawIndex,
    double textWidth,
    TextDirection textDirection,
  ) {
    final line = widget.lines[lineIndex];
    if (line.characters.isEmpty) {
      return _lineHeights[lineIndex] / 2;
    }

    final painter = _layoutLinePainter(line, textWidth, textDirection);
    final charOffset = _charOffsetInLine(lineIndex, rawIndex);
    final selectionEnd = (charOffset + 1).clamp(0, line.characters.length);
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: charOffset, extentOffset: selectionEnd),
    );
    final caretOffset = painter.getOffsetForCaret(
      TextPosition(offset: charOffset),
      Rect.zero,
    );
    final sampleY = boxes.isNotEmpty
        ? (boxes.first.top + boxes.first.bottom) / 2
        : caretOffset.dy;

    var rowCenter = caretOffset.dy + painter.preferredLineHeight / 2;
    for (final metric in painter.computeLineMetrics()) {
      final top = metric.baseline - metric.ascent;
      final bottom = top + metric.height;
      if (sampleY >= top - 0.5 && sampleY <= bottom + 0.5) {
        rowCenter = top + metric.height / 2;
        break;
      }
    }

    painter.dispose();
    return (rowCenter + _lineVerticalPadding)
        .clamp(0.0, _lineHeights[lineIndex])
        .toDouble();
  }

  void _ensureLineMetrics(double textWidth, TextDirection textDirection) {
    final widthChanged =
        _lastTextWidth == null || (_lastTextWidth! - textWidth).abs() > 0.5;
    final directionChanged = _lastTextDirection != textDirection;

    if (!_metricsDirty &&
        !widthChanged &&
        !directionChanged &&
        _lineHeights.length == widget.lines.length) {
      return;
    }

    _lineHeights.clear();
    _lineTops.clear();

    var cursor = 0.0;
    for (final line in widget.lines) {
      _lineTops.add(cursor);
      final height = _measureLineHeight(line, textWidth, textDirection);
      _lineHeights.add(height);
      cursor += height;
    }

    _contentHeight = cursor;
    _lastTextWidth = textWidth;
    _lastTextDirection = textDirection;
    _metricsDirty = false;
  }

  double _measureLineHeight(
    ScriptLine line,
    double textWidth,
    TextDirection textDirection,
  ) {
    if (line.characters.isEmpty) {
      return widget.fontSize * widget.lineHeight;
    }

    final painter = _layoutLinePainter(line, textWidth, textDirection);

    final height = painter.height + _lineVerticalPadding * 2;
    painter.dispose();
    return height;
  }

  int _findLineForContentOffset(double contentOffset) {
    if (_lineTops.isEmpty) return 0;

    final target = contentOffset
        .clamp(0.0, _contentHeight <= 0 ? 0.0 : _contentHeight)
        .toDouble();
    var low = 0;
    var high = _lineTops.length - 1;

    while (low <= high) {
      final mid = low + ((high - low) >> 1);
      final top = _lineTops[mid];
      final bottom = top + _lineHeights[mid];

      if (target < top) {
        high = mid - 1;
      } else if (target >= bottom) {
        low = mid + 1;
      } else {
        return mid;
      }
    }

    return low.clamp(0, _lineTops.length - 1).toInt();
  }

  int? _rawIndexForContentOffset(
    double contentOffset,
    double textWidth,
    TextDirection textDirection,
    double x,
  ) {
    if (widget.lines.isEmpty || _lineTops.isEmpty) return null;

    final lineIndex = _findLineForContentOffset(contentOffset);
    final line = widget.lines[lineIndex];
    if (line.characters.isEmpty) return null;

    final painter = _layoutLinePainter(line, textWidth, textDirection);
    final localY = (contentOffset - _lineTops[lineIndex] - _lineVerticalPadding)
        .clamp(0.0, painter.height)
        .toDouble();
    final localX = x.clamp(0.0, textWidth).toDouble();
    final position = painter.getPositionForOffset(Offset(localX, localY));
    painter.dispose();

    final charOffset = position.offset
        .clamp(0, line.characters.length - 1)
        .toInt();
    return line.characters[charOffset].rawIndex;
  }

  int? rawIndexForVisualLineMove(int direction) {
    if (direction == 0 || widget.lines.isEmpty) return null;

    final viewportWidth =
        context.size?.width ?? MediaQuery.of(context).size.width;
    final textWidth = _textWidthForViewport(viewportWidth);
    final textDirection = Directionality.of(context);
    _ensureLineMetrics(textWidth, textDirection);
    if (_lineHeights.isEmpty) return null;

    if (widget.currentIndex < 0) {
      for (final line in widget.lines) {
        if (line.characters.isNotEmpty) return line.characters.first.rawIndex;
      }
      return null;
    }

    final currentLine = _findLineForRawIndex(widget.currentIndex);
    final safeLine = currentLine.clamp(0, _lineHeights.length - 1).toInt();
    final line = widget.lines[safeLine];
    if (line.characters.isEmpty) return null;

    final painter = _layoutLinePainter(line, textWidth, textDirection);
    final charOffset = _charOffsetInLine(safeLine, widget.currentIndex);
    final selectionEnd = (charOffset + 1).clamp(0, line.characters.length);
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: charOffset, extentOffset: selectionEnd),
    );
    final caretOffset = painter.getOffsetForCaret(
      TextPosition(offset: charOffset),
      Rect.zero,
    );
    final sampleY = boxes.isNotEmpty
        ? (boxes.first.top + boxes.first.bottom) / 2
        : caretOffset.dy;
    var currentMetricHeight = painter.preferredLineHeight;
    var currentRowCenter = caretOffset.dy + currentMetricHeight / 2;
    for (final metric in painter.computeLineMetrics()) {
      final top = metric.baseline - metric.ascent;
      final bottom = top + metric.height;
      if (sampleY >= top - 0.5 && sampleY <= bottom + 0.5) {
        currentMetricHeight = metric.height;
        currentRowCenter = top + metric.height / 2;
        break;
      }
    }
    final currentX = boxes.isNotEmpty
        ? (boxes.first.left + boxes.first.right) / 2
        : caretOffset.dx;
    painter.dispose();

    final targetContentY =
        _lineTops[safeLine] +
        currentRowCenter +
        direction * currentMetricHeight;
    final targetLine = _findLineForContentOffset(targetContentY);
    final target = widget.lines[targetLine];
    if (target.characters.isEmpty) return null;

    return _rawIndexForContentOffset(
      targetContentY,
      textWidth,
      textDirection,
      currentX,
    );
  }

  void scrollToCurrentChar({bool animate = true}) {
    _scrollToCurrentChar(animate: animate);
  }

  void _animateToOffset(double targetOffset, Duration duration) {
    if (!widget.scrollController.hasClients) return;

    final requestId = ++_scrollRequestId;
    _isProgrammaticScroll = true;

    unawaited(
      widget.scrollController
          .animateTo(
            targetOffset,
            duration: duration,
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (!mounted || requestId != _scrollRequestId) return;
            _isProgrammaticScroll = false;
          }),
    );
  }

  void _jumpToOffset(double targetOffset) {
    if (!widget.scrollController.hasClients) return;

    _scrollRequestId++;
    _isProgrammaticScroll = true;
    widget.scrollController.jumpTo(targetOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _isProgrammaticScroll = false;
    });
  }

  void _scrollToCurrentChar({bool animate = true}) {
    if (!widget.scrollController.hasClients) return;

    final pos = widget.scrollController.position;
    final viewportHeight = pos.viewportDimension;
    final viewportWidth =
        context.size?.width ?? MediaQuery.of(context).size.width;
    final maxScroll = pos.maxScrollExtent;

    if (widget.currentIndex < 0 || widget.lines.isEmpty) {
      if (animate) {
        _animateToOffset(0, const Duration(milliseconds: 200));
      } else {
        _jumpToOffset(0);
      }
      return;
    }

    final textWidth = _textWidthForViewport(viewportWidth);
    final textDirection = Directionality.of(context);
    _ensureLineMetrics(textWidth, textDirection);
    if (_lineHeights.isEmpty) return;

    final targetLine = _findLineForRawIndex(widget.currentIndex);
    final safeLine = targetLine.clamp(0, _lineHeights.length - 1).toInt();
    final rowCenter =
        _topPad(viewportHeight) +
        _lineTops[safeLine] +
        _visualRowCenterForRawIndex(
          safeLine,
          widget.currentIndex,
          textWidth,
          textDirection,
        );
    final targetOffset =
        (rowCenter - _readingLineY(viewportHeight, viewportWidth))
            .clamp(0.0, maxScroll)
            .toDouble();

    final currentOffset = pos.pixels;
    final offsetDelta = (targetOffset - currentOffset).abs();
    if (offsetDelta <= 0.5) return;

    final shouldAnimate = animate || (widget.autoFollow && offsetDelta > 1.0);

    if (shouldAnimate) {
      _animateToOffset(
        targetOffset,
        Duration(milliseconds: widget.autoFollow ? 150 : 190),
      );
    } else {
      _jumpToOffset(targetOffset);
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isProgrammaticScroll || widget.onReadingLineChanged == null) {
      return false;
    }
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification &&
        notification is! UserScrollNotification) {
      return false;
    }

    final viewportHeight = notification.metrics.viewportDimension;
    final viewportWidth =
        context.size?.width ?? MediaQuery.of(context).size.width;
    final contentY =
        notification.metrics.pixels +
        _readingLineY(viewportHeight, viewportWidth) -
        _topPad(viewportHeight);
    final textWidth = _textWidthForViewport(viewportWidth);
    final lineIndex = _findLineForContentOffset(contentY);
    final rawIndex = _rawIndexForContentOffset(
      contentY,
      textWidth,
      Directionality.of(context),
      0,
    );

    final isScrollEnd =
        notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle);
    if (rawIndex == null) return false;

    if (lineIndex == _lastReportedReadingLine &&
        rawIndex == widget.currentIndex &&
        !isScrollEnd) {
      return false;
    }

    if (rawIndex == widget.currentIndex) {
      if (isScrollEnd) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToCurrentChar();
        });
      }
      return false;
    }

    _lastReportedReadingLine = lineIndex;
    _lastScrolledToIndex = isScrollEnd ? -2 : rawIndex;
    _scrollRequestId++;
    _isProgrammaticScroll = false;
    widget.onReadingLineChanged?.call(rawIndex);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screenWidth;
        final horizontalPadding = _horizontalPadding(viewportWidth);
        final textWidth = _textWidthForViewport(viewportWidth);

        _ensureLineMetrics(textWidth, Directionality.of(context));

        return Transform(
          alignment: Alignment.center,
          transform: widget.mirrorMode
              ? (Matrix4.identity()..setEntry(0, 0, -1.0))
              : Matrix4.identity(),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: CustomScrollView(
                controller: widget.scrollController,
                physics: widget.physics ?? const ClampingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: _topPad(screenHeight)),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    sliver: widget.lines.isEmpty
                        ? SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: screenHeight * 0.2,
                                ),
                                child: const Text(
                                  '暂无内容',
                                  style: TextStyle(
                                    color: AppColors.textDisabled,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : SliverList.builder(
                            itemCount: widget.lines.length,
                            itemBuilder: (context, index) {
                              return _buildLine(widget.lines[index], textWidth);
                            },
                          ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: _bottomPad(screenHeight)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<TextSpan> _buildTextSpans(
    ScriptLine line, {
    required bool forMeasurement,
  }) {
    final textColor = widget.textColor != 0
        ? Color(widget.textColor)
        : const Color(0xFFFFFFFF);
    final baseWeight = widget.defaultBold ? FontWeight.w700 : FontWeight.w400;
    final boldWeight = widget.defaultBold ? FontWeight.w900 : FontWeight.w700;

    return line.characters.map((char) {
      final isRead = !forMeasurement && char.rawIndex <= widget.currentIndex;
      final isCurrent = !forMeasurement && char.rawIndex == widget.currentIndex;
      final doHighlight = isCurrent && widget.highlightCurrentChar;
      final effectiveFontSize =
          char.fontSizePx ?? widget.fontSize * (char.fontSizeRatio ?? 1.0);
      final effectiveTextColor = char.textColor != null
          ? Color(char.textColor!)
          : textColor;
      final effectiveReadColor = widget.grayReadChars
          ? effectiveTextColor.withValues(alpha: 0.6)
          : effectiveTextColor;

      final style = TextStyle(
        fontSize: effectiveFontSize,
        height: widget.lineHeight,
        fontWeight: doHighlight
            ? boldWeight
            : (char.bold ? boldWeight : baseWeight),
        fontStyle: char.italic ? FontStyle.italic : FontStyle.normal,
        decoration: (isCurrent && widget.underlineCurrentChar)
            ? TextDecoration.underline
            : (char.underline ? TextDecoration.underline : TextDecoration.none),
        decorationColor: effectiveTextColor,
        color: doHighlight
            ? effectiveTextColor
            : (isRead ? effectiveReadColor : effectiveTextColor),
        fontFamily: widget.teleprompterFontFamily.isNotEmpty
            ? widget.teleprompterFontFamily
            : null,
        letterSpacing: widget.letterSpacing,
        backgroundColor: char.backgroundColor != null
            ? Color(char.backgroundColor!).withValues(alpha: 0.3)
            : null,
      );

      return TextSpan(text: char.char, style: style);
    }).toList();
  }

  Widget _buildLine(ScriptLine line, double textWidth) {
    if (line.characters.isEmpty) {
      return SizedBox(
        height: widget.fontSize * widget.lineHeight + _lineVerticalPadding * 2,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _lineVerticalPadding),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (details) {
            final painter = _layoutLinePainter(
              line,
              textWidth,
              Directionality.of(context),
            );
            final position = painter.getPositionForOffset(
              details.localPosition,
            );
            painter.dispose();

            final charOffset = position.offset
                .clamp(0, line.characters.length - 1)
                .toInt();
            widget.onCharTap?.call(line.characters[charOffset].rawIndex);
          },
          child: RepaintBoundary(
            child: RichText(
              text: TextSpan(
                children: _buildTextSpans(line, forMeasurement: false),
              ),
              softWrap: true,
              overflow: TextOverflow.clip,
            ),
          ),
        ),
      ),
    );
  }
}
