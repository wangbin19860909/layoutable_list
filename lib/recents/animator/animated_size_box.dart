import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../algorithms/layout_algorithm.dart';
import '../../utils/logger.dart';
import 'animation_widget.dart';
import 'item_animator.dart';

/// 尺寸动画参数
class SizeAnimationParams {
  /// 目标尺寸
  final Size size;

  /// 是否执行动画
  final bool animate;

  /// 弹簧动画配置（优先于 curveConfig）
  final SpringConfig? springConfig;

  /// 曲线动画配置
  final CurveConfig curveConfig;

  const SizeAnimationParams({
    required this.size,
    required this.animate,
    this.springConfig,
    this.curveConfig = const CurveConfig(curve: Curves.easeInOut, durationMs: 400),
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SizeAnimationParams &&
          runtimeType == other.runtimeType &&
          size == other.size &&
          animate == other.animate &&
          springConfig == other.springConfig &&
          curveConfig == other.curveConfig;

  @override
  int get hashCode =>
      size.hashCode ^ animate.hashCode ^ springConfig.hashCode ^ curveConfig.hashCode;

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
/// - 当 ItemAnimatorParams.size 变化且不为 zero 时，执行尺寸动画
/// - 当 LayoutParams 变化时（非动画期间），直接更新尺寸，不执行动画
class SizeAnimationParamsMerger extends ValueNotifier<SizeAnimationParams> {
  final ValueListenable<ItemAnimatorParams> paramsNotifier;
  ValueListenable<LayoutParams> _layoutParamsListenable;
  
  Size _lastParamsSize;
  bool _isAnimating = false;

  SizeAnimationParamsMerger({
    required this.paramsNotifier,
    required ValueListenable<LayoutParams> layoutParamsListenable,
  }) : _layoutParamsListenable = layoutParamsListenable,
       _lastParamsSize = paramsNotifier.value.size,
       super(SizeAnimationParams(
          size: layoutParamsListenable.value.rect.size,
          animate: false,
        )) {
    paramsNotifier.addListener(_onParamsChanged);
    _layoutParamsListenable.addListener(_onLayoutParamsChanged);
  }
  
  ValueListenable<LayoutParams> get layoutParamsListenable => _layoutParamsListenable;
  
  set layoutParamsListenable(ValueListenable<LayoutParams> newListenable) {
    if (_layoutParamsListenable == newListenable) return;
    _layoutParamsListenable.removeListener(_onLayoutParamsChanged);
    _layoutParamsListenable = newListenable;
    _layoutParamsListenable.addListener(_onLayoutParamsChanged);
    _onLayoutParamsChanged();
  }
  
  void _onParamsChanged() {
    final params = paramsNotifier.value;
    final newSize = params.size;
    
    if (newSize == _lastParamsSize) return;
    _lastParamsSize = newSize;
    
    if (newSize == Size.zero) {
      _isAnimating = false;
      final layoutSize = _layoutParamsListenable.value.rect.size;
      value = SizeAnimationParams(size: layoutSize, animate: false);
    } else {
      _isAnimating = true;
      final p = paramsNotifier.value;
      value = SizeAnimationParams(
        size: newSize,
        animate: true,
        springConfig: p.springConfig,
        curveConfig: p.curveConfig,
      );
    }
  }
  
  void _onLayoutParamsChanged() {
    final newSize = _layoutParamsListenable.value.rect.size;
    
    if (!_isAnimating && newSize != value.size) {
      value = SizeAnimationParams(size: newSize, animate: false);
    }
  }
  
  void markAnimationEnd() {
    _isAnimating = false;
  }
  
  @override
  void dispose() {
    paramsNotifier.removeListener(_onParamsChanged);
    _layoutParamsListenable.removeListener(_onLayoutParamsChanged);
    super.dispose();
  }
}

/// 尺寸动画组件
///
/// 监听 SizeAnimationParams 的变化，自动执行尺寸动画
class AnimatedSizeBox extends StatefulWidget {
  /// 尺寸动画参数的 ValueNotifier
  final ValueNotifier<SizeAnimationParams> sizeParamsNotifier;

  /// 子组件
  final Widget child;

  /// 对齐方式
  final Alignment alignment;

  /// 动画结束回调（只有 animate = true 时才调用）
  final VoidCallback? onEnd;

  const AnimatedSizeBox({
    super.key,
    required this.sizeParamsNotifier,
    required this.child,
    this.alignment = Alignment.center,
    this.onEnd,
  });

  @override
  State<AnimatedSizeBox> createState() => _AnimatedSizeBoxState();
}

class _AnimatedSizeBoxState extends State<AnimatedSizeBox>
    with SingleTickerProviderStateMixin {
  static final _log = Logger('AnimatedSizeBox');
  late AnimationController _controller;
  late Animation<Size> _sizeAnimation;
  late Size _currentSize;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _currentSize = widget.sizeParamsNotifier.value.size;
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener(_onStatus);
    _sizeAnimation = AlwaysStoppedAnimation(_currentSize);
    widget.sizeParamsNotifier.addListener(_onParamsChanged);
  }

  void _onParamsChanged() {
    final params = widget.sizeParamsNotifier.value;
    final targetSize = params.size;

    // 目标尺寸没变，跳过
    if (targetSize == _currentSize && !_isAnimating) return;

    _sizeAnimation = Tween<Size>(
      begin: _currentSize,
      end: targetSize,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: params.springConfig != null ? Curves.linear : params.curveConfig.curve,
    ));

    if (params.animate) {
      _isAnimating = true;
      _log.d('start size ${_currentSize.width.toStringAsFixed(1)}×${_currentSize.height.toStringAsFixed(1)} → ${targetSize.width.toStringAsFixed(1)}×${targetSize.height.toStringAsFixed(1)}');
      if (params.springConfig != null) {
        final sc = params.springConfig!;
        _controller.animateWith(SpringSimulation(
          SpringDescription(stiffness: sc.stiffness, damping: sc.damping, mass: 1.0),
          0.0, 1.0, sc.velocity,
        ));
      } else {
        _controller.duration = Duration(milliseconds: params.curveConfig.durationMs);
        _controller.forward(from: 0.0);
      }
    } else {
      // 不做动画，直接到位
      _isAnimating = false;
      _currentSize = targetSize;
      _controller.value = 1.0;
      _log.dDebounced('size update (no anim) ${targetSize.width.toStringAsFixed(1)}×${targetSize.height.toStringAsFixed(1)}');
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _isAnimating) {
      _isAnimating = false;
      _currentSize = widget.sizeParamsNotifier.value.size;
      _log.d('end size=${_currentSize.width.toStringAsFixed(1)}×${_currentSize.height.toStringAsFixed(1)}');
      widget.onEnd?.call();
    }
  }

  @override
  void dispose() {
    widget.sizeParamsNotifier.removeListener(_onParamsChanged);
    _controller.dispose();
    if (_isAnimating) {
      widget.onEnd?.call();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final size = _sizeAnimation.value;
        _currentSize = size;
        return OverflowBox(
          alignment: widget.alignment,
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
