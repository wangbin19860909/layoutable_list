import 'dart:ui';

import 'package:flutter/foundation.dart';
import '../layout_algorithm.dart';
import 'item_animator_params.dart';

/// 尺寸动画参数
class SizeAnimationParams {
  /// 目标尺寸
  final Size size;
  
  /// 是否执行动画
  final bool animate;

  const SizeAnimationParams({
    required this.size,
    required this.animate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SizeAnimationParams &&
          runtimeType == other.runtimeType &&
          size == other.size &&
          animate == other.animate;

  @override
  int get hashCode => size.hashCode ^ animate.hashCode;

  @override
  String toString() => 'SizeAnimationParams(size: $size, animate: $animate)';
}

/// 尺寸动画参数合并器
/// 
/// 接收两个输入源：
/// 1. ItemAnimatorParams (paramsNotifier) - 补位动画参数
/// 2. LayoutParams (layoutParamsListenable) - 布局参数
/// 
/// 输出一个 SizeAnimationParams，包含目标尺寸和是否执行动画
/// 
/// 逻辑：
/// - 当 animationId 变化时，触发尺寸动画
///   - 如果 ItemAnimatorParams.size 不为 null，使用它
///   - 否则使用 LayoutParams.rect.size
///   - animate = true
/// - 当 LayoutParams 变化时（非动画期间）
///   - 使用 LayoutParams.rect.size
///   - animate = false
class SizeAnimationParamsMerger extends ValueNotifier<SizeAnimationParams> {
  final ValueListenable<ItemAnimatorParams> paramsNotifier;
  ValueListenable<LayoutParams> _layoutParamsListenable;
  
  int? _currentAnimationId;
  bool _isAnimating = false;

  SizeAnimationParamsMerger({
    required this.paramsNotifier,
    required ValueListenable<LayoutParams> layoutParamsListenable,
  }) : _layoutParamsListenable = layoutParamsListenable,
       super(SizeAnimationParams(
          size: layoutParamsListenable.value.rect.size,
          animate: false,
        )) {
    // 监听两个输入源
    paramsNotifier.addListener(_onParamsChanged);
    _layoutParamsListenable.addListener(_onLayoutParamsChanged);
    
    // 初始化 animationId
    _currentAnimationId = paramsNotifier.value.animationId;
  }
  
  /// 获取当前的 layoutParamsListenable
  ValueListenable<LayoutParams> get layoutParamsListenable => _layoutParamsListenable;
  
  /// 更新 layoutParamsListenable
  /// 
  /// 当 item 的位置变化时，需要更新监听的 layoutParamsListenable
  set layoutParamsListenable(ValueListenable<LayoutParams> newListenable) {
    if (_layoutParamsListenable == newListenable) return;
    
    // 移除旧的监听
    _layoutParamsListenable.removeListener(_onLayoutParamsChanged);
    
    // 更新为新的
    _layoutParamsListenable = newListenable;
    
    // 添加新的监听
    _layoutParamsListenable.addListener(_onLayoutParamsChanged);
    
    // 立即触发一次，获取新的值
    _onLayoutParamsChanged();
  }
  
  void _onParamsChanged() {
    final params = paramsNotifier.value;
    
    // 检测 animationId 是否变化
    if (_currentAnimationId != params.animationId) {
      _currentAnimationId = params.animationId;
      
      // 如果 params.size 为 zero，说明不需要尺寸动画
      if (params.size == Size.zero) {
        _isAnimating = false;
        
        final layoutSize = _layoutParamsListenable.value.rect.size;
        
        // 使用 LayoutParams 的尺寸，不执行动画
        value = SizeAnimationParams(
          size: layoutSize,
          animate: false,
        );
      } else {
        // 根据 params.animated 决定是否执行动画
        _isAnimating = params.animated;
        
        // 使用 params.size
        value = SizeAnimationParams(
          size: params.size,
          animate: params.animated,
        );
      }
    }
  }
  
  void _onLayoutParamsChanged() {
    final newSize = _layoutParamsListenable.value.rect.size;
    
    // 只在非动画期间响应 LayoutParams 变化
    if (!_isAnimating) {
      // 更新尺寸，不执行动画
      value = SizeAnimationParams(
        size: newSize,
        animate: false,
      );
    }
  }
  
  /// 标记动画结束
  /// 
  /// 应该在尺寸动画结束后调用，以便恢复响应 LayoutParams 的变化
  void markAnimationEnd() {
    _isAnimating = false;
  }
  
  @override
  void dispose() {
    paramsNotifier.removeListener(_onParamsChanged);
    layoutParamsListenable.removeListener(_onLayoutParamsChanged);
    super.dispose();
  }
}
