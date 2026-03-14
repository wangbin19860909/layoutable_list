import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_multi_window/service_holder.dart';
import 'base/custom_sliver_fixed_extent_base.dart';
import 'layout_algorithm.dart';

/// 布局管理器接口
///
/// 提供布局相关的查询接口，供外部组件（如 ScrollPhysics）使用。
/// 这个接口由 RenderObject 实现，作为布局算法和外部组件之间的桥梁。
///
/// 主要用途：
/// 1. 允许 ScrollPhysics 查询 item 的布局信息
/// 2. 提供 item 数量和大小等基本信息
/// 3. 提供 LayoutParams 变化的监听能力
abstract class LayoutManager {
  /// 获取指定 item 的布局参数
  ///
  /// 这是一个便利方法，允许外部组件查询任意 item 的布局信息。
  /// 所有参数都是可选的，未提供的参数会使用当前状态的默认值。
  ///
  /// [index] - item 的索引（必需）
  /// [scrollOffset] - 滚动偏移量（可选，默认使用当前滚动位置）
  /// [containerWidth] - 容器宽度（可选，默认使用当前视口宽度）
  /// [containerHeight] - 容器高度（可选，默认使用当前视口高度）
  /// [itemWidth] - item 宽度（可选，默认使用当前配置的宽度）
  /// [itemHeight] - item 高度（可选，默认使用当前配置的高度）
  /// [itemCount] - item 总数（可选，默认使用当前 item 数量）
  /// [padding] - 内边距（可选，默认使用当前配置的 padding）
  /// [reverse] - 是否反转（可选，默认使用当前滚动方向）
  ///
  /// 返回值：该 item 的布局参数
  LayoutParams getLayoutParamsForPosition({
    required int index,
    double? scrollOffset,
    double? containerWidth,
    double? containerHeight,
    double? itemWidth,
    double? itemHeight,
    int? itemCount,
    EdgeInsetsGeometry? padding,
    bool? reverse,
  });

  /// 监听指定 item 的布局参数变化
  ///
  /// 返回一个 ValueListenable，当该 item 的布局参数发生变化时会通知监听者。
  /// 这允许 widget 响应布局参数的变化，例如：
  /// - 根据 alpha 调整透明度
  /// - 根据 titleAlpha 调整标题显示
  /// - 根据 dimming 显示暗化效果
  ///
  /// 使用示例：
  /// ```dart
  /// Widget buildItem(BuildContext context, int index) {
  ///   final paramsListenable = layoutManager.listenLayoutParamsForPosition(index);
  ///
  ///   return ValueListenableBuilder<LayoutParams>(
  ///     valueListenable: paramsListenable,
  ///     builder: (context, params, child) {
  ///       return Opacity(
  ///         opacity: params.alpha,
  ///         child: YourWidget(),
  ///       );
  ///     },
  ///   );
  /// }
  /// ```
  ///
  /// [index] - item 的索引
  ///
  /// 返回值：可监听的 LayoutParams
  ///
  /// 注意：
  /// - 返回的 ValueListenable 会在 item 可见时自动更新
  /// - 当 item 不可见时，ValueListenable 不会更新（性能优化）
  /// - 不需要手动释放，生命周期由 LayoutManager 管理
  ValueListenable<LayoutParams> listenLayoutParamsForPosition(int index);

  /// 获取当前的滚动偏移量
  double get scrollOffset;

  /// 获取视口主轴方向的大小（宽度或高度）
  double get viewportMainAxisExtent;

  /// 计算指定 item 数量下的最大滚动距离
  ///
  /// [itemCount] - item 总数
  ///
  /// 返回值：最大滚动距离
  double getMaxScrollOffset(int itemCount);

  /// item 总数
  ///
  /// 返回当前列表中的 item 总数。
  int get itemCount;

  /// item 在主轴方向的逻辑大小
  ///
  /// 用于计算滚动距离和滚动进度。
  /// 对于横向滚动，这是 itemWidth；对于纵向滚动，这是 itemHeight。
  double get itemExtent;
}

/// 带 CustomScrollView 的完整堆叠列表组件
class LayoutableListWidget extends StatelessWidget {
  /// 每个 item 的宽度计算函数
  final double itemWidth;

  /// 每个 item 的高度计算函数
  final double itemHeight;

  final Axis scrollDirection;

  /// 是否反转滚动方向
  final bool reverse;

  /// 子元素构建器
  final SliverChildDelegate delegate;

  final ServiceHolder<LayoutManager> layoutManagerHolder;

  /// 布局算法
  final LayoutAlgorithm layoutAlgorithm;

  /// 滚动物理效果
  final ScrollPhysics? physics;

