import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'layout_algorithm.dart';

/// 网格布局算法实现
/// 支持横向和纵向滚动的网格布局，类似 GridView
class GridLayoutAlgorithm extends LayoutAlgorithm {
  /// 交叉轴方向的 span 数量
  /// - 纵向滚动时：spanCount 表示列数
  /// - 横向滚动时：spanCount 表示行数
  final int spanCount;

  /// 交叉轴方向的间距
  /// - 纵向滚动时：列间距
  /// - 横向滚动时：行间距
  final double crossAxisSpacing;

  /// 主轴方向的间距
  /// - 纵向滚动时：行间距
  /// - 横向滚动时：列间距
  final double mainAxisSpacing;

  /// 主轴方向与容器边缘的间距
  /// - 纵向滚动时：上下边距
  /// - 横向滚动时：左右边距
  final double mainAxisPadding;

  /// 交叉轴方向与容器边缘的间距
  /// - 纵向滚动时：左右边距
  /// - 横向滚动时：上下边距
  final double crossAxisPadding;

  /// 滚动方向
  final Axis scrollDirection;

  GridLayoutAlgorithm({
    this.spanCount = 3,
    this.crossAxisSpacing = 8.0,
    this.mainAxisSpacing = 8.0,
    this.mainAxisPadding = 0.0,
    this.crossAxisPadding = 0.0,
    this.scrollDirection = Axis.vertical,
  });

  /// 获取列数（纵向滚动）或行数（横向滚动）
  int get columnCount => scrollDirection == Axis.vertical ? spanCount : 0;
  
  /// 获取行数（横向滚动）或列数（纵向滚动）
  int get rowCount => scrollDirection == Axis.horizontal ? spanCount : 0;

  @override
  double computeMaxScrollOffset({
    required double itemExtent,
    required int itemCount,
    required double viewportExtent,
  }) {
    if (itemCount == 0) return 0.0;
    
    final int lastIndex = itemCount - 1;
    final int lastMainAxisIndex = lastIndex ~/ spanCount;
    // 修复：需要加上最后一个 item 的 itemExtent
    final result = mainAxisPadding + lastMainAxisIndex * (itemExtent + mainAxisSpacing) + itemExtent;
    
    return result;
  }

  @override
  LayoutParams getLayoutParamsForPosition({
    required int index,
    required double scrollOffset,
    required double mainAxisExtent,
    required double crossAxisExtent,
    required double itemWidth,
    required double itemHeight,
    required int itemCount,
    required EdgeInsetsGeometry padding,
    bool reverseLayout = false,
    required TextDirection textDirection,
    required Axis scrollDirection,
  }) {
    final itemExtent = scrollDirection == Axis.horizontal ? itemWidth : itemHeight;
    final startTime = DateTime.now();
    
    // 解析 padding 为具体的 EdgeInsets，使用实际的 textDirection
    final resolvedPadding = padding.resolve(textDirection);
    
    if (scrollDirection == Axis.vertical) {
      // 纵向滚动：按行列布局
      return _getVerticalLayoutParams(
        index: index,
        scrollOffset: scrollOffset,
        containerWidth: mainAxisExtent,
        containerHeight: crossAxisExtent,
        itemExtent: itemExtent,
        startTime: startTime,
        resolvedPadding: resolvedPadding,
      );
    } else {
      // 横向滚动：按列行布局
      return _getHorizontalLayoutParams(
        index: index,
        scrollOffset: scrollOffset,
        containerWidth: mainAxisExtent,
        containerHeight: crossAxisExtent,
        itemExtent: itemExtent,
        startTime: startTime,
        resolvedPadding: resolvedPadding,
      );
    }
  }

  LayoutParams _getVerticalLayoutParams({
    required int index,
    required double scrollOffset,
    required double containerWidth,
    required double containerHeight,
    required double itemExtent,
    required DateTime startTime,
    required EdgeInsets resolvedPadding,
  }) {
    final int row = index ~/ spanCount;
    final int column = index % spanCount;

    final double totalCrossAxisSpacing = crossAxisSpacing * (spanCount - 1);
    final double availableWidth = containerWidth - totalCrossAxisSpacing - crossAxisPadding * 2;
    final double cellWidth = availableWidth / spanCount;
    final double cellHeight = itemExtent;

    // 使用传入的 padding.left 和内部的 crossAxisPadding
    final double left = resolvedPadding.left + crossAxisPadding + column * (cellWidth + crossAxisSpacing);
    // 直接使用 scrollOffset，不需要转换
    final double top = resolvedPadding.top + mainAxisPadding + row * (itemExtent + mainAxisSpacing) - scrollOffset;

    return LayoutParams(
      rect: Rect.fromLTWH(left, top, cellWidth, cellHeight),
      scale: 1.0,
      alpha: 1.0,
      dimming: 0.0,
      titleAlpha: 1.0,
      headerAlpha: 1.0,
      shadowAlpha: 0.0,
    );
  }

