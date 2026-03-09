// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// 这是 RenderSliverFixedExtentBoxAdaptor 的副本
// 唯一的修改：将 _getChildConstraints 改为 protected，允许子类重写

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// 基类，允许子类自定义子元素的约束
/// 
/// 这是 [RenderSliverFixedExtentBoxAdaptor] 的副本，
/// 唯一的修改是将 `_getChildConstraints` 改为 protected 方法 `getChildConstraints`，
/// 允许子类重写以提供自定义的子元素约束。
abstract class RenderSliverFixedExtentBoxAdaptorBase extends RenderSliverMultiBoxAdaptor {
  /// Creates a sliver that contains multiple box children that have the same
  /// extent along the main axis.
  RenderSliverFixedExtentBoxAdaptorBase({
    required super.childManager,
  });

  /// The main-axis extent of each item.
  double get itemExtent;

  /// Precision error tolerance for floating point comparisons
  static const double precisionErrorTolerance = 1e-10;

  /// The layout offset for the child with the given index.
  ///
  /// This function uses the returned value of [itemExtent] to avoid recomputing
  /// item extent repeatedly during layout.
  ///
  /// By default, places the children in order, without gaps, starting from
  /// layout offset zero.
  @protected
  double indexToLayoutOffset(
    @Deprecated(
      'The itemExtent is already available within the scope of this function. '
      'This feature was deprecated after v3.20.0-7.0.pre.'
    )
    double itemExtent,
    int index,
  ) => index * this.itemExtent;

