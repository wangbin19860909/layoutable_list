import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/physics.dart';

/// 限制 overscroll 范围的 ScrollPhysics
///
/// 始终使用 ScrollSpringSimulation，通过调整 spring 的 damping 来控制 overscroll 距离。
///
/// 拖动阶段（applyPhysicsToUserOffset）：
///   施加渐进阻尼，确保手动拖动的 overscroll 不超过 maxOverscrollExtent。
///
/// 松手阶段（createBallisticSimulation）：
///   1. 用默认 damping 预测 spring 的最大 overscroll 距离
///   2. 若 ≤ maxOverscrollExtent，直接使用默认 spring
///   3. 若 > maxOverscrollExtent，二分反算一个更大的 damping，
///      使 spring 最大位移恰好等于 maxOverscrollExtent
class LimitedOverscrollPhysics extends BouncingScrollPhysics {
  /// overscroll 的最大距离（像素）
  final double maxOverscrollExtent;

  const LimitedOverscrollPhysics({
    super.parent,
    this.maxOverscrollExtent = 100.0,
  });

  @override
  LimitedOverscrollPhysics applyTo(ScrollPhysics? ancestor) {
    ScrollPhysics? newAncestor = ancestor;
    if (ancestor is BouncingScrollPhysics && ancestor is! LimitedOverscrollPhysics) {
      newAncestor = ancestor.parent;
    }
    return LimitedOverscrollPhysics(
      parent: buildParent(newAncestor),
      maxOverscrollExtent: maxOverscrollExtent,
    );
  }

  // 固定的 spring 物理参数（mass 和 stiffness 不变，只调整 damping）
  static const double _mass = 0.5;
  static const double _stiffness = 20.0;  // 调软，减速更自然
  // 默认 damping ratio（用于 overscroll 弹回，略微过阻尼）
  static const double _defaultDampingRatio = 1.1;
  // 范围内减速用的 damping ratio（高过阻尼，确保不回弹）
  static const double _decelerationDampingRatio = 5.0;

  static double get _defaultDamping =>
      _defaultDampingRatio * 2.0 * math.sqrt(_mass * _stiffness);

  static double get _decelerationDamping =>
      _decelerationDampingRatio * 2.0 * math.sqrt(_mass * _stiffness);

  /// 构造指定 damping 的 SpringDescription
  static SpringDescription _springWithDamping(double damping) {
    return SpringDescription(mass: _mass, stiffness: _stiffness, damping: damping);
  }

  @override
  SpringDescription get spring => _springWithDamping(_defaultDamping);

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // 允许在 [min - maxOverscrollExtent, max + maxOverscrollExtent] 范围内自由移动
    // 超出这个范围的部分作为 overscroll 返回，ScrollPosition 会自动 clamp
    final double hardMin = position.minScrollExtent - maxOverscrollExtent;
    final double hardMax = position.maxScrollExtent + maxOverscrollExtent;
    if (value < hardMin) return value - hardMin;
    if (value > hardMax) return value - hardMax;
    return 0.0;
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (!position.outOfRange) {
      return offset;
    }

    final double overscrollPastStart = math.max(position.minScrollExtent - position.pixels, 0.0);
    final double overscrollPastEnd = math.max(position.pixels - position.maxScrollExtent, 0.0);
    final double overscrollPast = math.max(overscrollPastStart, overscrollPastEnd);

    // 判断是否在继续往外拖（tensioning）
    final bool tensioning =
        (overscrollPastStart > 0.0 && offset > 0.0) ||
        (overscrollPastEnd > 0.0 && offset < 0.0);

    if (!tensioning) {
      return super.applyPhysicsToUserOffset(position, offset);
    }

    // 已达到最大值，完全阻止
    if (overscrollPast >= maxOverscrollExtent) {
      return 0.0;
    }

