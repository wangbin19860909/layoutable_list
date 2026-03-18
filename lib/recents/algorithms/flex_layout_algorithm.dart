import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'layout_algorithm.dart';

/// 主轴对齐方式（justify-content）
enum FlexJustifyContent {
  start,
  end,
  center,
  spaceBetween,
  spaceAround,
  spaceEvenly,
}

/// 交叉轴对齐方式（align-items）
enum FlexAlignItems {
  start,
  end,
  center,
  stretch,
}

/// FlexBox 布局算法
///
/// 所有 item 等尺寸，单行/列排列（不换行），支持：
/// - [justifyContent]：主轴对齐方式
/// - [alignItems]：交叉轴对齐方式
/// - [scrollDirection]：滚动方向
///
/// 间距通过外部传入的 edgeSpacing / itemSpacing 控制：
/// - edgeSpacing：item 与容器边缘的间距
/// - itemSpacing：item 之间的间距（主轴方向用 width（横向）或 height（纵向））
class FlexLayoutAlgorithm extends LayoutAlgorithm {
  final FlexJustifyContent justifyContent;
  final FlexAlignItems alignItems;
  final Axis scrollDirection;
  final double maxOverscrollCount;

  FlexLayoutAlgorithm({
    this.justifyContent = FlexJustifyContent.start,
    this.alignItems = FlexAlignItems.center,
    this.scrollDirection = Axis.horizontal,
    this.maxOverscrollCount = 1.0,
  });

  // ── 从 edgeSpacing / itemSpacing 提取各方向间距 ──────────────────────────

  double _mainAxisItemSpacing(Size itemSpacing) =>
      scrollDirection == Axis.horizontal ? itemSpacing.width : itemSpacing.height;

  double _mainAxisEdgeStart(EdgeInsetsGeometry edgeSpacing, TextDirection td) {
    final r = edgeSpacing.resolve(td);
    return scrollDirection == Axis.horizontal ? r.left : r.top;
  }

  double _mainAxisEdgeEnd(EdgeInsetsGeometry edgeSpacing, TextDirection td) {
    final r = edgeSpacing.resolve(td);
    return scrollDirection == Axis.horizontal ? r.right : r.bottom;
  }

  double _crossAxisEdgeStart(EdgeInsetsGeometry edgeSpacing, TextDirection td) {
    final r = edgeSpacing.resolve(td);
    return scrollDirection == Axis.horizontal ? r.top : r.left;
  }

  double _crossAxisEdgeEnd(EdgeInsetsGeometry edgeSpacing, TextDirection td) {
    final r = edgeSpacing.resolve(td);
    return scrollDirection == Axis.horizontal ? r.bottom : r.right;
  }

  // ─────────────────────────────────────────────────────────────────────────

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
    final double mainSpacing = _mainAxisItemSpacing(itemSpacing);
    final double edgeStart = _mainAxisEdgeStart(edgeSpacing, TextDirection.ltr);
    final double edgeEnd = _mainAxisEdgeEnd(edgeSpacing, TextDirection.ltr);
    return edgeStart + itemCount * itemExtent + (itemCount - 1) * mainSpacing + edgeEnd;
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
    final double itemMainSize =
        scrollDirection == Axis.horizontal ? itemSize.width : itemSize.height;
    final double itemCrossSize =
        scrollDirection == Axis.horizontal ? itemSize.height : itemSize.width;

    final double mainViewport =
        scrollDirection == Axis.horizontal ? mainAxisExtent : crossAxisExtent;
    final double crossViewport =
        scrollDirection == Axis.horizontal ? crossAxisExtent : mainAxisExtent;

    final resolvedPadding = padding.resolve(textDirection);
    final double paddingMainStart =
        scrollDirection == Axis.horizontal ? resolvedPadding.left : resolvedPadding.top;
    final double paddingCrossStart =
        scrollDirection == Axis.horizontal ? resolvedPadding.top : resolvedPadding.left;

