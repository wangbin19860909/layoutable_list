import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'layout_algorithm.dart';

/// 网格布局算法实现
/// 支持横向和纵向滚动的网格布局，类似 GridView
///
/// 间距通过外部传入的 edgeSpacing / itemSpacing 控制：
/// - edgeSpacing：item 与容器边缘的间距（EdgeInsetsGeometry）
/// - itemSpacing：item 之间的间距（Size），主轴方向用 width（横向）或 height（纵向），
///   交叉轴方向用 height（横向）或 width（纵向）
class GridLayoutAlgorithm extends LayoutAlgorithm {
  /// 交叉轴方向的 span 数量
  /// - 纵向滚动时：spanCount 表示列数
  /// - 横向滚动时：spanCount 表示行数
  final int spanCount;

  /// 滚动方向
  final Axis scrollDirection;

  /// 两侧最多能多滚动的 item 数量（乘以 itemExtent 得到像素）
  final double maxOverscrollCount;

  GridLayoutAlgorithm({
    this.spanCount = 3,
    this.scrollDirection = Axis.vertical,
    this.maxOverscrollCount = 1.0,
  });

  /// 获取列数（纵向滚动）或行数（横向滚动）
  int get columnCount => scrollDirection == Axis.vertical ? spanCount : 0;

  /// 获取行数（横向滚动）或列数（纵向滚动）
  int get rowCount => scrollDirection == Axis.horizontal ? spanCount : 0;

  // ── 从 edgeSpacing / itemSpacing 提取各方向间距 ──────────────────────────

  /// 将 itemSpacing 拆分为主轴 / 交叉轴间距
  ({double main, double cross}) _resolveItemSpacing(Size itemSpacing) =>
      scrollDirection == Axis.horizontal
          ? (main: itemSpacing.width, cross: itemSpacing.height)
          : (main: itemSpacing.height, cross: itemSpacing.width);

  /// 一次性解析 edgeSpacing 的四个方向间距
  ({double mainStart, double mainEnd, double crossStart, double crossEnd})
      _resolveEdgeSpacing(EdgeInsetsGeometry edgeSpacing, TextDirection td) {
    final r = edgeSpacing.resolve(td);
    return scrollDirection == Axis.horizontal
        ? (mainStart: r.left, mainEnd: r.right, crossStart: r.top, crossEnd: r.bottom)
        : (mainStart: r.top, mainEnd: r.bottom, crossStart: r.left, crossEnd: r.right);
  }


  @override
  double? calculatePaintExtent(
    SliverConstraints constraints, {
    required double from,
    required double to,
    required EdgeInsetsGeometry edgeSpacing,
    required Size itemSpacing,
  }) =>
      constraints.viewportMainAxisExtent;

  @override
  double computeMaxScrollOffset({
    required double itemExtent,
    required int itemCount,
    required double viewportExtent,
    required EdgeInsetsGeometry edgeSpacing,
    required Size itemSpacing,
  }) {
    if (itemCount == 0) return 0.0;

    final spacing = _resolveItemSpacing(itemSpacing);
    final edge = _resolveEdgeSpacing(edgeSpacing, TextDirection.ltr);

    final int lastMainAxisIndex = (itemCount - 1) ~/ spanCount;
    return edge.mainStart + lastMainAxisIndex * (itemExtent + spacing.main) + itemExtent + edge.mainEnd;
  }

  @override
  LayoutParams getLayoutParamsForPosition({
    required int index,
    required double scrollOffset,
    required double mainAxisExtent,
    required double crossAxisExtent,
    required Size itemSize,
    required int itemCount,
    required EdgeInsetsGeometry padding,
    bool reverseLayout = false,
    required TextDirection textDirection,
    required Axis scrollDirection,
    required EdgeInsetsGeometry edgeSpacing,
    required Size itemSpacing,
  }) {
    final double itemExtent =
        scrollDirection == Axis.horizontal ? itemSize.width : itemSize.height;

    final resolvedPadding = padding.resolve(textDirection);

    final double clampedScrollOffset = _clampScrollOffset(
      scrollOffset, itemExtent, itemCount, mainAxisExtent,
      edgeSpacing: edgeSpacing, itemSpacing: itemSpacing,
    );

    if (scrollDirection == Axis.vertical) {
      return _getVerticalLayoutParams(
        index: index,
        scrollOffset: clampedScrollOffset,
        containerWidth: mainAxisExtent,
        itemExtent: itemExtent,
        resolvedPadding: resolvedPadding,
        edgeSpacing: edgeSpacing,
        textDirection: textDirection,
        itemSpacing: itemSpacing,
      );
    } else {
      return _getHorizontalLayoutParams(
        index: index,
        scrollOffset: clampedScrollOffset,
        containerHeight: crossAxisExtent,
        itemExtent: itemExtent,
        resolvedPadding: resolvedPadding,
        edgeSpacing: edgeSpacing,
        textDirection: textDirection,
        itemSpacing: itemSpacing,
      );
    }
  }