    // 渐进阻尼：ratio=0 时无阻力，ratio=1 时完全阻止
    // 同时 clamp offset，确保单帧不会冲过 maxOverscrollExtent
    final double ratio = overscrollPast / maxOverscrollExtent;
    final double frictionFactor = (1.0 - ratio) * (1.0 - ratio);
    final double dampedOffset = offset * frictionFactor;
    // 硬性保证：position + dampedOffset 不超过 maxOverscrollExtent
    final double remaining = maxOverscrollExtent - overscrollPast;
    final double clampedOffset = dampedOffset.sign * math.min(dampedOffset.abs(), remaining);
    return clampedOffset;
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final Tolerance tolerance = toleranceFor(position);

    if (velocity.abs() < tolerance.velocity && !position.outOfRange) {
      return null;
    }

    // 当前 overscroll
    final double overscrollPastStart = math.max(position.minScrollExtent - position.pixels, 0.0);
    final double overscrollPastEnd = math.max(position.pixels - position.maxScrollExtent, 0.0);
    final double currentOverscroll = math.max(overscrollPastStart, overscrollPastEnd);

    // 已经超过限制，直接 spring 弹回边界
    if (currentOverscroll > maxOverscrollExtent) {
      final double target = overscrollPastStart > 0
          ? position.minScrollExtent
          : position.maxScrollExtent;
      // 如果速度还在往外冲，清零速度直接弹回，避免继续冲出去
      final bool movingOutward =
          (overscrollPastStart > 0 && velocity < 0) ||
          (overscrollPastEnd > 0 && velocity > 0);
      final double effectiveVelocity = movingOutward ? 0.0 : velocity;
      return ScrollSpringSimulation(spring, position.pixels, target, effectiveVelocity,
          tolerance: tolerance);
    }

    final bool headingToStart = velocity < 0.0;
    final bool headingToEnd = velocity > 0.0;
    final bool alreadyAtStart = position.pixels <= position.minScrollExtent;
    final bool alreadyAtEnd = position.pixels >= position.maxScrollExtent;

    // 用 FrictionSimulation 预测惯性终点，判断是否真的能到达边界
    final double frictionFinalX = FrictionSimulation(_defaultDrag, position.pixels, velocity).finalX;
    final bool frictionReachesBoundary =
        (headingToStart && frictionFinalX <= position.minScrollExtent) ||
        (headingToEnd && frictionFinalX >= position.maxScrollExtent);

    // 确定是否会越界
    final bool willOvershoot =
        frictionReachesBoundary ||
        (alreadyAtStart && headingToStart) ||
        (alreadyAtEnd && headingToEnd);

    if (!willOvershoot) {
      // 在范围内减速停止：spring 滑向 friction 预测的终点（clamp 到边界内）
      final double target = frictionFinalX.clamp(position.minScrollExtent, position.maxScrollExtent);
      return ScrollSpringSimulation(
          _springWithDamping(_decelerationDamping), position.pixels, target, velocity,
          tolerance: tolerance);
    }

    // 确定边界和 overscroll 目标点
    final double boundary = (headingToStart || alreadyAtStart)
        ? position.minScrollExtent
        : position.maxScrollExtent;
    // overscroll 目标点：boundary 外 maxOverscrollExtent 处
    // spring 的 end 设为这里，spring 自然减速停在此处再弹回 boundary
    // Flutter 不会在 boundary 处打断 spring（因为 end 在 boundary 外面）
    final double overscrollSign = headingToStart ? -1.0 : 1.0;
    final double overscrollTarget = boundary + overscrollSign * maxOverscrollExtent;

    // 如果已经冲过 boundary，直接从当前位置弹回 boundary
    if (currentOverscroll > 0) {
      return ScrollSpringSimulation(spring, position.pixels, boundary, velocity,
          tolerance: tolerance);
    }

    // end=overscrollTarget，spring 一次性完成：减速→越界→弹回
    // 不依赖 Flutter 重触发，避免 clamp velocity 问题
    return ScrollSpringSimulation(spring, position.pixels, overscrollTarget, velocity,
        tolerance: tolerance);
  }

  static const double _defaultDrag = 0.135;
}


