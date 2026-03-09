import 'package:flutter/material.dart';

/// Item 动画参数
/// 
/// 定义一个 item 从当前状态动画到目标状态所需的所有参数。
/// 
/// 使用场景：
/// 1. 补位动画：offset → toOffset (通常 toOffset = Offset.zero)
/// 2. 拖拽跟随：offset = toOffset（立即显示，无动画）
/// 3. 添加动画：offset 为 null，表示新创建的 item
class ItemAnimatorParams {
  /// 全局动画 ID 计数器
  static int _globalAnimationIdCounter = 0;
  
  /// 当前偏移量（相对于目标位置）
  /// 
  /// - 如果为 null，表示这是一个新添加的 item，应该执行添加动画（淡入 + 缩放）
  /// - 如果不为 null，是一个可变的 ValueNotifier，表示 item 动画的起始位置
  ///   - ItemAnimator 在动画过程中会更新这个值
  ///   - ListAdapter 可以读取这个值来计算新的动画参数
  /// 
  /// 例如：
  /// - offset.value = Offset(0, -100)：item 从上方 100 像素开始动画
  /// - offset.value = toOffset：立即显示在目标位置（无动画）
  final ValueNotifier<Offset>? offset;

  /// 目标偏移量（相对于正确位置）
  /// 
  /// - 补位动画场景：通常是 Offset.zero（item 的正确位置）
  /// - 拖拽场景：是拖拽的目标位置（如 Offset(0, -100) 表示向上偏移 100）
  /// 
  /// 例如：
  /// - toOffset = Offset.zero：动画到正确位置
  /// - toOffset = Offset(0, -100)：动画到向上偏移 100 的位置
  /// 
  /// 默认值为 Offset.zero
  final Offset toOffset;

  /// 当前尺寸（绝对值）
  /// 
  /// - 如果为 null，表示使用 item 的自然尺寸（目标状态）
  /// - 如果不为 null，表示 item 应该从这个尺寸动画到自然尺寸
  /// 
  /// 例如：
  /// - size = Size(200, 100)：item 从 200x100 动画到自然尺寸
  /// - size = null：item 使用自然尺寸，无需尺寸动画
  final Size? size;

  /// 动画 ID，用于强制重新触发动画
  /// 每次创建新的 params 时自动递增
  final int animationId;
  
  /// 是否启用动画
  /// 
  /// - true: 执行动画过渡（使用 duration）
  /// - false: 直接跳转到目标值（duration = 0）
  final bool animated;

  ItemAnimatorParams({
    this.offset,
    this.toOffset = Offset.zero,
    this.size,
    this.animated = true,
  }) : animationId = ++_globalAnimationIdCounter;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemAnimatorParams &&
          runtimeType == other.runtimeType &&
          offset == other.offset &&
          toOffset == other.toOffset &&
          size == other.size &&
          animationId == other.animationId &&
          animated == other.animated;

  @override
  int get hashCode => 
      offset.hashCode ^ 
      toOffset.hashCode ^ 
      size.hashCode ^ 
      animationId.hashCode ^ 
      animated.hashCode;

  @override
  String toString() {
    return 'ItemAnimatorParams('
        'offset: ${offset?.value}, '
        'toOffset: $toOffset, '
        'size: $size, '
        'animationId: $animationId, '
        'animated: $animated'
        ')';
  }

  
  /// 释放资源
  void dispose() {
    offset?.dispose();
  }
}

