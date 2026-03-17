import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'layout_algorithm.dart';

/// 主轴对齐方式（justify-content）
enum FlexJustifyContent {
  /// item 靠主轴起始端对齐，间距在末尾
  start,
  /// item 靠主轴末尾端对齐，间距在起始
  end,
  /// item 居中，两端留等量空白
  center,
  /// item 均匀分布，首尾 item 贴边，间距均等
  spaceBetween,
  /// item 均匀分布，每个 item 两侧间距相等（首尾各有半个间距）
  spaceAround,
  /// item 均匀分布，所有间距（含首尾）完全相等
  spaceEvenly,
}

/// 交叉轴对齐方式（align-items）
enum FlexAlignItems {
  /// item 靠交叉轴起始端对齐
  start,
  /// item 靠交叉轴末尾端对齐
  end,
  /// item 在交叉轴居中
  center,
  /// item 在交叉轴方向拉伸填满（使用 itemHeight/itemWidth 作为交叉轴尺寸）
  stretch,
}

/// FlexBox 布局算法
///
/// 所有 item 等尺寸，单行/列排列（不换行），支持：
/// - [justifyContent]：主轴对齐方式
/// - [alignItems]：交叉轴对齐方式
/// - [scrollDirection]：滚动方向（Axis.horizontal = 横向滚动，item 横向排列）
///
/// 注意：scrollDirection 决定滚动轴，item 沿滚动轴方向排列。
/// 主轴 = 滚动轴，交叉轴 = 垂直于滚动轴。
class FlexLayoutAlgorithm extends LayoutAlgorithm {
  final FlexJustifyContent justifyContent;
  final FlexAlignItems alignItems;
  final Axis scrollDirection;

  /// item 之间的固定间距（仅在 justifyContent = start/end/center 时生效）
  final double itemSpacing;

  /// 主轴方向的边距（两端）
  final double mainAxisPadding;

  /// 交叉轴方向的边距（两端）
  final double crossAxisPadding;

  /// 最大过滚动量（item 数量单位）
  final double maxOverscrollCount;

  FlexLayoutAlgorithm({
    this.justifyContent = FlexJustifyContent.start,
    this.alignItems = FlexAlignItems.center,
    this.scrollDirection = Axis.horizontal,
    this.itemSpacing = 8.0,
    this.mainAxisPadding = 0.0,
    this.crossAxisPadding = 0.0,
    this.maxOverscrollCount = 1.0,
  });

  @override
  double computeMaxScrollOffset({
    required double itemExtent,
    required int itemCount,
    required double viewportExtent,
  }) {
    if (itemCount == 0) return 0.0;
    // 总内容长度 = 两端 padding + 所有 item + 间距
    return mainAxisPadding * 2 +
        itemCount * itemExtent +
        (itemCount - 1) * itemSpacing;
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
    final double itemMainSize =
        scrollDirection == Axis.horizontal ? itemWidth : itemHeight;
    final double itemCrossSize =
        scrollDirection == Axis.horizontal ? itemHeight : itemWidth;

    // 视口在主轴/交叉轴方向的尺寸
    final double mainViewport =
        scrollDirection == Axis.horizontal ? mainAxisExtent : crossAxisExtent;
    final double crossViewport =
        scrollDirection == Axis.horizontal ? crossAxisExtent : mainAxisExtent;

    final resolvedPadding = padding.resolve(textDirection);
    final double edgeMainPadding = scrollDirection == Axis.horizontal
        ? resolvedPadding.left
        : resolvedPadding.top;
    final double edgeCrossPadding = scrollDirection == Axis.horizontal
        ? resolvedPadding.top
        : resolvedPadding.left;

    final double clampedScroll =
        _clampScrollOffset(scrollOffset, itemMainSize, itemCount, mainViewport);

    // 计算主轴起始偏移
    final double mainOffset = _computeMainOffset(
      index: index,
      itemCount: itemCount,
      itemMainSize: itemMainSize,
      mainViewport: mainViewport,
      edgeMainPadding: edgeMainPadding,
    ) - clampedScroll;

    // 计算交叉轴偏移
    final double availableCross =
        crossViewport - edgeCrossPadding * 2 - crossAxisPadding * 2;
    final double crossOffset = _computeCrossOffset(
      itemCrossSize: itemCrossSize,
      availableCross: availableCross,
      edgeCrossPadding: edgeCrossPadding,
    );
    final double actualCrossSize = alignItems == FlexAlignItems.stretch
        ? availableCross
        : itemCrossSize;

    double left, top, width, height;
    if (scrollDirection == Axis.horizontal) {
      left = mainOffset;
      top = crossOffset;
      width = itemMainSize;
      height = actualCrossSize;
    } else {
      left = crossOffset;
      top = mainOffset;
      width = actualCrossSize;
      height = itemMainSize;
    }

    return LayoutParams(
      rect: Rect.fromLTWH(left, top, width, height),
      scale: 1.0,
      alpha: 1.0,
      dimming: 0.0,
      titleAlpha: 1.0,
      headerAlpha: 1.0,
      shadowAlpha: 0.0,
    );
  }