  LayoutParams _getVerticalLayoutParams({
    required int index,
    required double scrollOffset,
    required double containerWidth,
    required double itemExtent,
    required EdgeInsets resolvedPadding,
    required EdgeInsetsGeometry edgeSpacing,
    required TextDirection textDirection,
    required Size itemSpacing,
  }) {
    final int row = index ~/ spanCount;
    final int column = index % spanCount;

    final spacing = _resolveItemSpacing(itemSpacing);
    final edge = _resolveEdgeSpacing(edgeSpacing, textDirection);

    final double totalCrossSpacing = spacing.cross * (spanCount - 1);
    final double availableWidth =
        containerWidth - totalCrossSpacing - edge.crossStart - edge.crossEnd;
    final double cellWidth = availableWidth / spanCount;

    final double left =
        resolvedPadding.left + edge.crossStart + column * (cellWidth + spacing.cross);
    final double top =
        resolvedPadding.top + edge.mainStart + row * (itemExtent + spacing.main) - scrollOffset;

    return LayoutParams(
      rect: Rect.fromLTWH(left, top, cellWidth, itemExtent),
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
    required double containerHeight,
    required double itemExtent,
    required EdgeInsets resolvedPadding,
    required EdgeInsetsGeometry edgeSpacing,
    required TextDirection textDirection,
    required Size itemSpacing,
  }) {
    final int column = index ~/ spanCount;
    final int row = index % spanCount;

    final spacing = _resolveItemSpacing(itemSpacing);
    final edge = _resolveEdgeSpacing(edgeSpacing, textDirection);

    final double totalCrossSpacing = spacing.cross * (spanCount - 1);
    final double availableHeight =
        containerHeight - totalCrossSpacing - edge.crossStart - edge.crossEnd;
    final double cellHeight = availableHeight / spanCount;

    final double left =
        resolvedPadding.left + edge.mainStart + column * (itemExtent + spacing.main) - scrollOffset;
    final double top =
        resolvedPadding.top + edge.crossStart + row * (cellHeight + spacing.cross);

    return LayoutParams(
      rect: Rect.fromLTWH(left, top, itemExtent, cellHeight),
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
    required Size itemSize,
    required EdgeInsetsGeometry padding,
    required bool reverseLayout,
    required double cacheExtent,
    required TextDirection textDirection,
    required Axis scrollDirection,
    required EdgeInsetsGeometry edgeSpacing,
    required Size itemSpacing,
  }) {
    if (itemCount == 0) return 0;
    final double itemExtent =
        scrollDirection == Axis.horizontal ? itemSize.width : itemSize.height;
    final double mainSpacing = _resolveItemSpacing(itemSpacing).main;
    final double edgeStart = _resolveEdgeSpacing(edgeSpacing, textDirection).mainStart;
    final resolvedPadding = padding.resolve(textDirection);
    final double paddingStart =
        scrollDirection == Axis.vertical ? resolvedPadding.top : resolvedPadding.left;

    final double clampedScrollOffset = _clampScrollOffset(
      scrollOffset, itemExtent, itemCount, mainAxisExtent,
      edgeSpacing: edgeSpacing, itemSpacing: itemSpacing,
    );

    final double totalStart = paddingStart + edgeStart;
    final int firstVisibleMainAxis = math.max(
      0,
      ((clampedScrollOffset - totalStart - cacheExtent) / (itemExtent + mainSpacing)).floor(),
    );

    return firstVisibleMainAxis * spanCount;
  }

  @override
  int getMaxVisibleIndex({
    required double scrollOffset,
    required int itemCount,
    required double mainAxisExtent,
    required double crossAxisExtent,
    required Size itemSize,
    required EdgeInsetsGeometry padding,
    required bool reverseLayout,
    required double cacheExtent,
    required TextDirection textDirection,
    required Axis scrollDirection,
    required EdgeInsetsGeometry edgeSpacing,
    required Size itemSpacing,
  }) {
    if (itemCount == 0) return 0;
    final double itemExtent =
        scrollDirection == Axis.horizontal ? itemSize.width : itemSize.height;
    final double mainSpacing = _resolveItemSpacing(itemSpacing).main;
    final double edgeStart = _resolveEdgeSpacing(edgeSpacing, textDirection).mainStart;
    final resolvedPadding = padding.resolve(textDirection);
    final double paddingStart =
        scrollDirection == Axis.vertical ? resolvedPadding.top : resolvedPadding.left;

    final double clampedScrollOffset = _clampScrollOffset(
      scrollOffset, itemExtent, itemCount, mainAxisExtent,
      edgeSpacing: edgeSpacing, itemSpacing: itemSpacing,
    );

    final double totalStart = paddingStart + edgeStart;
    final double viewportEnd = clampedScrollOffset + mainAxisExtent + cacheExtent;
    final int lastVisibleMainAxis =
        ((viewportEnd - totalStart) / (itemExtent + mainSpacing)).floor();

    return math.min(
      math.max((lastVisibleMainAxis + 1) * spanCount - 1, 0),
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
    required EdgeInsetsGeometry edgeSpacing,
    required Size itemSpacing,
  }) {
    final double mainSpacing = _resolveItemSpacing(itemSpacing).main;
    final double edgeStart = _resolveEdgeSpacing(edgeSpacing, TextDirection.ltr).mainStart;
    final int mainAxisIndex = index ~/ spanCount;
    return edgeStart + mainAxisIndex * (itemExtent + mainSpacing);
  }

  /// 对 scrollOffset 施加软边界阻尼
  double _clampScrollOffset(
    double scrollOffset,
    double itemExtent,
    int itemCount,
    double mainAxisExtent, {
    required EdgeInsetsGeometry edgeSpacing,
    required Size itemSpacing,
  }) {
    final double maxScroll = computeMaxScrollOffset(
      itemExtent: itemExtent,
      itemCount: itemCount,
      viewportExtent: mainAxisExtent,
      edgeSpacing: edgeSpacing,
      itemSpacing: itemSpacing,
    );
    final double margin = maxOverscrollCount * itemExtent;
    final double effectiveMax =
        maxScroll > mainAxisExtent ? maxScroll - mainAxisExtent : 0.0;
    return softClamp(scrollOffset, -margin, effectiveMax + margin, itemExtent);
  }
}
