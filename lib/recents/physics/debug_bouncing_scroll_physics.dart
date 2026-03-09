import 'package:flutter/widgets.dart';

/// 用于调试的 ScrollPhysics，打印日志但不修改行为
class DebugBouncingScrollPhysics extends BouncingScrollPhysics {
  const DebugBouncingScrollPhysics({super.parent});

  @override
  DebugBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    print('[DebugBouncingScrollPhysics.applyTo]');
    print('  this: $this');
    print('  this.parent: $parent');
    print('  ancestor: $ancestor');
    
    // 跳过 ancestor 中的 BouncingScrollPhysics，避免双重 bouncing
    ScrollPhysics? newAncestor = ancestor;
    if (ancestor is BouncingScrollPhysics && ancestor is! DebugBouncingScrollPhysics) {
      print('  检测到 BouncingScrollPhysics，跳过它');
      newAncestor = ancestor.parent;
      print('  newAncestor: $newAncestor');
    }
    
    final built = buildParent(newAncestor);
    print('  buildParent(newAncestor): $built');
    final result = DebugBouncingScrollPhysics(parent: built);
    print('  result.parent: ${result.parent}');
    return result;
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final result = super.applyBoundaryConditions(position, value);
    print('[DebugBouncing.applyBoundaryConditions]');
    print('  pixels=${position.pixels}');
    print('  value=$value');
    print('  delta=${value - position.pixels}');
    print('  minScrollExtent=${position.minScrollExtent}');
    print('  maxScrollExtent=${position.maxScrollExtent}');
    print('  outOfRange=${position.outOfRange}');
    print('  返回 result=$result');
    return result;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final simulation = super.createBallisticSimulation(position, velocity);
    print('[DebugBouncing.createBallisticSimulation]');
    print('  pixels=${position.pixels}');
    print('  velocity=$velocity');
    print('  outOfRange=${position.outOfRange}');
    print('  minScrollExtent=${position.minScrollExtent}');
    print('  maxScrollExtent=${position.maxScrollExtent}');
    if (simulation != null) {
      print('  创建了 simulation: ${simulation.runtimeType}');
    } else {
      print('  simulation = null');
    }
    return simulation;
  }
}
