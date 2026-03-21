import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'layout_algorithm.dart';

/// MIUI 堆叠布局算法实现
/// 参考 MIUI TaskStackViewsAlgorithmStack 实现
/// 传入 index 和滚动信息，返回该 item 的布局参数
class StackLayoutAlgorithm extends LayoutAlgorithm {
  /// 两侧最多能多滚动的卡片数量（乘以 itemExtent 得到像素）
  final double maxOverscrollCount;

  StackLayoutAlgorithm({this.maxOverscrollCount = 1.0});
  @override
  double? calculatePaintExtent(
    SliverConstraints constraints, {
    required double from,
    required double to,
    required EdgeInsetsGeometry edgeSpacing,
    required Size itemSpacing,
  }) => constraints.viewportMainAxisExtent;

  @override
  double computeMaxScrollOffset({
    required double itemExtent,
    required int itemCount,
    required double viewportExtent,
    required EdgeInsetsGeometry edgeSpacing,
    required Size itemSpacing,
  }) {
    // 让最后一个 item 能滚动到和第一个 item 一样的位置（视口起始位置）
    // scrollExtent = 最后一个 item 的起始位置 + 视口大小
    if (itemCount == 0) return 0.0;
    return (itemCount - 1) * itemExtent + viewportExtent;
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
    // 从缓存中获取该 index 的 LayoutParams
    final params = layoutParamsCache?[index];
    if (params == null) {
      // 如果缓存中没有，返回简单的线性值
      return index * itemExtent;
    }
    
    // 根据方向决定使用 rect.left 还是 rect.right
    if (reverseLayout) {
      // reverse: true，从右往左
      // layoutOffset = (viewportExtent - rect.right) + scrollOffset
      return (viewportExtent - params.rect.right) + scrollOffset;
    } else {
      // reverse: false，从左往右
      // layoutOffset = rect.left + scrollOffset
      return params.rect.left + scrollOffset;
    }
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
    final itemExtent = scrollDirection == Axis.horizontal ? itemSize.width : itemSize.height;
    final resolvedPadding = padding.resolve(textDirection);
    // 堆叠只支持横向滚动，所以下面的计算都是基于这个前提
    final visibleWidth = mainAxisExtent - resolvedPadding.horizontal;
    
    // 对 scrollOffset 施加软边界阻尼，防止 overscroll 时 depth 指数爆炸
    // 超出边界的部分用指数衰减渐近边界，而不是硬截断
    final double minBound = -maxOverscrollCount * itemExtent;
    final double maxBound = (itemCount - 1 + maxOverscrollCount) * itemExtent;
    final double clampedScrollOffset = softClamp(scrollOffset, minBound, maxBound, itemExtent / 2);

    // Stack 算法需要知道"第几张卡片"，所以内部转换
    final curIndex = _scrollOffsetToPosition(clampedScrollOffset, itemExtent);

    final cardScale = 0.7;
    final depthPadding = 0.125;
    // 计算百分比
    final per = itemCount == 0 ? 0.0 : curIndex / itemCount;
    final aCoeff = (-35.0 / 402.0) * visibleWidth;
    final bCoeff = 8.0;
    final scrollMin = _getScrollMin(visibleWidth, cardScale, aCoeff, bCoeff);

    // 计算深度
    final depthRange = depthPadding * itemCount;
    final depth = scrollMin + depthRange * per - depthPadding * index;

    // 基于深度计算各种属性
    final scale = _getScale(depth, cardScale);
    final offsetX = _getOffsetX(
      depth,
      scale,
      visibleWidth,
      cardScale,
      aCoeff,
      bCoeff,
    );
    final alpha = _getAlpha(depth);
    final dimming = _getDimming(depth);
    final titleAlpha = _getTitleAlpha(depth);
    final headerAlpha = _getHeaderAlpha(depth);
    final shadowAlpha = _getShadowAlpha(depth);

    // 计算 Y 轴位置（垂直居中）
    final scaledHeight = itemSize.height * scale;
    final offsetY = (crossAxisExtent - scaledHeight) / 2;

    // offsetX 是相对于卡片居中位置的偏移
    final scaledWidth = itemSize.width * scale;
    // 居中位置需要考虑 paddingLeft 的偏移
    final centeredLeft =
        (visibleWidth - scaledWidth) / 2 + resolvedPadding.left;

    // 根据 reverse 决定方向
    // reverse=true: 原始 MIUI 算法（从右往左），使用 +offsetX
    // reverse=false: 反转方向（从左往右），使用 -offsetX
    final absoluteX =
        reverseLayout
            ? centeredLeft + offsetX // 从右往左
            : centeredLeft - offsetX; // 从左往右

    // 创建 Rect（已应用缩放）
    // 确保宽度和高度不为负数
    final rect = Rect.fromLTWH(
      absoluteX,
      offsetY,
      math.max(0.0, scaledWidth),
      math.max(0.0, scaledHeight),
    );


    return LayoutParams(
      rect: rect,
      scale: scale,
      alpha: alpha,
      dimming: dimming,
      titleAlpha: titleAlpha,
      headerAlpha: headerAlpha,
      shadowAlpha: shadowAlpha,
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
    final itemExtent = scrollDirection == Axis.horizontal ? itemSize.width : itemSize.height;
    final scrollPosition = _scrollOffsetToPosition(scrollOffset, itemExtent);
    
    int startIndex = math.max(scrollPosition.floor() - 1, 0);

    while (startIndex > 0) {
      var params = getLayoutParamsWithCache(
        index: startIndex,
        scrollOffset: scrollOffset,
        mainAxisExtent: mainAxisExtent,
        crossAxisExtent: crossAxisExtent,
        itemSize: itemSize,
        itemCount: itemCount,
        padding: padding,
        reverse: reverseLayout,
        textDirection: textDirection,
        scrollDirection: scrollDirection,
      );

      if (reverseLayout) {
        if (params.rect.left > mainAxisExtent + cacheExtent) break;
      } else {
        if (params.rect.right < -cacheExtent) break;
      }
      
      startIndex--;
    }

    final int minIdx = math.max(startIndex, 0);
    return minIdx;
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
    final itemExtent = scrollDirection == Axis.horizontal ? itemSize.width : itemSize.height;
    final scrollPosition = _scrollOffsetToPosition(scrollOffset, itemExtent);
    
    int endIndex = math.max(scrollPosition.floor() + 4, itemCount - 1);

    while (endIndex < itemCount) {
      var params = getLayoutParamsWithCache(
        index: endIndex,
        scrollOffset: scrollOffset,
        mainAxisExtent: mainAxisExtent,
        crossAxisExtent: crossAxisExtent,
        itemSize: itemSize,
        itemCount: itemCount,
        padding: padding,
        reverse: reverseLayout,
        textDirection: textDirection,
        scrollDirection: scrollDirection,
      );
      if (params.alpha == 0) break;
      endIndex++;
    }

    final int maxIdx = math.min(endIndex, itemCount - 1);
    return maxIdx;  }

  // ========== 私有计算方法 ==========

  /// 将 scrollOffset 转换为逻辑位置（卡片索引）
  /// 这是 Stack 算法特有的内部方法
  double _scrollOffsetToPosition(double scrollOffset, double itemExtent) {
    // 对于单列堆叠布局，scrollPosition 就是 item 索引（浮点数）
    return scrollOffset / itemExtent;
  }

  double _getScrollMin(
    double containerWidth,
    double cardScale,
    double aCoeff,
    double bCoeff,
  ) {
    return math.log(
          (containerWidth * (1.0 - cardScale) * 0.5 - aCoeff) / containerWidth,
        ) /
        bCoeff;
  }

  double _getScale(double depth, double cardScale) {
    return (depth * 0.2 + 1.0) * cardScale;
  }

  double _getOffsetX(
    double depth,
    double scale,
    double containerWidth,
    double cardScale,
    double aCoeff,
    double bCoeff,
  ) {
    final expValue = math.exp(depth * bCoeff);
    return (((aCoeff + containerWidth * expValue) +
                containerWidth * (1.0 - cardScale) * -0.5) /
            cardScale) *
        scale;
  }

  double _valueAlongDepth(double depth, double a, double b) {
    return ((-depth - a) * b).clamp(0.0, 1.0);
  }

  double _getAlpha(double depth) {
    final alpha = 1.0 - _valueAlongDepth(depth, 0.4, 4.0);
    return alpha < 0.01 ? 0.0 : alpha;
  }

  double _getDimming(double depth) {
    return _valueAlongDepth(depth, 0.23, 2.5) * 0.5;
  }

  double _getTitleAlpha(double depth) {
    return 1.0 - _valueAlongDepth(depth, 0.23, 2.5);
  }

  double _getHeaderAlpha(double depth) {
    return 1.0 - _valueAlongDepth(depth, 0.23, 2.5);
  }

  double _getShadowAlpha(double depth) {
    return _valueAlongDepth(depth, 0.0, 2.5) * 0.6;
  }
}
