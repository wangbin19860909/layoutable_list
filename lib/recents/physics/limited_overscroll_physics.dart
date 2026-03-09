import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/physics.dart';

/// 限制 overscroll 范围的 ScrollPhysics
/// 
/// 通过重写 createBallisticSimulation 来限制惯性滚动和回弹动画的 overscroll
class LimitedOverscrollPhysics extends BouncingScrollPhysics {
  /// overscroll 的最大距离（像素）
  final double maxOverscrollExtent;

  const LimitedOverscrollPhysics({
    super.parent,
    this.maxOverscrollExtent = 100.0,
  });

  @override
  LimitedOverscrollPhysics applyTo(ScrollPhysics? ancestor) {
    // 跳过 ancestor 中的 BouncingScrollPhysics，避免双重 bouncing
    ScrollPhysics? newAncestor = ancestor;
    if (ancestor is BouncingScrollPhysics && ancestor is! LimitedOverscrollPhysics) {
      newAncestor = ancestor.parent;
    }
    return LimitedOverscrollPhysics(
      parent: buildParent(newAncestor),
      maxOverscrollExtent: maxOverscrollExtent,
    );
  }

  @override
  SpringDescription get spring {
    // 使用更高的阻尼比来减少"冲出去"的距离
    // 默认是 ratio: 1.3，我们增加到 1.8 让它衰减更快
    return SpringDescription.withDampingRatio(
      mass: 0.3,
      stiffness: 75.0,
      ratio: 1.8, // 增加阻尼比
    );
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final Tolerance tolerance = toleranceFor(position);
    
    // 如果速度太小且在范围内，不需要 simulation
    if (velocity.abs() < tolerance.velocity && !position.outOfRange) {
      return null;
    }

    // 检查当前是否已经超过限制
    final double overscrollPastStart = math.max(position.minScrollExtent - position.pixels, 0.0);
    final double overscrollPastEnd = math.max(position.pixels - position.maxScrollExtent, 0.0);
    final double currentOverscroll = math.max(overscrollPastStart, overscrollPastEnd);

    // 如果当前已经超过限制，直接创建回弹到正常边界的 spring simulation
    if (currentOverscroll > maxOverscrollExtent) {
      final double targetPosition = overscrollPastStart > 0 
          ? position.minScrollExtent
          : position.maxScrollExtent;
      
      // 减小速度，避免回弹时冲出去太多
      double adjustedVelocity = velocity;
      if (velocity.abs() > 1000) {
        final double velocityScale = math.max(0.2, 1.0 - (velocity.abs() - 1000) / 15000);
        adjustedVelocity = velocity * velocityScale;
      }
      
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        targetPosition,
        adjustedVelocity,
        tolerance: tolerance,
      );
    }

    // 对所有情况都进行预测，确保不会冲出去太多
    double adjustedVelocity = velocity;
    
    // 创建一个临时 simulation 来预测最终位置
    final testSimulation = BouncingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      leadingExtent: position.minScrollExtent,
      trailingExtent: position.maxScrollExtent,
      spring: spring,
      tolerance: tolerance,
    );
    
    // 检查 0.5 秒后的位置
    final predictedX = testSimulation.x(0.5);
    final predictedOverscroll = predictedX < position.minScrollExtent
        ? position.minScrollExtent - predictedX
        : math.max(0, predictedX - position.maxScrollExtent);
    
    if (predictedOverscroll > maxOverscrollExtent) {
      // 会超出限制，按比例减小速度
      final scale = math.min(1.0, (maxOverscrollExtent / predictedOverscroll) * 0.7); // 0.7 系数更保守
      adjustedVelocity = velocity * scale;
    }
    
    return BouncingScrollSimulation(
      position: position.pixels,
      velocity: adjustedVelocity,
      leadingExtent: position.minScrollExtent,
      trailingExtent: position.maxScrollExtent,
      spring: spring,
      tolerance: tolerance,
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // 如果在正常范围内，不施加摩擦
    if (!position.outOfRange) {
      return offset;
    }

    // 计算当前的 overscroll 距离
    final double overscrollPastStart = math.max(position.minScrollExtent - position.pixels, 0.0);
    final double overscrollPastEnd = math.max(position.pixels - position.maxScrollExtent, 0.0);
    final double overscrollPast = math.max(overscrollPastStart, overscrollPastEnd);

    // 判断是否在继续往外拖（tensioning）
    final bool tensioning = 
        (overscrollPastStart > 0.0 && offset > 0.0) || 
        (overscrollPastEnd > 0.0 && offset < 0.0);

    // 如果已经超过最大值且继续往外拖，完全阻止
    if (overscrollPast >= maxOverscrollExtent && tensioning) {
      return 0.0; // 完全阻止
    }

    // 如果接近最大值（70%-100%），施加强阻力
    if (overscrollPast >= maxOverscrollExtent * 0.7 && tensioning) {
      return offset * 0.1; // 施加 90% 阻力
    }

    // 否则使用父类的摩擦力计算（BouncingScrollPhysics 的默认行为）
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // 始终返回 0，不阻止任何移动
    // 限制由 simulation 本身处理
    return 0.0;
  }
}