  /// 滚动控制器
  final ScrollController? scrollController;

  /// 内边距（可选）
  final EdgeInsetsGeometry padding;

  /// 缓存区域大小（可选，默认为 250.0）
  final double cacheExtent;

  const LayoutableListWidget({
    super.key,
    required this.itemWidth,
    required this.itemHeight,
    required this.delegate,
    required this.layoutManagerHolder,
    required this.layoutAlgorithm,
    required this.scrollDirection,
    this.physics,
    this.scrollController,
    this.reverse = false,
    this.padding = EdgeInsets.zero,
    this.cacheExtent = 250.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      scrollDirection: scrollDirection,
      controller: scrollController,
      physics: physics,
      reverse: reverse,
      cacheExtent: cacheExtent,
      slivers: [
        LayoutableSliverList(
          itemWidth: itemWidth,
          itemHeight: itemHeight,
          padding: padding,
          delegate: delegate,
          layoutManagerHolder: layoutManagerHolder,
          layoutAlgorithm: layoutAlgorithm,
          cacheExtent: cacheExtent,
        ),
      ],
    );
  }
}

/// 支持可变宽度的堆叠 Sliver List（基于 MIUI 算法）
class LayoutableSliverList extends SliverMultiBoxAdaptorWidget {
  /// Item 的宽度
  final double itemWidth;

  /// Item 的高度
  final double itemHeight;

  /// 左侧 padding（用于调整居中位置）
  final EdgeInsetsGeometry padding;

  final ServiceHolder<LayoutManager> layoutManagerHolder;

  /// 布局算法
  final LayoutAlgorithm layoutAlgorithm;

  /// 缓存区域大小（默认 250.0）
  final double cacheExtent;

  const LayoutableSliverList({
    super.key,
    required super.delegate,
    required this.itemWidth,
    required this.itemHeight,
    required this.padding,
    required this.layoutManagerHolder,
    required this.layoutAlgorithm,
    this.cacheExtent = 250.0,
  });

