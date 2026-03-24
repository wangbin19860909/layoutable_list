import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_multi_window/service_holder.dart';
import 'base/custom_sliver_fixed_extent_base.dart';
import 'algorithms/layout_algorithm.dart';

/// 绘制配置
///
/// [reverse] 对应原来的 reversePaint：true 时 index 大的先绘制（在下层）。
/// [topMostIndex] 不为 -1 时，该 index 的 child 最后绘制（显示在最上层）。
class PaintConfig {
  final bool reverse;
  final int topMostIndex;

  const PaintConfig({
    this.reverse = false,
    this.topMostIndex = -1,
  });

  @override
  bool operator ==(Object other) =>
      other is PaintConfig &&
      other.reverse == reverse &&
      other.topMostIndex == topMostIndex;

  @override
  int get hashCode => Object.hash(reverse, topMostIndex);
}

/// 布局管理器接口
///
/// 提供布局相关的查询接口，供外部组件（如 ScrollPhysics）使用。
/// 这个接口由 RenderObject 实现，作为布局算法和外部组件之间的桥梁。
///
/// 主要用途：
/// 1. 允许 ScrollPhysics 查询 item 的布局信息
/// 2. 提供 item 数量和大小等基本信息
/// 3. 提供 LayoutParams 变化的监听能力
/// LayoutManager 事件回调
typedef OnItemBoundsChanged = void Function(Rect bounds);

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
  ///
  /// 返回值：该 item 的布局参数
  LayoutParams getLayoutParamsForPosition({
    required int index,
    double? scrollOffset,
    double? containerWidth,
    double? containerHeight,
    Size? itemSize,
    int? itemCount,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? edgeSpacing,
    Size? itemSpacing,
    Object? tag,
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
  double getMaxScrollOffset(int itemCount, {
    EdgeInsetsGeometry? padding,
    Size? itemSize,
    EdgeInsetsGeometry? edgeSpacing,
    Size? itemSpacing,
  });

  /// item 总数
  ///
  /// 返回当前列表中的 item 总数。
  int get itemCount;

  /// item 在主轴方向的逻辑大小
  ///
  /// 用于计算滚动距离和滚动进度。
  /// 对于横向滚动，这是 itemWidth；对于纵向滚动，这是 itemHeight。
  double get itemExtent;

  /// 注册监听器，每次 performLayout 后回调
  void addListener(OnItemBoundsChanged listener);

  /// 移除监听器
  void removeListener(OnItemBoundsChanged listener);
}

/// 带 CustomScrollView 的完整堆叠列表组件
class LayoutableListWidget extends StatelessWidget {
  /// 每个 item 的尺寸
  final Size itemSize;

  final Axis scrollDirection;

  /// 是否反转滚动方向
  final bool reverseLayout;

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

  /// 边缘间距（item 与容器边缘的距离）
  final EdgeInsetsGeometry edgeSpacing;

  /// item 间距（主轴方向 width，交叉轴方向 height）
  final Size itemSpacing;

  /// 绘制配置（顺序、topMost 等）
  final PaintConfig paintConfig;

  const LayoutableListWidget({
    super.key,
    required this.itemSize,
    required this.delegate,
    required this.layoutManagerHolder,
    required this.layoutAlgorithm,
    required this.scrollDirection,
    this.physics,
    this.scrollController,
    this.reverseLayout = false,
    this.padding = EdgeInsets.zero,
    this.cacheExtent = 250.0,
    this.edgeSpacing = EdgeInsets.zero,
    this.itemSpacing = Size.zero,
    this.paintConfig = const PaintConfig(),
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      scrollDirection: scrollDirection,
      controller: scrollController,
      physics: physics,
      reverse: reverseLayout,
      cacheExtent: cacheExtent,
      slivers: [
        LayoutableSliverList(
          itemSize: itemSize,
          padding: padding,
          edgeSpacing: edgeSpacing,
          itemSpacing: itemSpacing,
          delegate: delegate,
          layoutManagerHolder: layoutManagerHolder,
          layoutAlgorithm: layoutAlgorithm,
          cacheExtent: cacheExtent,
          paintConfig: paintConfig,
        ),
      ],
    );
  }
}

/// 支持可变宽度的堆叠 Sliver List（基于 MIUI 算法）
class LayoutableSliverList extends SliverMultiBoxAdaptorWidget {
  /// Item 的尺寸
  final Size itemSize;

  /// 内边距（影响主轴方向的可滚动范围和 item 起始位置）
  final EdgeInsetsGeometry padding;

  /// 边缘间距
  final EdgeInsetsGeometry edgeSpacing;

  /// item 间距
  final Size itemSpacing;

  final ServiceHolder<LayoutManager> layoutManagerHolder;

  /// 布局算法
  final LayoutAlgorithm layoutAlgorithm;

  /// 缓存区域大小（默认 250.0）
  final double cacheExtent;

  /// 绘制配置
  final PaintConfig paintConfig;

  const LayoutableSliverList({
    super.key,
    required super.delegate,
    required this.itemSize,
    required this.padding,
    required this.layoutManagerHolder,
    required this.layoutAlgorithm,
    this.edgeSpacing = EdgeInsets.zero,
    this.itemSpacing = Size.zero,
    this.cacheExtent = 250.0,
    this.paintConfig = const PaintConfig(),
  });

  @override
  RenderLayoutableSliverList createRenderObject(BuildContext context) {
    final element = context as SliverMultiBoxAdaptorElement;
    return RenderLayoutableSliverList(
      childManager: element,
      itemSize: itemSize,
      padding: padding,
      edgeSpacing: edgeSpacing,
      itemSpacing: itemSpacing,
      layoutManagerHolder: layoutManagerHolder,
      layoutAlgorithm: layoutAlgorithm,
      textDirection: Directionality.of(context),
      cacheExtent: cacheExtent,
      paintConfig: paintConfig,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLayoutableSliverList renderObject,
  ) {
    renderObject
      ..itemSize = itemSize
      ..padding = padding
      ..edgeSpacing = edgeSpacing
      ..itemSpacing = itemSpacing
      ..layoutAlgorithm = layoutAlgorithm
      ..textDirection = Directionality.of(context)
      ..cacheExtent = cacheExtent
      ..paintConfig = paintConfig;
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
  final Map<int, ValueNotifier<LayoutParams>> _layoutParamsNotifiers = {};

  /// itemBounds 监听器列表
  final List<OnItemBoundsChanged> _itemBoundsListeners = [];

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

  PaintConfig _paintConfig;
  PaintConfig get paintConfig => _paintConfig;
  set paintConfig(PaintConfig value) {
    if (_paintConfig == value) return;
    _paintConfig = value;
    markNeedsPaint();
  }

  RenderLayoutableSliverList({
    required super.childManager,
    required this.layoutManagerHolder,
    required LayoutAlgorithm layoutAlgorithm,
    required Size itemSize,
    required EdgeInsetsGeometry padding,
    required EdgeInsetsGeometry edgeSpacing,
    required Size itemSpacing,
    required TextDirection textDirection,
    required double cacheExtent,
    PaintConfig paintConfig = const PaintConfig(),
  }) : _layoutAlgorithm = layoutAlgorithm,
       _itemSize = itemSize,
       _padding = padding,
       _edgeSpacing = edgeSpacing,
       _itemSpacing = itemSpacing,
       _textDirection = textDirection,
       _cacheExtent = cacheExtent,
       _paintConfig = paintConfig {
    layoutManagerHolder.attach(this);
    // 将缓存传递给算法
    _layoutAlgorithm.setLayoutParamsCache(_layoutParamsCache);
  }

  @override
  void dispose() {
    super.dispose();
    layoutManagerHolder.detach();
    _itemBoundsListeners.clear();
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

  EdgeInsetsGeometry _edgeSpacing;
  EdgeInsetsGeometry get edgeSpacing => _edgeSpacing;
  set edgeSpacing(EdgeInsetsGeometry value) {
    if (_edgeSpacing == value) return;
    _edgeSpacing = value;
    markNeedsLayout();
  }

  Size _itemSpacing;
  Size get itemSpacing => _itemSpacing;
  set itemSpacing(Size value) {
    if (_itemSpacing == value) return;
    _itemSpacing = value;
    markNeedsLayout();
  }

  Size _itemSize;
  Size get itemSize => _itemSize;
  set itemSize(Size value) {
    if (_itemSize == value) return;
    _itemSize = value;
    markNeedsLayout();
  }

  double get itemWidth => _itemSize.width;
  double get itemHeight => _itemSize.height;

  @override
  double get scrollOffset {
    return constraints.scrollOffset + constraints.overlap;
  }

  @override
  double get viewportMainAxisExtent {
    return constraints.viewportMainAxisExtent;
  }

  @override
  double getMaxScrollOffset(int itemCount, {
    EdgeInsetsGeometry? padding,
    Size? itemSize,
    EdgeInsetsGeometry? edgeSpacing,
    Size? itemSpacing,
  }) {
    final resolvedItemSize = itemSize ?? this.itemSize;
    final resolvedItemExtent = isVertical ? resolvedItemSize.height : resolvedItemSize.width;
    final actualScrollExtent = _layoutAlgorithm.computeMaxScrollOffset(
      itemExtent: resolvedItemExtent,
      itemCount: itemCount,
      viewportExtent: constraints.viewportMainAxisExtent,
      padding: padding ?? this.padding,
      edgeSpacing: edgeSpacing ?? this.edgeSpacing,
      itemSpacing: itemSpacing ?? this.itemSpacing,
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
    Size? itemSize,
    int? itemCount,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? edgeSpacing,
    Size? itemSpacing,
    Object? tag,
  }) {
    final resolvedItemSize = itemSize ?? this.itemSize;
    return _layoutAlgorithm.getLayoutParamsForPosition(
      index: index,
      scrollOffset: scrollOffset ?? constraints.scrollOffset + constraints.overlap,
      mainAxisExtent: containerWidth ?? constraints.viewportMainAxisExtent,
      crossAxisExtent: containerHeight ?? constraints.crossAxisExtent,
      itemSize: resolvedItemSize,
      itemCount: itemCount ?? childManager.childCount,
      padding: padding ?? this.padding,
      reverseLayout: isReversed,
      textDirection: textDirection,
      scrollDirection: isVertical ? Axis.vertical : Axis.horizontal,
      edgeSpacing: edgeSpacing ?? this.edgeSpacing,
      itemSpacing: itemSpacing ?? this.itemSpacing,
      tag: tag,
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
  void addListener(OnItemBoundsChanged listener) {
    _itemBoundsListeners.add(listener);
  }

  @override
  void removeListener(OnItemBoundsChanged listener) {
    _itemBoundsListeners.remove(listener);
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
  double calculatePaintOffset(SliverConstraints constraints, {required double from, required double to}) {
    final override = _layoutAlgorithm.calculatePaintExtent(
      constraints,
      from: from,
      to: to,
      edgeSpacing: edgeSpacing,
      itemSpacing: itemSpacing,
    );
    if (override != null) return override.clamp(0.0, constraints.viewportMainAxisExtent);
    return super.calculatePaintOffset(constraints, from: from, to: to);
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
      padding: padding,
      edgeSpacing: edgeSpacing,
      itemSpacing: itemSpacing,
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

  bool _postFrameCallbackScheduled = false;

  @override
  void performLayout() {
    // 清除缓存，因为 scrollOffset 可能已经改变
    _layoutParamsCache.clear();
    super.performLayout();

    // 延迟更新 notifier，避免在布局期间触发 setState
    // 用 flag 去重，一帧内多次 layout 只注册一次回调
    if (!_postFrameCallbackScheduled) {
      _postFrameCallbackScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _postFrameCallbackScheduled = false;
        _updateVisibleNotifiers();
        _notifyItemBoundsChanged();
      });
    }
  }

  /// 计算所有 item 的占用空间（包含 edgeSpacing，不含 padding），通知监听器
  void _notifyItemBoundsChanged() {
    if (_itemBoundsListeners.isEmpty) return;
    if (itemCount == 0) {
      final empty = Rect.zero;
      for (final l in _itemBoundsListeners) { l(empty); }
      return;
    }

    // 用 scrollOffset=0 计算首尾 item 的位置，得到静态布局范围
    final first = getLayoutParamsForPosition(index: 0, scrollOffset: 0);
    final last = getLayoutParamsForPosition(
      index: itemCount - 1,
      scrollOffset: 0,
    );

    // 加上 edgeSpacing
    final edge = edgeSpacing.resolve(textDirection);
    final bounds = Rect.fromLTRB(
      first.rect.left - edge.left,
      first.rect.top - edge.top,
      last.rect.right + edge.right,
      last.rect.bottom + edge.bottom,
    );

    for (final l in _itemBoundsListeners) { l(bounds); }
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
      itemCount: childManager.childCount,
      mainAxisExtent: constraints.viewportMainAxisExtent,
      crossAxisExtent: constraints.crossAxisExtent,
      itemSize: itemSize,
      padding: padding,
      reverseLayout: isReversed,
      cacheExtent: cacheExtent,
      textDirection: textDirection,
      scrollDirection: isVertical ? Axis.vertical : Axis.horizontal,
      edgeSpacing: edgeSpacing,
      itemSpacing: itemSpacing,
    );
    
    return minIndex;
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    final maxIndex = _layoutAlgorithm.getMaxVisibleIndex(
      scrollOffset: constraints.scrollOffset + constraints.overlap,
      itemCount: childManager.childCount,
      mainAxisExtent: constraints.viewportMainAxisExtent,
      crossAxisExtent: constraints.crossAxisExtent,
      itemSize: itemSize,
      padding: padding,
      reverseLayout: isReversed,
      cacheExtent: cacheExtent,
      textDirection: textDirection,
      scrollDirection: isVertical ? Axis.vertical : Axis.horizontal,
      edgeSpacing: edgeSpacing,
      itemSpacing: itemSpacing,
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
      reverseLayout: isReversed,
      edgeSpacing: edgeSpacing,
      itemSpacing: itemSpacing,
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
    // hitTest 顺序与 paint 相反：paint 最后画的在最上层，优先响应事件
    // topMostIndex 不为 -1 时，该 child 最后绘制（最上层），hitTest 时最先检测
    final BoxHitTestResult boxResult = BoxHitTestResult.wrap(result);
    final topMostIndex = _paintConfig.topMostIndex;

    // 先检测 topMostIndex（最上层）
    if (topMostIndex != -1) {
      RenderBox? child = firstChild;
      while (child != null) {
        final childParentData = child.parentData as SliverMultiBoxAdaptorParentData;
        if (childParentData.index == topMostIndex) {
          if (hitTestBoxChild(boxResult, child,
              mainAxisPosition: mainAxisPosition,
              crossAxisPosition: crossAxisPosition)) {
            return true;
          }
          break;
        }
        child = childAfter(child);
      }
    }

    // 再按 paint 逆序检测其余 child
    // reverse=true 时 paint 从 lastChild→firstChild（跳过 topMost），hitTest 从 firstChild→lastChild
    // reverse=false 时 paint 从 firstChild→lastChild（跳过 topMost），hitTest 从 lastChild→firstChild
    RenderBox? child = _paintConfig.reverse ? firstChild : lastChild;
    while (child != null) {
      final childParentData = child.parentData as SliverMultiBoxAdaptorParentData;
      if (childParentData.index != topMostIndex) {
        if (hitTestBoxChild(boxResult, child,
            mainAxisPosition: mainAxisPosition,
            crossAxisPosition: crossAxisPosition)) {
          return true;
        }
      }
      child = _paintConfig.reverse ? childAfter(child) : childBefore(child);
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (firstChild == null) return;

    final topMostIndex = _paintConfig.topMostIndex;
    RenderBox? topMostChild;

    // 按 reverse 顺序绘制所有非 topMostIndex 的 child
    RenderBox? child = _paintConfig.reverse ? lastChild : firstChild;
    while (child != null) {
      final childParentData = child.parentData as SliverMultiBoxAdaptorParentData;
      final index = childParentData.index!;
      if (index == topMostIndex) {
        topMostChild = child;
      } else {
        final params = _getLayoutForPosition(index);
        context.paintChild(child, Offset(params.rect.left, params.rect.top));
      }
      child = _paintConfig.reverse ? childBefore(child) : childAfter(child);
    }

    // 最后绘制 topMostIndex（显示在最上层）
    if (topMostChild != null) {
      final childParentData = topMostChild.parentData as SliverMultiBoxAdaptorParentData;
      final params = _getLayoutForPosition(childParentData.index!);
      context.paintChild(topMostChild, Offset(params.rect.left, params.rect.top));
    }
  }
}