    final double edgeMainStart = _mainAxisEdgeStart(edgeSpacing, textDirection);
    final double edgeMainEnd = _mainAxisEdgeEnd(edgeSpacing, textDirection);
    final double crossEdgeStart = _crossAxisEdgeStart(edgeSpacing, textDirection);
    final double crossEdgeEnd = _crossAxisEdgeEnd(edgeSpacing, textDirection);
    final double mainSpacing = _mainAxisItemSpacing(itemSpacing);

    final double availableMain =
        mainViewport - paddingMainStart * 2 - edgeMainStart - edgeMainEnd;
    final double baseStart = paddingMainStart + edgeMainStart;

    final double clampedScroll = _clampScrollOffset(
      scrollOffset, itemMainSize, itemCount, mainViewport,
      edgeSpacing: edgeSpacing, itemSpacing: itemSpacing,
    );

    final double mainOffset = _computeMainOffset(
      index: index,
      itemCount: itemCount,
      itemMainSize: itemMainSize,
      availableMain: availableMain,
      baseStart: baseStart,
      mainSpacing: mainSpacing,
    ) - clampedScroll;

    final double availableCross =
        crossViewport - paddingCrossStart * 2 - crossEdgeStart - crossEdgeEnd;
    final double crossOffset = _computeCrossOffset(
      itemCrossSize: itemCrossSize,
      availableCross: availableCross,
      base: paddingCrossStart + crossEdgeStart,
    );
    final double actualCrossSize =
        alignItems == FlexAlignItems.stretch ? availableCross : itemCrossSize;

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
    required double availableMain,
    required double baseStart,
    required double mainSpacing,
  }) {
    final double totalContentSize =
        itemCount * itemMainSize + (itemCount - 1) * mainSpacing;

    switch (justifyContent) {
      case FlexJustifyContent.start:
        return baseStart + index * (itemMainSize + mainSpacing);

      case FlexJustifyContent.end:
        return baseStart +
            (availableMain - totalContentSize) +
            index * (itemMainSize + mainSpacing);

      case FlexJustifyContent.center:
        return baseStart +
            (availableMain - totalContentSize) / 2 +
            index * (itemMainSize + mainSpacing);

      case FlexJustifyContent.spaceBetween:
        if (itemCount == 1) return baseStart;
        final double gap =
            (availableMain - itemCount * itemMainSize) / (itemCount - 1);
        return baseStart + index * (itemMainSize + gap);

      case FlexJustifyContent.spaceAround:
        final double gap =
            (availableMain - itemCount * itemMainSize) / itemCount;
        return baseStart + gap / 2 + index * (itemMainSize + gap);

      case FlexJustifyContent.spaceEvenly:
        final double gap =
            (availableMain - itemCount * itemMainSize) / (itemCount + 1);
        return baseStart + gap + index * (itemMainSize + gap);
    }
  }

  /// 计算 item 在交叉轴方向的起始位置
  double _computeCrossOffset({
    required double itemCrossSize,
    required double availableCross,
    required double base,
  }) {
    switch (alignItems) {
      case FlexAlignItems.start:
      case FlexAlignItems.stretch:
        return base;
      case FlexAlignItems.end:
        return base + availableCross - itemCrossSize;
      case FlexAlignItems.center:
        return base + (availableCross - itemCrossSize) / 2;
    }
  }

  // ── 公共辅助：提取 availableMain / baseStart ──────────────────────────────

  ({double availableMain, double baseStart, double mainSpacing}) _mainAxisParams({
    required double mainViewport,
    required EdgeInsetsGeometry padding,
    required EdgeInsetsGeometry edgeSpacing,
    required Size itemSpacing,
    required TextDirection textDirection,
    required Axis scrollDirection,
  }) {
    final resolvedPadding = padding.resolve(textDirection);
    final double paddingMainStart =
        scrollDirection == Axis.horizontal ? resolvedPadding.left : resolvedPadding.top;
    final double edgeMainStart = _mainAxisEdgeStart(edgeSpacing, textDirection);
    final double edgeMainEnd = _mainAxisEdgeEnd(edgeSpacing, textDirection);
    final double mainSpacing = _mainAxisItemSpacing(itemSpacing);
    return (
      availableMain: mainViewport - paddingMainStart * 2 - edgeMainStart - edgeMainEnd,
      baseStart: paddingMainStart + edgeMainStart,
      mainSpacing: mainSpacing,
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
    final double itemMainSize =
        scrollDirection == Axis.horizontal ? itemSize.width : itemSize.height;
    final double mainViewport =
        scrollDirection == Axis.horizontal ? mainAxisExtent : crossAxisExtent;

    final p = _mainAxisParams(
      mainViewport: mainViewport,
      padding: padding,
      edgeSpacing: edgeSpacing,
      itemSpacing: itemSpacing,
      textDirection: textDirection,
      scrollDirection: scrollDirection,
    );

    final double clampedScroll = _clampScrollOffset(
      scrollOffset, itemMainSize, itemCount, mainViewport,
      edgeSpacing: edgeSpacing, itemSpacing: itemSpacing,
    );

    if (justifyContent == FlexJustifyContent.start ||
        justifyContent == FlexJustifyContent.end ||
        justifyContent == FlexJustifyContent.center) {
      final double startOffset = _computeMainOffset(
        index: 0,
        itemCount: itemCount,
        itemMainSize: itemMainSize,
        availableMain: p.availableMain,
        baseStart: p.baseStart,
        mainSpacing: p.mainSpacing,
      );
      final int idx =
          ((clampedScroll - cacheExtent - startOffset) / (itemMainSize + p.mainSpacing))
              .floor();
      return math.max(0, idx);
    }

    for (int i = 0; i < itemCount; i++) {
      final double right = _computeMainOffset(
            index: i,
            itemCount: itemCount,
            itemMainSize: itemMainSize,
            availableMain: p.availableMain,
            baseStart: p.baseStart,
            mainSpacing: p.mainSpacing,
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
    final double itemMainSize =
        scrollDirection == Axis.horizontal ? itemSize.width : itemSize.height;
    final double mainViewport =
        scrollDirection == Axis.horizontal ? mainAxisExtent : crossAxisExtent;

    final p = _mainAxisParams(
      mainViewport: mainViewport,
      padding: padding,
      edgeSpacing: edgeSpacing,
      itemSpacing: itemSpacing,
      textDirection: textDirection,
      scrollDirection: scrollDirection,
    );

    final double clampedScroll = _clampScrollOffset(
      scrollOffset, itemMainSize, itemCount, mainViewport,
      edgeSpacing: edgeSpacing, itemSpacing: itemSpacing,
    );

    if (justifyContent == FlexJustifyContent.start ||
        justifyContent == FlexJustifyContent.end ||
        justifyContent == FlexJustifyContent.center) {
      final double startOffset = _computeMainOffset(
        index: 0,
        itemCount: itemCount,
        itemMainSize: itemMainSize,
        availableMain: p.availableMain,
        baseStart: p.baseStart,
        mainSpacing: p.mainSpacing,
      );
      final int idx =
          ((clampedScroll + mainViewport + cacheExtent - startOffset) /
                  (itemMainSize + p.mainSpacing))
              .ceil();
      return math.min(itemCount - 1, math.max(0, idx));
    }

    int last = 0;
    for (int i = 0; i < itemCount; i++) {
      final double left = _computeMainOffset(
            index: i,
            itemCount: itemCount,
            itemMainSize: itemMainSize,
            availableMain: p.availableMain,
            baseStart: p.baseStart,
            mainSpacing: p.mainSpacing,
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
    required EdgeInsetsGeometry edgeSpacing,
    required Size itemSpacing,
  }) {
    final double edgeStart = _mainAxisEdgeStart(edgeSpacing, TextDirection.ltr);
    final double mainSpacing = _mainAxisItemSpacing(itemSpacing);
    return edgeStart + index * (itemExtent + mainSpacing);
  }

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