  @override
  RenderLayoutableSliverList createRenderObject(BuildContext context) {
    final element = context as SliverMultiBoxAdaptorElement;
    return RenderLayoutableSliverList(
      childManager: element,
      itemWidth: itemWidth,
      itemHeight: itemHeight,
      padding: padding,
      layoutManagerHolder: layoutManagerHolder,
      layoutAlgorithm: layoutAlgorithm,
      textDirection: Directionality.of(context),
      cacheExtent: cacheExtent,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLayoutableSliverList renderObject,
  ) {
    renderObject
      ..itemWidth = itemWidth
      ..itemHeight = itemHeight
      ..padding = padding
      ..layoutAlgorithm = layoutAlgorithm
      ..textDirection = Directionality.of(context)
      ..cacheExtent = cacheExtent;
  }

  @override
  SliverMultiBoxAdaptorElement createElement() {
    return SliverMultiBoxAdaptorElement(this);
  }
}

class RenderLayoutableSliverList extends RenderSliverFixedExtentBoxAdaptorBase
    implements LayoutManager {
  final ServiceHolder<LayoutManager> layoutManagerHolder;

  final Map<int, LayoutParams> _layoutParamsCache = {};

  /// LayoutParams 的 ValueNotifier 缓存
  /// key: item index, value: ValueNotifier<LayoutParams>
  final Map<int, ValueNotifier<LayoutParams>> _layoutParamsNotifiers = {};

  LayoutAlgorithm _layoutAlgorithm;
  LayoutAlgorithm get layoutAlgorithm => _layoutAlgorithm;
  set layoutAlgorithm(LayoutAlgorithm value) {
    if (_layoutAlgorithm == value) return;
    _layoutAlgorithm = value;
    // 将缓存传递给新算法
    _layoutAlgorithm.setLayoutParamsCache(_layoutParamsCache);
    markNeedsLayout();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  double _cacheExtent;
  double get cacheExtent => _cacheExtent;
  set cacheExtent(double value) {
    if (_cacheExtent == value) return;
    _cacheExtent = value;
    markNeedsLayout();
  }

  RenderLayoutableSliverList({
    required super.childManager,
    required this.layoutManagerHolder,
    required LayoutAlgorithm layoutAlgorithm,
    required double itemWidth,
    required double itemHeight,
    required EdgeInsetsGeometry padding,
    required TextDirection textDirection,
    required double cacheExtent,
  }) : _layoutAlgorithm = layoutAlgorithm,
       _itemWidth = itemWidth,
       _itemHeight = itemHeight,
       _padding = padding,
       _textDirection = textDirection,
       _cacheExtent = cacheExtent {
    layoutManagerHolder.attach(this);
    // 将缓存传递给算法
    _layoutAlgorithm.setLayoutParamsCache(_layoutParamsCache);
  }

  @override
  void dispose() {
    super.dispose();
    layoutManagerHolder.detach();
    // 释放所有 notifier
    for (final notifier in _layoutParamsNotifiers.values) {
      notifier.dispose();
    }
    _layoutParamsNotifiers.clear();
  }

  EdgeInsetsGeometry _padding;
  EdgeInsetsGeometry get padding => _padding;
  set padding(EdgeInsetsGeometry value) {
    if (_padding == value) return;
    _padding = value;
    markNeedsLayout();
  }

  double _itemWidth;
  double get itemWidth => _itemWidth;
  set itemWidth(double value) {
    if (_itemWidth == value) return;
    _itemWidth = value;
    markNeedsLayout();
  }

  double _itemHeight;
  double get itemHeight => _itemHeight;
  set itemHeight(double value) {
    if (_itemHeight == value) return;
    _itemHeight = value;
    markNeedsLayout();
  }

  @override
  double get scrollOffset {
    return constraints.scrollOffset + constraints.overlap;
  }

  @override
  double get viewportMainAxisExtent {
    return constraints.viewportMainAxisExtent;
  }

  @override
  double getMaxScrollOffset(int itemCount) {
    final actualScrollExtent = _layoutAlgorithm.computeMaxScrollOffset(
      itemExtent: itemExtent,
      itemCount: itemCount,
      viewportExtent: constraints.viewportMainAxisExtent,
    );
    
    return math.max(actualScrollExtent, constraints.viewportMainAxisExtent + 1.0);
  }

  @override
  int get itemCount => childManager.childCount;

  @override
  LayoutParams getLayoutParamsForPosition({
    required int index,
    double? scrollOffset,
    double? containerWidth,
    double? containerHeight,
    double? itemWidth,
    double? itemHeight,
    int? itemCount,
    EdgeInsetsGeometry? padding,
    bool? reverse,
  }) {
    return _layoutAlgorithm.getLayoutParamsForPosition(
      index: index,
      scrollOffset: scrollOffset ?? constraints.scrollOffset + constraints.overlap,
      mainAxisExtent: containerWidth ?? constraints.viewportMainAxisExtent,
      crossAxisExtent: containerHeight ?? constraints.crossAxisExtent,
      itemWidth: itemWidth ?? this.itemWidth,
      itemHeight: itemHeight ?? this.itemHeight,
      itemExtent: itemExtent,
      itemCount: itemCount ?? childManager.childCount,
      padding: padding ?? this.padding,
      reverse: reverse ?? isReversed,
      textDirection: textDirection,
    );
  }

  @override
  ValueListenable<LayoutParams> listenLayoutParamsForPosition(int index) {
    // 如果已经存在，直接返回
    if (_layoutParamsNotifiers.containsKey(index)) {
      return _layoutParamsNotifiers[index]!;
    }

    // 创建新的 notifier
    final initialParams = getLayoutParamsForPosition(index: index);
    final notifier = ValueNotifier<LayoutParams>(initialParams);
    _layoutParamsNotifiers[index] = notifier;

    return notifier;
  }

  bool get isReversed =>
      constraints.axisDirection == AxisDirection.left ||
      constraints.axisDirection == AxisDirection.up;
  bool get isVertical =>
      constraints.axisDirection == AxisDirection.up ||
      constraints.axisDirection == AxisDirection.down;

  /// 获取指定 index 的布局参数（带缓存）
  LayoutParams _getLayoutForPosition(int index) {
    // 先从缓存获取
    if (_layoutParamsCache.containsKey(index)) {
      return _layoutParamsCache[index]!;
    }

    final params = getLayoutParamsForPosition(index: index);

    // 存入缓存
    _layoutParamsCache[index] = params;
    return params;
  }

  @override
  double get itemExtent {
    return isVertical ? itemHeight : itemWidth;
  }

  @override
  double childCrossAxisPosition(RenderBox child) {
    final childParentData = child.parentData as SliverMultiBoxAdaptorParentData;
    final index = childParentData.index;
    
    if (index == null) {
      return 0.0;
    }
    
    // 从缓存获取布局参数
    final params = _getLayoutForPosition(index);
    
    // 根据滚动方向返回交叉轴位置
    if (isVertical) {
      // 纵向滚动：交叉轴是水平方向，返回 left
      return params.rect.left;
    } else {
      // 横向滚动：交叉轴是垂直方向，返回 top
      return params.rect.top;
    }
  }

  @override
  double computeMaxScrollOffset(
    SliverConstraints constraints,
    double itemExtent,
  ) {
    final actualScrollExtent = _layoutAlgorithm.computeMaxScrollOffset(
      itemExtent: itemExtent,
      itemCount: itemCount,
      viewportExtent: constraints.viewportMainAxisExtent,
    );
    
    // 确保至少大于 viewport，这样即使内容少也能 overscroll
    // 添加一个小的额外空间（1像素）来触发滚动
    return math.max(actualScrollExtent, constraints.viewportMainAxisExtent + 1.0);
  }

  @override
  double estimateMaxScrollOffset(
    SliverConstraints constraints, {
    int? firstIndex,
    int? lastIndex,
    double? leadingScrollOffset,
    double? trailingScrollOffset,
  }) {
    // 使用我们自己的 computeMaxScrollOffset 而不是默认的估算
    return computeMaxScrollOffset(constraints, itemExtent);
  }

  @override
  void performLayout() {
    // 清除缓存，因为 scrollOffset 可能已经改变
    _layoutParamsCache.clear();

    super.performLayout();

    // 延迟更新 notifier，避免在布局期间触发 setState
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateVisibleNotifiers();
    });
  }

