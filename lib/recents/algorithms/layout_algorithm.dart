import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 布局参数
/// 
/// 描述单个 item 在视口中的完整布局信息，包括位置、大小、透明度等视觉属性。
/// 这些参数由布局算法计算，用于渲染层绘制 item。
class LayoutParams {
  /// item 的位置和大小（已应用缩放）
  /// 
  /// rect 的坐标是相对于 Sliver 的局部坐标系。
  /// 宽高已经包含了 scale 的效果，可以直接用于设置 BoxConstraints。
  final Rect rect;

  /// 缩放比例
  /// 
  /// 用于某些算法（如 Stack）计算缩放后的尺寸。
  /// 注意：rect 中的宽高已经是缩放后的值。
  final double scale;

  /// 透明度 (0.0 - 1.0)
  /// 
  /// 0.0 表示完全透明（不可见），1.0 表示完全不透明。
  /// 当 alpha <= 0 时，item 可以跳过绘制。
  final double alpha;

  /// 暗化程度 (0.0 - 1.0)
  /// 
  /// 用于在 item 上叠加黑色半透明层，模拟深度效果。
  /// 0.0 表示不暗化，1.0 表示完全黑色。
  final double dimming;

  /// 标题透明度 (0.0 - 1.0)
  /// 
  /// 用于控制 item 内标题文字的透明度。
  /// 某些算法可能让远处的 item 标题逐渐淡出。
  final double titleAlpha;

  /// 头部透明度 (0.0 - 1.0)
  /// 
  /// 用于控制 item 内头部区域的透明度。
  final double headerAlpha;

  /// 阴影透明度 (0.0 - 1.0)
  /// 
  /// 用于控制 item 阴影的透明度，增强深度感。
  final double shadowAlpha;

  const LayoutParams({
    required this.rect,
    required this.scale,
    required this.alpha,
    required this.dimming,
    required this.titleAlpha,
    required this.headerAlpha,
    required this.shadowAlpha,
  });

  @override
  String toString() {
    return 'LayoutParams(rect: $rect, scale: $scale, alpha: $alpha, '
        'dimming: $dimming, titleAlpha: $titleAlpha, headerAlpha: $headerAlpha, '
        'shadowAlpha: $shadowAlpha)';
  }
}

/// 布局算法接口
/// 
/// 定义了计算 item 布局的核心接口。不同的布局算法（如堆叠、网格）
/// 通过实现这个接口来提供不同的布局效果。
/// 
/// 布局算法的职责：
/// 1. 根据 item 索引和滚动位置计算每个 item 的布局参数
/// 2. 确定哪些 item 在当前视口中可见
/// 3. 计算最大滚动范围
/// 
/// 算法可以选择性地使用缓存来提高性能。
abstract class LayoutAlgorithm {
  /// 布局参数缓存（可选）
  /// 
  /// 由 RenderObject 提供，算法可以选择使用缓存来避免重复计算。
  /// 缓存的生命周期由 RenderObject 管理，每次 performLayout 时会清空。
  @protected
  Map<int, LayoutParams>? layoutParamsCache;

  /// 设置布局参数缓存（可选）
  /// 
  /// 由 RenderObject 调用，将缓存 Map 传递给算法。
  /// 算法可以选择使用或忽略缓存。
  /// 
  /// [cache] - 缓存 Map，key 是 item index，value 是 LayoutParams
  void setLayoutParamsCache(Map<int, LayoutParams>? cache) {
    layoutParamsCache = cache;
  }

  /// 获取布局参数（优先使用缓存）
  /// 
  /// 这是一个便利方法，子类算法在内部调用时可以使用它来自动处理缓存。
  /// 如果缓存中存在，直接返回；否则调用 [getLayoutParamsForPosition] 计算。
  /// 
  /// 注意：这个方法主要用于算法内部（如在 getMinVisibleIndex 中），
  /// 外部调用者应该直接调用 [getLayoutParamsForPosition]。
  /// 
  /// 参数说明见 [getLayoutParamsForPosition]。
  LayoutParams getLayoutParamsWithCache({
    required int index,
    required double scrollOffset,
    required double mainAxisExtent,
    required double crossAxisExtent,
    required double itemWidth,
    required double itemHeight,
    required int itemCount,
    required EdgeInsetsGeometry padding,
    required bool reverse,
    required TextDirection textDirection,
    required Axis scrollDirection,
  }) {
    if (layoutParamsCache != null && layoutParamsCache!.containsKey(index)) {
      return layoutParamsCache![index]!;
    }

    final params = getLayoutParamsForPosition(
      index: index,
      scrollOffset: scrollOffset,
      mainAxisExtent: mainAxisExtent,
      crossAxisExtent: crossAxisExtent,
      itemWidth: itemWidth,
      itemHeight: itemHeight,
      itemCount: itemCount,
      padding: padding,
      reverseLayout: reverse,
      textDirection: textDirection,
      scrollDirection: scrollDirection,
    );

    if (layoutParamsCache != null) {
      layoutParamsCache![index] = params;
    }

    return params;
  }

  /// 计算最大滚动偏移量
  /// 
  /// 返回滚动视图可以滚动到的最大像素偏移量。
  /// 这个值决定了滚动条的范围和滚动行为。
  /// 
  /// [itemExtent] - 每个 item 在主轴方向的逻辑大小（用于计算滚动距离）
  /// [itemCount] - item 总数
  /// [viewportExtent] - 视口在主轴方向的大小（用于计算最后一个 item 能滚动到的位置）
  /// 
  /// 返回值：最大滚动偏移量（像素）
  double computeMaxScrollOffset({
    required double itemExtent,
    required int itemCount,
    required double viewportExtent,
  });