  LayoutParams _getHorizontalLayoutParams({
    required int index,
    required double scrollOffset,
    required double containerWidth,
    required double containerHeight,
    required double itemExtent,
    required DateTime startTime,
    required EdgeInsets resolvedPadding,
  }) {
    final int column = index ~/ spanCount;
    final int row = index % spanCount;

    final double totalCrossAxisSpacing = crossAxisSpacing * (spanCount - 1);
    final double availableHeight = containerHeight - totalCrossAxisSpacing - crossAxisPadding * 2;
    final double cellWidth = itemExtent;
    final double cellHeight = availableHeight / spanCount;

    // 直接使用 scrollOffset，不需要转换
    final double left = resolvedPadding.left + mainAxisPadding + column * (itemExtent + mainAxisSpacing) - scrollOffset;
    // 使用传入的 padding.top 和内部的 crossAxisPadding
    final double top = resolvedPadding.top + crossAxisPadding + row * (cellHeight + crossAxisSpacing);

    return LayoutParams(
      rect: Rect.fromLTWH(left, top, cellWidth, cellHeight),
      scale: 1.0,
      alpha: 1.0,
      dimming: 0.0,
      titleAlpha: 1.0,
      headerAlpha: 1.0,
      shadowAlpha: 0.0,
    );
  }

  @override
  int getMinVisibleIndex({
    required double scrollOffset,
    required int itemCount,
    required double mainAxisExtent,
    required double crossAxisExtent,
    required double itemWidth,
    required double itemHeight,
    required EdgeInsetsGeometry padding,
    required bool reverseLayout,
    required double cacheExtent,
    required TextDirection textDirection,
    required Axis scrollDirection,
  }) {
    if (itemCount == 0) return 0;
    final itemExtent = scrollDirection == Axis.horizontal ? itemWidth : itemHeight;
    final resolvedPadding = padding.resolve(textDirection);
    final double mainAxisPaddingFromEdgeInsets = scrollDirection == Axis.vertical 
        ? resolvedPadding.top 
        : resolvedPadding.left;

    final double totalMainAxisPadding = mainAxisPaddingFromEdgeInsets + mainAxisPadding;
    final int firstVisibleMainAxis = math.max(
      0,
      ((scrollOffset - totalMainAxisPadding - cacheExtent) / (itemExtent + mainAxisSpacing)).floor(),
    );

    return firstVisibleMainAxis * spanCount;
  }

  @override
  int getMaxVisibleIndex({
    required double scrollOffset,
    required int itemCount,
    required double mainAxisExtent,
    required double crossAxisExtent,
    required double itemWidth,
    required double itemHeight,
    required EdgeInsetsGeometry padding,
    required bool reverseLayout,
    required double cacheExtent,
    required TextDirection textDirection,
    required Axis scrollDirection,
  }) {
    if (itemCount == 0) return 0;
    final itemExtent = scrollDirection == Axis.horizontal ? itemWidth : itemHeight;
    final resolvedPadding = padding.resolve(textDirection);
    final double mainAxisPaddingFromEdgeInsets = scrollDirection == Axis.vertical 
        ? resolvedPadding.top 
        : resolvedPadding.left;

    final double viewportEnd = scrollOffset + mainAxisExtent + cacheExtent;
    final double totalMainAxisPadding = mainAxisPaddingFromEdgeInsets + mainAxisPadding;
    final int lastVisibleMainAxis = ((viewportEnd - totalMainAxisPadding) / (itemExtent + mainAxisSpacing)).floor();

    return math.min(
      (lastVisibleMainAxis + 1) * spanCount - 1,
      itemCount - 1,
    );
  }

  @override
  double indexToLayoutOffset({
    required int index,
    required double itemExtent,
    required double scrollOffset,
    required double viewportExtent,
    required bool reverseLayout,
  }) {
    final int mainAxisIndex = index ~/ spanCount;
    return mainAxisPadding + mainAxisIndex * (itemExtent + mainAxisSpacing);
  }
}