  /// 更新可见 item 的 LayoutParams notifier
  void _updateVisibleNotifiers() {
    if (firstChild == null) return;

    // 遍历所有可见的子元素
    RenderBox? child = firstChild;

    while (child != null) {
      final childParentData =
          child.parentData as SliverMultiBoxAdaptorParentData;
      final index = childParentData.index;

      if (index != null) {
        // 如果该 index 有 notifier，更新它
        if (_layoutParamsNotifiers.containsKey(index)) {
          final params = _getLayoutForPosition(index);
          _layoutParamsNotifiers[index]!.value = params;
        }
      }

      child = childAfter(child);
    }
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    final minIndex = _layoutAlgorithm.getMinVisibleIndex(
      scrollOffset: constraints.scrollOffset + constraints.overlap,
      itemExtent: itemExtent,
      itemCount: childManager.childCount,
      mainAxisExtent: constraints.viewportMainAxisExtent,
      crossAxisExtent: constraints.crossAxisExtent,
      itemWidth: itemWidth,
      itemHeight: itemHeight,
      padding: padding,
      reverse: isReversed,
      cacheExtent: cacheExtent,
      textDirection: textDirection,
    );
    
    return minIndex;
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    final maxIndex = _layoutAlgorithm.getMaxVisibleIndex(
      scrollOffset: constraints.scrollOffset + constraints.overlap,
      itemExtent: itemExtent,
      itemCount: childManager.childCount,
      mainAxisExtent: constraints.viewportMainAxisExtent,
      crossAxisExtent: constraints.crossAxisExtent,
      itemWidth: itemWidth,
      itemHeight: itemHeight,
      padding: padding,
      reverse: isReversed,
      cacheExtent: cacheExtent,
      textDirection: textDirection,
    );
    
    return maxIndex;
  }

  @override
  double indexToLayoutOffset(double itemExtent, int index) {
    return _layoutAlgorithm.indexToLayoutOffset(
      index: index,
      itemExtent: itemExtent,
      scrollOffset: constraints.scrollOffset + constraints.overlap,
      viewportExtent: constraints.viewportMainAxisExtent,
      reverse: isReversed,
    );
  }

  @override
  BoxConstraints getChildConstraints(int index) {
    // 使用缓存的布局参数
    final params = _getLayoutForPosition(index);

    // 返回缩放后的尺寸（rect 中已经包含了 scale）
    return BoxConstraints.tightFor(
      width: params.rect.width,
      height: params.rect.height,
    );
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    RenderBox? child = firstChild;
    final BoxHitTestResult boxResult = BoxHitTestResult.wrap(result);
    while (child != null) {
      if (hitTestBoxChild(
        boxResult,
        child,
        mainAxisPosition: mainAxisPosition,
        crossAxisPosition: crossAxisPosition,
      )) {
        return true;
      }
      child = childAfter(child);
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (firstChild == null) {
      return;
    }

    RenderBox? child = lastChild;
    // 按照正确的 z-order 绘制（后面的先绘制）
    while (child != null) {
      final childParentData =
          child.parentData as SliverMultiBoxAdaptorParentData;
      final index = childParentData.index!;

      // 使用缓存的布局参数
      final params = _getLayoutForPosition(index);
      final rect = params.rect;

      // 计算子元素的绘制位置
      // paintChild 的 offset 是相对于当前 Sliver 的位置
      final childOffset = Offset(rect.left, rect.top);

      // 直接在正确的位置绘制子元素
      context.paintChild(child, childOffset);

      child = childBefore(child);
    }
  }
}
