import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' show sqrt;

import 'package:flutter/physics.dart';

/// 弹簧物理配置
class SpringConfig {
  final double stiffness;
  final double damping;
  final double velocity;

  const SpringConfig({
    this.stiffness = 100.0,
    this.damping = 10.0,
    this.velocity = 0.0,
  });

  double get criticalDamping => 2 * sqrt(stiffness);

  SpringConfig copyWith({double? velocity}) {
    return SpringConfig(
      stiffness: stiffness,
      damping: damping,
      velocity: velocity ?? this.velocity,
    );
  }
}

/// 曲线动画配置
class CurveConfig {
  final Curve curve;
  final int durationMs;

  const CurveConfig({
    this.curve = Curves.linear,
    this.durationMs = 500,
  });
}

/// 统一动画参数
class AnimationParams {
  final SpringConfig? springConfig;
  final CurveConfig curveConfig;

  Offset offset;
  final Offset toOffset;

  double scale;
  final double toScale;

  double alpha;
  final double toAlpha;

  AnimationParams({
    this.springConfig,
    CurveConfig? curveConfig,
    required this.offset,
    required this.toOffset,
    required this.scale,
    required this.toScale,
    required this.alpha,
    required this.toAlpha,
  })  : curveConfig = springConfig != null
            ? const CurveConfig(curve: Curves.linear)
            : (curveConfig ?? const CurveConfig());

  /// 复制并替换任意参数，current 值默认从当前值中取
  AnimationParams copy({
    SpringConfig? springConfig,
    CurveConfig? curveConfig,
    Offset? offset,
    Offset? toOffset,
    double? scale,
    double? toScale,
    double? alpha,
    double? toAlpha,
  }) {
    return AnimationParams(
      springConfig: springConfig ?? this.springConfig,
      curveConfig: curveConfig ?? this.curveConfig,
      offset: offset ?? this.offset,
      toOffset: toOffset ?? this.toOffset,
      scale: scale ?? this.scale,
      toScale: toScale ?? this.toScale,
      alpha: alpha ?? this.alpha,
      toAlpha: toAlpha ?? this.toAlpha,
    );
  }
}

class AnimationWidget extends StatefulWidget {
  final Widget child;
  final ValueListenable<AnimationParams> animParams;

  const AnimationWidget({
    super.key,
    required this.child,
    required this.animParams,
  });

  @override
  State<AnimationWidget> createState() => _AnimationWidgetState();
}

class _AnimationWidgetState extends State<AnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _alphaAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.animParams.value.curveConfig.durationMs),
    );
    widget.animParams.addListener(_onParamsChanged);
    _startAnimations();
  }

  @override
  void didUpdateWidget(AnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animParams != widget.animParams) {
      oldWidget.animParams.removeListener(_onParamsChanged);
      widget.animParams.addListener(_onParamsChanged);
      _onParamsChanged();
    }
  }

  @override
  void dispose() {
    widget.animParams.removeListener(_onParamsChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onParamsChanged() {
    _controller.reset();
    _controller.duration = Duration(milliseconds: widget.animParams.value.curveConfig.durationMs);
    _startAnimations();
  }

  void _startAnimations() {
    final params = widget.animParams.value;
    final isSpring = params.springConfig != null;

    final Animation<double> parent = isSpring
        ? _controller
        : _controller.drive(CurveTween(curve: params.curveConfig.curve));

    _offsetAnimation = Tween<Offset>(
      begin: params.offset,
      end: params.toOffset,
    ).animate(parent);

    _scaleAnimation = Tween<double>(
      begin: params.scale,
      end: params.toScale,
    ).animate(parent);

    _alphaAnimation = Tween<double>(
      begin: params.alpha,
      end: params.toAlpha,
    ).animate(parent);

    // 所有属性都已在目标值，跳过动画
    if (params.offset == params.toOffset &&
        params.scale == params.toScale &&
        params.alpha == params.toAlpha) {
      _controller.value = 1.0;
      return;
    }

    if (isSpring) {
      final springConfig = params.springConfig!;
      _controller.animateWith(
        SpringSimulation(
          SpringDescription(
            stiffness: springConfig.stiffness,
            damping: springConfig.damping,
            mass: 1.0,
          ),
          0.0,
          1.0,
          springConfig.velocity,
        ),
      );
    } else {
      _controller.forward(from: _controller.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final params = widget.animParams.value;
        params.offset = _offsetAnimation.value;
        params.scale = _scaleAnimation.value;
        params.alpha = _alphaAnimation.value.clamp(0.0, 1.0);

        return Transform.translate(
          offset: params.offset,
          child: Transform.scale(
            scale: params.scale,
            child: Opacity(
              opacity: params.alpha,
              child: widget.child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
