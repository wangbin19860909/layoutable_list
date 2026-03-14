import 'package:flutter/animation.dart';
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

  final ValueNotifier<Offset> offset;
  final Offset toOffset;

  final ValueNotifier<double> scale;
  final double toScale;

  final ValueNotifier<double> alpha;
  final double toAlpha;

  AnimationParams({
    this.springConfig,
    CurveConfig? curveConfig,
    required Offset offsetInitial,
    required this.toOffset,
    required double scaleInitial,
    required this.toScale,
    required double alphaInitial,
    required this.toAlpha,
  })  : curveConfig = springConfig != null
            ? const CurveConfig(curve: Curves.linear)
            : (curveConfig ?? const CurveConfig()),
        offset = ValueNotifier(offsetInitial),
        scale = ValueNotifier(scaleInitial),
        alpha = ValueNotifier(alphaInitial);

  void dispose() {
    offset.dispose();
    scale.dispose();
    alpha.dispose();
  }

  /// 复制并替换任意参数，current 值默认从当前 ValueNotifier 中取
  AnimationParams copy({
    SpringConfig? springConfig,
    CurveConfig? curveConfig,
    Offset? offsetInitial,
    Offset? toOffset,
    double? scaleInitial,
    double? toScale,
    double? alphaInitial,
    double? toAlpha,
  }) {
    return AnimationParams(
      springConfig: springConfig ?? this.springConfig,
      curveConfig: curveConfig ?? this.curveConfig,
      offsetInitial: offsetInitial ?? offset.value,
      toOffset: toOffset ?? this.toOffset,
      scaleInitial: scaleInitial ?? scale.value,
      toScale: toScale ?? this.toScale,
      alphaInitial: alphaInitial ?? alpha.value,
      toAlpha: toAlpha ?? this.toAlpha,
    );
  }
}

class AnimationWidget extends StatefulWidget {
  final Widget child;
  final AnimationParams animParams;

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
      duration: Duration(milliseconds: widget.animParams.curveConfig.durationMs),
    );

    _startAnimations();
  }

  @override
  void didUpdateWidget(AnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animParams != widget.animParams) {
      _controller.reset();
      _controller.duration = Duration(milliseconds: widget.animParams.curveConfig.durationMs);
      _startAnimations();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startAnimations() {
    final params = widget.animParams;
    final isSpring = params.springConfig != null;

    final Animation<double> parent = isSpring
        ? _controller
        : _controller.drive(CurveTween(curve: params.curveConfig.curve));

    _offsetAnimation = Tween<Offset>(
      begin: params.offset.value,
      end: params.toOffset,
    ).animate(parent);

    _scaleAnimation = Tween<double>(
      begin: params.scale.value,
      end: params.toScale,
    ).animate(parent);

    _alphaAnimation = Tween<double>(
      begin: params.alpha.value,
      end: params.toAlpha,
    ).animate(parent);

    // 所有属性都已在目标值，跳过动画
    if (params.offset.value == params.toOffset &&
        params.scale.value == params.toScale &&
        params.alpha.value == params.toAlpha) {
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
        final params = widget.animParams;
        params.offset.value = _offsetAnimation.value;
        params.scale.value = _scaleAnimation.value;
        params.alpha.value = _alphaAnimation.value.clamp(0.0, 1.0);

        return Transform.translate(
          offset: params.offset.value,
          child: Transform.scale(
            scale: params.scale.value,
            child: Opacity(
              opacity: params.alpha.value,
              child: widget.child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }

  
}