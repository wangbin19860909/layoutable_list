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

  /// 计算最近的吸附位置
  double _getTargetOffset(
    ScrollMetrics position,
    Tolerance tolerance,
    double velocity,
  ) {
    final double itemExtent = layoutManager.target!.itemExtent;

    // 计算当前位置对应的 item index（浮点数）
    final double currentIndex = position.pixels / itemExtent;

    // 根据速度计算应该滑动多少个卡片
    double targetIndex;

    if (velocity.abs() < tolerance.velocity) {
      // 速度很小，吸附到最近的 item
      targetIndex = currentIndex.roundToDouble();
    } else {
      // 根据速度计算惯性滑动的卡片数
      // 使用平方关系：distance = v² / (2 * friction)
      const double friction = 8000.0; // 摩擦系数，值越大滑动距离越短
      final double flingDistance =
          velocity.sign * (velocity * velocity) / (2 * friction);
      final double cardOffset = flingDistance / itemExtent;

      // 计算目标 index
      targetIndex = (currentIndex + cardOffset).clamp(0, layoutManager.target!.itemCount - 1);

      // 至少移动到下一个/上一个
      if (velocity > 0 && targetIndex < currentIndex + 1) {
        targetIndex = currentIndex.ceilToDouble();
      } else if (velocity < 0 && targetIndex > currentIndex - 1) {
        targetIndex = currentIndex.floorToDouble();
      } else {
        targetIndex = targetIndex.roundToDouble();
      }
    }

    return targetIndex * itemExtent;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // 如果已经在边界，使用默认行为
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final Tolerance tolerance = toleranceFor(position);
    final double targetOffset = _getTargetOffset(position, tolerance, velocity);

    // 如果当前位置已经接近目标位置，停止滚动
    final double distance = (targetOffset - position.pixels).abs();
    if (distance < tolerance.distance) {
      return null;
    }

    // 创建弹簧模拟动画
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