  /// 计算绘制范围（可选覆盖）
  ///
  /// 返回 null 表示使用默认的 calculatePaintOffset 计算。
  /// 返回具体值时，RenderLayoutableSliverList 会直接使用该值作为 paintExtent。
  ///
  /// Stack 等重叠布局应覆盖此方法返回 mainAxisExtent，
  /// 因为默认的 from/to 差值计算对重叠布局不适用。
  double? calculatePaintExtent(
    SliverConstraints constraints, {
    required double from,
    required double to,
  }) => null;

  /// 根据 index 和滚动偏移量计算布局参数
  /// 
  /// 这是布局算法的核心方法，根据 item 索引和当前滚动位置，
  /// 计算该 item 应该如何显示（位置、大小、透明度等）。
  /// 
  /// [index] - item 的索引（从 0 开始）
  /// [scrollOffset] - 当前滚动偏移量（像素），表示视口滚动了多少距离
  /// [mainAxisExtent] - 容器宽度（视口主轴方向的大小）
  /// [crossAxisExtent] - 容器高度（视口交叉轴方向的大小）
  /// [itemWidth] - item 的原始宽度（未缩放）
  /// [itemHeight] - item 的原始高度（未缩放）
  /// [itemExtent] - item 在主轴方向的逻辑大小（用于计算滚动进度）
  /// [itemCount] - item 总数
  /// [padding] - 容器的内边距（EdgeInsetsGeometry，需要用 textDirection 解析）
  /// [reverseLayout] - 是否反转滚动方向（true: 从右往左/从下往上，false: 从左往右/从上往下）
  /// [textDirection] - 文本方向（用于解析 padding，支持 RTL 布局）
  /// 
  /// 返回值：该 item 的布局参数
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
  });

  /// 获取给定 scrollOffset 下的最小可见 item 索引
  /// 
  /// 确定在当前滚动位置下，第一个需要渲染的 item 索引。
  /// 这个方法用于优化性能，只渲染可见的 item。
  /// 
  /// [scrollOffset] - 当前滚动偏移量（像素）
  /// [itemCount] - item 总数
  /// [mainAxisExtent] - 容器主轴方向大小
  /// [crossAxisExtent] - 容器交叉轴方向大小
  /// [itemWidth] - item 的原始宽度
  /// [itemHeight] - item 的原始高度
  /// [padding] - 容器的内边距
  /// [reverseLayout] - 是否反转滚动方向
  /// [cacheExtent] - 缓存区域大小（视口外需要预渲染的距离）
  /// [textDirection] - 文本方向
  /// [scrollDirection] - 滚动方向，内部用于计算 itemExtent
  /// 
  /// 返回值：最小可见 item 的索引（包含缓存区域）
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
  });

  /// 获取给定 scrollOffset 下的最大可见 item 索引
  /// 
  /// 确定在当前滚动位置下，最后一个需要渲染的 item 索引。
  /// 这个方法用于优化性能，只渲染可见的 item。
  /// 
  /// 参数说明见 [getMinVisibleIndex]。
  /// 
  /// 返回值：最大可见 item 的索引（包含缓存区域）
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
  });

  /// 计算绘制范围（可选覆盖）
  ///
  /// 返回 null 表示使用默认的 calculatePaintOffset 计算。
  /// 返回具体值时，RenderLayoutableSliverList 会直接使用该值作为 paintExtent。
  ///
  /// Stack 等重叠布局应覆盖此方法返回 mainAxisExtent，
  /// 因为默认的 from/to 差值计算对重叠布局不适用。
  /// 计算指定 item 在滚动轴上的起始位置（像素偏移量）。
  /// 这个方法用于滚动到指定 item 或计算滚动范围。
  /// 
  /// [index] - item 的索引
  /// [itemExtent] - item 在主轴方向的逻辑大小
  /// [scrollOffset] - 当前滚动偏移量
  /// [viewportExtent] - 视口大小
  /// [reverseLayout] - 是否反转方向
  /// 
  /// 返回值：该 item 的起始位置（像素偏移量）
  double indexToLayoutOffset({
    required int index,
    required double itemExtent,
    required double scrollOffset,
    required double viewportExtent,
    required bool reverseLayout,
  });

  /// 软边界 clamp：输出永远在 [min, max] 内，但在接近边界的 [margin] 区间内
  /// 用指数曲线压缩，越接近边界阻力越大，不会硬截断
  @protected
  double softClamp(double value, double min, double max, double margin) {
    assert(max - min > margin * 2, 'range must be larger than 2 * margin');
    if (value < min + margin) {
      // 在 min 侧阻尼区：将 (-∞, min+margin) 映射到 [min, min+margin)
      final double t = (min + margin - value) / margin; // t ∈ (0, +∞)
      return min + margin * math.exp(-t);
    } else if (value > max - margin) {
      // 在 max 侧阻尼区：将 (max-margin, +∞) 映射到 (max-margin, max]
      final double t = (value - (max - margin)) / margin; // t ∈ (0, +∞)
      return max - margin * math.exp(-t);
    }
    return value;
  }

}
