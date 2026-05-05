import 'package:flutter/material.dart';
import 'package:flutter_multi_window/service_holder.dart';
import '../layoutable_list_widget.dart';

/// 自定义滚动物理效果，支持吸附到指定位置
///
/// 滚动停止后，会自动吸附到最近的 itemExtent 倍数位置
class StackSnapScrollPhysics extends BouncingScrollPhysics {
  final ServiceHolder<LayoutManager> layoutManager;

  const StackSnapScrollPhysics({required this.layoutManager, super.parent});

  @override
  StackSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return StackSnapScrollPhysics(
      layoutManager: layoutManager,
      parent: buildParent(ancestor),
    );
  }

  /// 计算最近的吸附位置，同时返回 flingDistance
  ({double flingDistance, double targetOffset}) _getTargetOffset(
    ScrollMetrics position,
    Tolerance tolerance,
    double velocity,
  ) {
    final double itemExtent = layoutManager.target!.itemExtent;
    final double currentIndex = position.pixels / itemExtent;

    double flingDistance;
    double targetIndex;

    if (velocity.abs() < tolerance.velocity) {
      flingDistance = 0.0;
      targetIndex = currentIndex.roundToDouble();
    } else {
      const double friction = 8000.0;
      flingDistance = velocity.sign * (velocity * velocity) / (2 * friction);
      final double cardOffset = flingDistance / itemExtent;

      targetIndex = (currentIndex + cardOffset).clamp(0, layoutManager.target!.itemCount - 1);

      if (velocity > 0 && targetIndex < currentIndex + 1) {
        targetIndex = currentIndex.ceilToDouble();
      } else if (velocity < 0 && targetIndex > currentIndex - 1) {
        targetIndex = currentIndex.floorToDouble();
      } else {
        targetIndex = targetIndex.roundToDouble();
      }
    }

    return (flingDistance: flingDistance, targetOffset: targetIndex * itemExtent);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final Tolerance tolerance = toleranceFor(position);

    // 已经在边界外，走父类（bouncing overscroll 回弹）
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }

    final (:flingDistance, :targetOffset) = _getTargetOffset(position, tolerance, velocity);
    final double flingEnd = position.pixels + flingDistance;

    // fling 落点超出滚动范围，走父类（让 bouncing overscroll 处理）
    if (flingEnd <= position.minScrollExtent || flingEnd >= position.maxScrollExtent) {
      return super.createBallisticSimulation(position, velocity);
    }

    // 如果当前位置已经接近目标位置，停止滚动
    final double distance = (targetOffset - position.pixels).abs();
    if (distance < tolerance.distance) {
      return null;
    }

    // 创建弹簧模拟动画，吸附到目标位置
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      targetOffset,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}