  /// The minimum child index that is visible at the given scroll offset.
  ///
  /// This function uses the returned value of [itemExtent] to avoid recomputing
  /// item extent repeatedly during layout.
  ///
  /// By default, returns a value consistent with the children being placed in
  /// order, without gaps, starting from layout offset zero.
  @protected
  int getMinChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    if (itemExtent > 0.0) {
      final double actual = scrollOffset / itemExtent;
      final int round = actual.round();
      if ((actual * itemExtent - round * itemExtent).abs() < precisionErrorTolerance) {
        return round;
      }
      return actual.floor();
    }
    return 0;
  }

  /// The maximum child index that is visible at the given scroll offset.
  ///
  /// This function uses the returned value of [itemExtent] to avoid recomputing
  /// item extent repeatedly during layout.
  ///
  /// By default, returns a value consistent with the children being placed in
  /// order, without gaps, starting from layout offset zero.
  @protected
  int getMaxChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    if (itemExtent > 0.0) {
      final double actual = scrollOffset / itemExtent - 1;
      final int round = actual.round();
      if ((actual * itemExtent - round * itemExtent).abs() < precisionErrorTolerance) {
        return math.max(0, round);
      }
      return math.max(0, actual.ceil());
    }
    return 0;
  }

  double estimateMaxScrollOffset(
    SliverConstraints constraints, {
    int? firstIndex,
    int? lastIndex,
    double? leadingScrollOffset,
    double? trailingScrollOffset,
  }) {
    return childManager.estimateMaxScrollOffset(
      constraints,
      firstIndex: firstIndex,
      lastIndex: lastIndex,
      leadingScrollOffset: leadingScrollOffset,
      trailingScrollOffset: trailingScrollOffset,
    );
  }

  /// Called to estimate the total scrollable extents of this object.
  ///
  /// Must return the total distance from the start of the child with the
  /// earliest possible index to the end of the child with the last possible
  /// index.
  ///
  /// By default, defers to [RenderSliverBoxChildManager.estimateMaxScrollOffset].
  ///
  /// See also:
  ///
  ///  * [computeMaxScrollOffset], which is similar but must provide a precise
  ///    value.
  @protected
  double computeMaxScrollOffset(SliverConstraints constraints, double itemExtent) {
    return childManager.childCount * itemExtent;
  }

  int _calculateLeadingGarbage(int firstIndex) {
    RenderBox? walker = firstChild;
    int leadingGarbage = 0;
    while (walker != null && indexOf(walker) < firstIndex) {
      leadingGarbage += 1;
      walker = childAfter(walker);
    }
    return leadingGarbage;
  }

  int _calculateTrailingGarbage(int targetLastIndex) {
    RenderBox? walker = lastChild;
    int trailingGarbage = 0;
    while (walker != null && indexOf(walker) > targetLastIndex) {
      trailingGarbage += 1;
      walker = childBefore(walker);
    }
    return trailingGarbage;
  }

  /// 获取子元素的约束
  /// 
  /// 这个方法是 protected 的，允许子类重写以提供自定义约束
  /// 
  /// 原始的 RenderSliverFixedExtentBoxAdaptor 中这是一个私有方法 `_getChildConstraints`
  @protected
  BoxConstraints getChildConstraints(int index) {
    return constraints.asBoxConstraints(
      minExtent: itemExtent,
      maxExtent: itemExtent,
    );
  }

  @override
  void performLayout() {
    final SliverConstraints constraints = this.constraints;
    childManager.didStartLayout();
    childManager.setDidUnderflow(false);

    final double itemExtent = this.itemExtent;
    final double scrollOffset = constraints.scrollOffset + constraints.cacheOrigin;
    assert(scrollOffset >= 0.0);
    final double remainingExtent = constraints.remainingCacheExtent;
    assert(remainingExtent >= 0.0);
    final double targetEndScrollOffset = scrollOffset + remainingExtent;

    final int firstIndex = getMinChildIndexForScrollOffset(scrollOffset, itemExtent);
    final int? targetLastIndex = targetEndScrollOffset.isFinite ?
        getMaxChildIndexForScrollOffset(targetEndScrollOffset, itemExtent) : null;

    if (firstChild != null) {
      final int leadingGarbage = _calculateLeadingGarbage(firstIndex);
      final int trailingGarbage = targetLastIndex != null ? _calculateTrailingGarbage(targetLastIndex) : 0;
      collectGarbage(leadingGarbage, trailingGarbage);
    } else {
      collectGarbage(0, 0);
    }

    if (firstChild == null) {
      if (!addInitialChild(index: firstIndex, layoutOffset: indexToLayoutOffset(itemExtent, firstIndex))) {
        // There are either no children, or we are past the end of all our children.
        final double max = computeMaxScrollOffset(constraints, itemExtent);
        geometry = SliverGeometry(
          scrollExtent: max,
          maxPaintExtent: max,
        );
        childManager.didFinishLayout();
        return;
      }
    }

    RenderBox? trailingChildWithLayout;

    for (int index = indexOf(firstChild!) - 1; index >= firstIndex; --index) {
      final RenderBox? child = insertAndLayoutLeadingChild(getChildConstraints(index));
      if (child == null) {
        // Items before the previously first child are no longer present.
        // Reset the scroll offset to offset all items prior and up to the
        // missing item. Let parent re-layout everything.
        geometry = SliverGeometry(scrollOffsetCorrection: index * itemExtent);
        return;
      }
      final SliverMultiBoxAdaptorParentData childParentData = child.parentData! as SliverMultiBoxAdaptorParentData;
      childParentData.layoutOffset = indexToLayoutOffset(itemExtent, index);
      assert(childParentData.index == index);
      trailingChildWithLayout ??= child;
    }

    if (trailingChildWithLayout == null) {
      firstChild!.layout(getChildConstraints(indexOf(firstChild!)));
      final SliverMultiBoxAdaptorParentData childParentData = firstChild!.parentData! as SliverMultiBoxAdaptorParentData;
      childParentData.layoutOffset = indexToLayoutOffset(itemExtent, firstIndex);
      trailingChildWithLayout = firstChild;
    }

    for (int index = indexOf(trailingChildWithLayout!) + 1; targetLastIndex == null || index <= targetLastIndex; ++index) {
      RenderBox? child = childAfter(trailingChildWithLayout!);
      if (child == null || indexOf(child) != index) {
        child = insertAndLayoutChild(getChildConstraints(index), after: trailingChildWithLayout);
        if (child == null) {
          // We have run out of children.
          break;
        }
      } else {
        child.layout(getChildConstraints(index));
      }
      trailingChildWithLayout = child;
      final SliverMultiBoxAdaptorParentData childParentData = child.parentData! as SliverMultiBoxAdaptorParentData;
      assert(childParentData.index == index);
      childParentData.layoutOffset = indexToLayoutOffset(
        itemExtent,
        childParentData.index!,
      );
    }

    final int lastIndex = indexOf(lastChild!);
    final double leadingScrollOffset = indexToLayoutOffset(itemExtent, firstIndex);
    final double trailingScrollOffset = indexToLayoutOffset(
      itemExtent,
      lastIndex + 1,
    );

    assert(firstIndex == 0 || childScrollOffset(firstChild!)! - scrollOffset <= precisionErrorTolerance);
    assert(debugAssertChildListIsNonEmptyAndContiguous());
    assert(indexOf(firstChild!) == firstIndex);
    assert(targetLastIndex == null || lastIndex <= targetLastIndex);

    final double estimatedMaxScrollOffset = estimateMaxScrollOffset(
      constraints,
      firstIndex: firstIndex,
      lastIndex: lastIndex,
      leadingScrollOffset: leadingScrollOffset,
      trailingScrollOffset: trailingScrollOffset,
    );

    final double paintExtent = calculatePaintOffset(
      constraints,
      from: leadingScrollOffset,
      to: trailingScrollOffset,
    );

    final double cacheExtent = calculateCacheOffset(
      constraints,
      from: leadingScrollOffset,
      to: trailingScrollOffset,
    );

    final double targetEndScrollOffsetForPaint = constraints.scrollOffset + constraints.remainingPaintExtent;
    final int? targetLastIndexForPaint = targetEndScrollOffsetForPaint.isFinite ?
        getMaxChildIndexForScrollOffset(targetEndScrollOffsetForPaint, itemExtent) : null;
    
    geometry = SliverGeometry(
      scrollExtent: estimatedMaxScrollOffset,
      paintExtent: paintExtent,
      cacheExtent: cacheExtent,
      maxPaintExtent: estimatedMaxScrollOffset,
      // Conservative to avoid flickering away the clip during scroll.
      hasVisualOverflow: (targetLastIndexForPaint != null && lastIndex >= targetLastIndexForPaint)
        || constraints.scrollOffset > 0.0,
    );

    // We may have started the layout while scrolled to the end, which would not
    // expose a new child.
    if (estimatedMaxScrollOffset == trailingScrollOffset) {
      childManager.setDidUnderflow(true);
    }
    childManager.didFinishLayout();
  }
}
