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
/// - [direction]：滚动方向
///
/// 间距通过外部传入的 edgeSpacing / itemSpacing 控制：
/// - edgeSpacing：item 与容器边缘的间距
/// - itemSpacing：item 之间的间距（主轴方向用 width（横向）或 height（纵向））
class FlexLayoutAlgorithm extends LayoutAlgorithm {
  final FlexJustifyContent justifyContent;
  final FlexAlignItems alignItems;
  final Axis direction;
  final ItemSizeProvider? itemSizeProvider;

  FlexLayoutAlgorithm({
    this.justifyContent = FlexJustifyContent.start,
    this.alignItems = FlexAlignItems.center,
    this.direction = Axis.horizontal,
    this.itemSizeProvider,
  });

  // ── 从 edgeSpacing / itemSpacing 提取各方向间距 ──────────────────────────

  /// 将 itemSpacing 拆分为主轴 / 交叉轴间距
  ({double main, double cross}) _resolveItemSpacing(Size itemSpacing) =>
      direction == Axis.horizontal
          ? (main: itemSpacing.width, cross: itemSpacing.height)
          : (main: itemSpacing.height, cross: itemSpacing.width);

  /// 一次性解析 edgeSpacing 的四个方向间距
  ({double mainStart, double mainEnd, double crossStart, double crossEnd})
      _resolveEdgeSpacing(EdgeInsetsGeometry edgeSpacing, TextDirection td) {
    final r = edgeSpacing.resolve(td);
    return direction == Axis.horizontal
        ? (mainStart: r.left, mainEnd: r.right, crossStart: r.top, crossEnd: r.bottom)
        : (mainStart: r.top, mainEnd: r.bottom, crossStart: r.left, crossEnd: r.right);
  }

  /// 将 mainAxisExtent / crossAxisExtent 映射为主轴 / 交叉轴视口尺寸
  ({double main, double cross}) _resolveViewport(
    double mainAxisExtent,
    double crossAxisExtent,
    Axis scrollDirection,
  ) {
    return scrollDirection == Axis.horizontal
        ? (main: mainAxisExtent, cross: crossAxisExtent)
        : (main: crossAxisExtent, cross: mainAxisExtent);
  }

  /// 将 padding 解析为主轴 / 交叉轴方向间距
  ({double mainStart, double mainEnd, double crossStart, double crossEnd}) _resolvePadding(
    EdgeInsetsGeometry padding,
    TextDirection textDirection,
    Axis scrollDirection,
  ) {
    final r = padding.resolve(textDirection);
    return scrollDirection == Axis.horizontal
        ? (mainStart: r.left, mainEnd: r.right, crossStart: r.top, crossEnd: r.bottom)
        : (mainStart: r.top, mainEnd: r.bottom, crossStart: r.left, crossEnd: r.right);
  }

  /// 将 itemSize 拆分为主轴 / 交叉轴尺寸
  ({double main, double cross}) _resolveItemSize(
    Size itemSize,
    Axis scrollDirection,
  ) {
    return scrollDirection == Axis.horizontal
        ? (main: itemSize.width, cross: itemSize.height)
        : (main: itemSize.height, cross: itemSize.width);
  }

  /// 从 ItemSizeProvider 获取主轴方向的累积偏移量
  double _mainDelta(int index, Size defaultSize, Axis scrollDirection) {
    if (itemSizeProvider == null) return 0.0;
    final offset = itemSizeProvider!.totalOffsetUpTo(index, defaultSize);
    return scrollDirection == Axis.horizontal ? offset.dx : offset.dy;
  }