  /// 计算 item 在主轴方向的起始位置（未减去 scrollOffset）
  double _computeMainOffset({
    required int index,
    required int itemCount,
    required double itemMainSize,
    required double mainViewport,
    required double edgeMainPadding,
  }) {
    final double totalContentSize =
        itemCount * itemMainSize + (itemCount - 1) * itemSpacing;
    final double availableMain =
        mainViewport - edgeMainPadding * 2 - mainAxisPadding * 2;

    switch (justifyContent) {
      case FlexJustifyContent.start:
        return edgeMainPadding +
            mainAxisPadding +
            index * (itemMainSize + itemSpacing);

      case FlexJustifyContent.end:
        final double startOffset =
            edgeMainPadding + mainAxisPadding + (availableMain - totalContentSize);
        return startOffset + index * (itemMainSize + itemSpacing);

      case FlexJustifyContent.center:
        final double startOffset = edgeMainPadding +
            mainAxisPadding +
            (availableMain - totalContentSize) / 2;
        return startOffset + index * (itemMainSize + itemSpacing);

      case FlexJustifyContent.spaceBetween:
        if (itemCount == 1) {
          return edgeMainPadding + mainAxisPadding;
        }
        final double gap = (availableMain - itemCount * itemMainSize) /
            (itemCount - 1);
        return edgeMainPadding +
            mainAxisPadding +
            index * (itemMainSize + gap);

      case FlexJustifyContent.spaceAround:
        final double gap =
            (availableMain - itemCount * itemMainSize) / itemCount;
        return edgeMainPadding +
            mainAxisPadding +
            gap / 2 +
            index * (itemMainSize + gap);

      case FlexJustifyContent.spaceEvenly:
        final double gap =
            (availableMain - itemCount * itemMainSize) / (itemCount + 1);
        return edgeMainPadding +
            mainAxisPadding +
            gap +
            index * (itemMainSize + gap);
    }
  }

