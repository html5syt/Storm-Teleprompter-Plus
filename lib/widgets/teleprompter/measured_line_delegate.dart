import 'package:flutter/widgets.dart';

/// 使用已测量的总高度替代懒加载平均值，避免不同字号在滚动末尾改变边界。
class MeasuredLineDelegate extends SliverChildBuilderDelegate {
  final double contentHeight;

  MeasuredLineDelegate(
    super.builder, {
    required int count,
    required this.contentHeight,
  }) : super(childCount: count);

  @override
  double estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) => contentHeight;
}