  /// 从 ItemSizeProvider 获取指定 item 的实际尺寸（主轴/交叉轴）
  ({double main, double cross}) _resolveActualItemSize(
    int index,
    Size defaultSize,
    Axis scrollDirection,
  ) {
    if (itemSizeProvider == null) {
      return _resolveItemSize(defaultSize, scrollDirection);
    }
    return _resolveItemSize(itemSizeProvider!.sizeOf(index, defaultSize), scrollDirection);
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
    final double mainSpacing = _resolveItemSpacing(itemSpacing).main;
    final edge = _resolveEdgeSpacing(edgeSpacing, TextDirection.ltr);
    final double totalDelta = _mainDelta(
      itemCount,
      direction == Axis.horizontal ? Size(itemExtent, 0) : Size(0, itemExtent),
      direction,
    );
    return edge.mainStart + itemCount * itemExtent + (itemCount - 1) * mainSpacing + totalDelta + edge.mainEnd;
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
    final item = _resolveItemSize(itemSize, scrollDirection);
    final actual = _resolveActualItemSize(index, itemSize, scrollDirection);
    final vp = _resolveViewport(mainAxisExtent, crossAxisExtent, scrollDirection);
    final pad = _resolvePadding(padding, textDirection, scrollDirection);
    final edge = _resolveEdgeSpacing(edgeSpacing, textDirection);
    final double mainSpacing = _resolveItemSpacing(itemSpacing).main;
    final double delta = _mainDelta(index, itemSize, scrollDirection);

    final double availableMain =
        vp.main - pad.mainStart * 2 - edge.mainStart - edge.mainEnd;
    final double baseStart = pad.mainStart + edge.mainStart;

    final double totalDelta = _mainDelta(itemCount, itemSize, scrollDirection);

    final double mainOffset = _computeMainOffset(
      index: index,
      itemCount: itemCount,
      itemMainSize: item.main,
      availableMain: availableMain,
      baseStart: baseStart,
      mainSpacing: mainSpacing,
      delta: delta,
      totalDelta: totalDelta,
    ) - scrollOffset;

    final double availableCross =
        vp.cross - pad.crossStart * 2 - edge.crossStart - edge.crossEnd;
    final double crossOffset = _computeCrossOffset(
      itemCrossSize: actual.cross,
      availableCross: availableCross,
      base: pad.crossStart + edge.crossStart,
    );
    final double actualCrossSize =
        alignItems == FlexAlignItems.stretch ? availableCross : actual.cross;

    double left, top, width, height;
    if (scrollDirection == Axis.horizontal) {
      left = mainOffset;
      top = crossOffset;
      width = actual.main;
      height = actualCrossSize;
    } else {
      left = crossOffset;
      top = mainOffset;
      width = actualCrossSize;
      height = actual.main;
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
  ///
  /// [delta] - 该 item 之前所有 item 的累积尺寸差值
  /// [totalDelta] - 所有 item 的累积尺寸差值（用于 center/end 等对齐）
  double _computeMainOffset({
    required int index,
    required int itemCount,
    required double itemMainSize,
    required double availableMain,
    required double baseStart,
    required double mainSpacing,
    double delta = 0.0,
    double totalDelta = 0.0,
  }) {
    final double totalContentSize =
        itemCount * itemMainSize + (itemCount - 1) * mainSpacing + totalDelta;
    final double pos = index * (itemMainSize + mainSpacing) + delta;

    switch (justifyContent) {
      case FlexJustifyContent.start:
        return baseStart + pos;

      case FlexJustifyContent.end:
        return baseStart + (availableMain - totalContentSize) + pos;

      case FlexJustifyContent.center:
        return baseStart + (availableMain - totalContentSize) / 2 + pos;

      case FlexJustifyContent.spaceBetween:
        if (itemCount == 1) return baseStart + delta;
        final double totalItemSize = itemCount * itemMainSize + totalDelta;
        final double gap = (availableMain - totalItemSize) / (itemCount - 1);
        return baseStart + index * (itemMainSize + gap) + delta;

      case FlexJustifyContent.spaceAround:
        final double totalItemSize = itemCount * itemMainSize + totalDelta;
        final double gap = (availableMain - totalItemSize) / itemCount;
        return baseStart + gap / 2 + index * (itemMainSize + gap) + delta;

      case FlexJustifyContent.spaceEvenly:
        final double totalItemSize = itemCount * itemMainSize + totalDelta;
        final double gap = (availableMain - totalItemSize) / (itemCount + 1);
        return baseStart + gap + index * (itemMainSize + gap) + delta;
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
  }) => 0;

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
  }) => math.max(0, itemCount - 1);

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
    final edge = _resolveEdgeSpacing(edgeSpacing, TextDirection.ltr);
    final double mainSpacing = _resolveItemSpacing(itemSpacing).main;
    final double delta = _mainDelta(
      index,
      direction == Axis.horizontal ? Size(itemExtent, 0) : Size(0, itemExtent),
      direction,
    );
    return edge.mainStart + index * (itemExtent + mainSpacing) + delta;
  }

}