  /// 计算 item 在交叉轴方向的起始位置
  double _computeCrossOffset({
    required double itemCrossSize,
    required double availableCross,
    required double edgeCrossPadding,
  }) {
    switch (alignItems) {
      case FlexAlignItems.start:
      case FlexAlignItems.stretch:
        return edgeCrossPadding + crossAxisPadding;
      case FlexAlignItems.end:
        return edgeCrossPadding +
            crossAxisPadding +
            availableCross -
            itemCrossSize;
      case FlexAlignItems.center:
        return edgeCrossPadding +
            crossAxisPadding +
            (availableCross - itemCrossSize) / 2;
    }
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
    final double itemMainSize =
        scrollDirection == Axis.horizontal ? itemWidth : itemHeight;
    final double mainViewport =
        scrollDirection == Axis.horizontal ? mainAxisExtent : crossAxisExtent;
    final resolvedPadding = padding.resolve(textDirection);
    final double edgeMainPadding = scrollDirection == Axis.horizontal
        ? resolvedPadding.left
        : resolvedPadding.top;
    final double clampedScroll =
        _clampScrollOffset(scrollOffset, itemMainSize, itemCount, mainViewport);

    // start/end/center 的 item 间距固定为 itemSpacing，可直接反推 index
    // space* 模式间距动态，需要遍历
    if (justifyContent == FlexJustifyContent.start ||
        justifyContent == FlexJustifyContent.end ||
        justifyContent == FlexJustifyContent.center) {
      final double startOffset = _computeMainOffset(
        index: 0,
        itemCount: itemCount,
        itemMainSize: itemMainSize,
        mainViewport: mainViewport,
        edgeMainPadding: edgeMainPadding,
      );
      final int idx =
          ((clampedScroll - cacheExtent - startOffset) / (itemMainSize + itemSpacing))
              .floor();
      return math.max(0, idx);
    }

    for (int i = 0; i < itemCount; i++) {
      final double right = _computeMainOffset(
            index: i,
            itemCount: itemCount,
            itemMainSize: itemMainSize,
            mainViewport: mainViewport,
            edgeMainPadding: edgeMainPadding,
          ) -
          clampedScroll +
          itemMainSize;
      if (right > -cacheExtent) return math.max(0, i);
    }
    return math.max(0, itemCount - 1);
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
    final double itemMainSize =
        scrollDirection == Axis.horizontal ? itemWidth : itemHeight;
    final double mainViewport =
        scrollDirection == Axis.horizontal ? mainAxisExtent : crossAxisExtent;
    final resolvedPadding = padding.resolve(textDirection);
    final double edgeMainPadding = scrollDirection == Axis.horizontal
        ? resolvedPadding.left
        : resolvedPadding.top;
    final double clampedScroll =
        _clampScrollOffset(scrollOffset, itemMainSize, itemCount, mainViewport);

    if (justifyContent == FlexJustifyContent.start ||
        justifyContent == FlexJustifyContent.end ||
        justifyContent == FlexJustifyContent.center) {
      final double startOffset = _computeMainOffset(
        index: 0,
        itemCount: itemCount,
        itemMainSize: itemMainSize,
        mainViewport: mainViewport,
        edgeMainPadding: edgeMainPadding,
      );
      final int idx =
          ((clampedScroll + mainViewport + cacheExtent - startOffset) /
                  (itemMainSize + itemSpacing))
              .ceil();
      return math.min(itemCount - 1, math.max(0, idx));
    }

    int last = 0;
    for (int i = 0; i < itemCount; i++) {
      final double left = _computeMainOffset(
            index: i,
            itemCount: itemCount,
            itemMainSize: itemMainSize,
            mainViewport: mainViewport,
            edgeMainPadding: edgeMainPadding,
          ) -
          clampedScroll;
      if (left < mainViewport + cacheExtent) {
        last = i;
      } else {
        break;
      }
    }
    return math.min(last, itemCount - 1);
  }

  @override
  double indexToLayoutOffset({
    required int index,
    required double itemExtent,
    required double scrollOffset,
    required double viewportExtent,
    required bool reverseLayout,
  }) {
    // 仅 start 模式下有意义的精确值，其他模式返回近似值
    return mainAxisPadding + index * (itemExtent + itemSpacing);
  }

  double _clampScrollOffset(
    double scrollOffset,
    double itemExtent,
    int itemCount,
    double mainAxisExtent,
  ) {
    final double maxScroll = computeMaxScrollOffset(
      itemExtent: itemExtent,
      itemCount: itemCount,
      viewportExtent: mainAxisExtent,
    );
    final double margin = maxOverscrollCount * itemExtent;
    final double effectiveMax =
        maxScroll > mainAxisExtent ? maxScroll - mainAxisExtent : 0.0;
    return softClamp(scrollOffset, -margin, effectiveMax + margin, itemExtent);
  }

  @override
  double? calculatePaintExtent(
    SliverConstraints constraints, {
    required double from,
    required double to,
  }) => constraints.viewportMainAxisExtent;
}
