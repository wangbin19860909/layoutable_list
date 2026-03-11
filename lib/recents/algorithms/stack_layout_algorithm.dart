import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../layout_algorithm.dart';

/// MIUI 堆叠布局算法实现
/// 参考 MIUI TaskStackViewsAlgorithmStack 实现
/// 传入 index 和滚动信息，返回该 item 的布局参数
class StackLayoutAlgorithm extends LayoutAlgorithm {
  @override
  double computeMaxScrollOffset({
    required double itemExtent,
    required int itemCount,
    required double viewportExtent,
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
    required bool reverse,
  }) {
    // 从缓存中获取该 index 的 LayoutParams
    final params = layoutParamsCache?[index];
    if (params == null) {
      // 如果缓存中没有，返回简单的线性值
      return index * itemExtent;
    }
    
    // 根据方向决定使用 rect.left 还是 rect.right
    if (reverse) {
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
    required double itemWidth,
    required double itemHeight,
    required double itemExtent,
    required int itemCount,
    required EdgeInsetsGeometry padding,
    bool reverse = false,
    required TextDirection textDirection,
  }) {
    final resolvedPadding = padding.resolve(textDirection);
    // 堆叠只支持横向滚动，所以下面的计算都是基于这个前提
    final visibleWidth = mainAxisExtent - resolvedPadding.horizontal;
    
    // Stack 算法需要知道"第几张卡片"，所以内部转换
    final curIndex = _scrollOffsetToPosition(scrollOffset, itemExtent);

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
    final scaledHeight = itemHeight * scale;
    final offsetY = (crossAxisExtent - scaledHeight) / 2;

    // offsetX 是相对于卡片居中位置的偏移
    final scaledWidth = itemWidth * scale;
    // 居中位置需要考虑 paddingLeft 的偏移
    final centeredLeft =
        (visibleWidth - scaledWidth) / 2 + resolvedPadding.left;

    // 根据 reverse 决定方向
    // reverse=true: 原始 MIUI 算法（从右往左），使用 +offsetX
    // reverse=false: 反转方向（从左往右），使用 -offsetX
    final absoluteX =
        reverse
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


    final params =  LayoutParams(
      rect: rect,
      scale: scale,
      alpha: alpha,
      dimming: dimming,
      titleAlpha: titleAlpha,
      headerAlpha: headerAlpha,
      shadowAlpha: shadowAlpha,
    );
    return params;
  }

  @override
  int getMinVisibleIndex({
    required double scrollOffset,
    required double itemExtent,
    required int itemCount,
    required double mainAxisExtent,
    required double crossAxisExtent,
    required double itemWidth,
    required double itemHeight,
    required EdgeInsetsGeometry padding,
    required bool reverse,
    required double cacheExtent,
    required TextDirection textDirection,
  }) {
    if (itemCount == 0) return 0;

    // 内部转换为逻辑位置
    final scrollPosition = _scrollOffsetToPosition(scrollOffset, itemExtent);
    
    // 从当前滚动位置开始估算第一个可能可见的索引
    int startIndex = math.max(scrollPosition.floor() - 1, 0);

    // 向前搜索，找到第一个可能可见的卡片
    // 检查 alpha > 0 来判断是否可见
    while (startIndex > 0) {
      var params = getLayoutParamsWithCache(
        index: startIndex,
        scrollOffset: scrollOffset,
        mainAxisExtent: mainAxisExtent,
        crossAxisExtent: crossAxisExtent,
        itemWidth: itemWidth,
        itemHeight: itemHeight,
        itemExtent: itemExtent,
        itemCount: itemCount,
        padding: padding,
        reverse: reverse,
        textDirection: textDirection,
      );

      if (reverse) {
        if (params.rect.left > mainAxisExtent + cacheExtent) {
          break;
        }
      } else {
        if (params.rect.right < -cacheExtent) {
          break;
        }
      }
      
      startIndex--;
    }

    return math.max(startIndex, 0);
  }

  @override
  int getMaxVisibleIndex({
    required double scrollOffset,
    required double itemExtent,
    required int itemCount,
    required double mainAxisExtent,
    required double crossAxisExtent,
    required double itemWidth,
    required double itemHeight,
    required EdgeInsetsGeometry padding,
    required bool reverse,
    required double cacheExtent,
    required TextDirection textDirection,
  }) {
    if (itemCount == 0) return 0;

    // 内部转换为逻辑位置
    final scrollPosition = _scrollOffsetToPosition(scrollOffset, itemExtent);
    
    // 从当前滚动位置开始估算，向后搜索
    int endIndex = math.min(scrollPosition.floor() + 4, itemCount - 1);

    // 向后搜索，找到第一个完全透明的 item
    while (endIndex < itemCount) {
      var params = getLayoutParamsWithCache(
        index: endIndex,
        scrollOffset: scrollOffset,
        mainAxisExtent: mainAxisExtent,
        crossAxisExtent: crossAxisExtent,
        itemWidth: itemWidth,
        itemHeight: itemHeight,
        itemExtent: itemExtent,
        itemCount: itemCount,
        padding: padding,
        reverse: reverse,
        textDirection: textDirection,
      );
      // 如果这个卡片不可见（alpha == 0），则返回这个索引
      if (params.alpha == 0) break;
      endIndex++;
    }

    endIndex = math.min(endIndex, itemCount - 1);

    return endIndex;
  }

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
