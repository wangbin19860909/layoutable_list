import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'animation_widget.dart';
import 'animated_size_box.dart';
import '../algorithms/layout_algorithm.dart';

/// Item 动画参数
///
/// 继承 AnimationParams，额外包含 size 字段用于尺寸动画。
///
/// 使用场景：
/// 1. 补位动画：offset → toOffset (通常 toOffset = Offset.zero)
/// 2. 新增 item：offset = toOffset = Offset.zero（不执行动画）
/// 3. 尺寸动画：size 不为 zero 时执行尺寸动画
class ItemAnimatorParams extends AnimationParams {
  /// 目标尺寸
  ///
  /// - Size.zero 表示使用 LayoutParams 的尺寸，不执行尺寸动画
  /// - 非 zero 表示执行尺寸动画到该尺寸
  final Size size;

  ItemAnimatorParams({
    super.springConfig,
    super.curveConfig,
    required super.offset,
    super.toOffset = Offset.zero,
    required super.scale,
    super.toScale = 1.0,
    required super.alpha,
    super.toAlpha = 1.0,
    this.size = Size.zero,
  });

  /// 复制并替换任意参数
  @override
  ItemAnimatorParams copy({
    SpringConfig? springConfig,
    CurveConfig? curveConfig,
    Offset? offset,
    Offset? toOffset,
    double? scale,
    double? toScale,
    double? alpha,
    double? toAlpha,
    Size? size,
  }) {
    return ItemAnimatorParams(
      springConfig: springConfig ?? this.springConfig,
      curveConfig: curveConfig ?? this.curveConfig,
      offset: offset ?? this.offset,
      toOffset: toOffset ?? this.toOffset,
      scale: scale ?? this.scale,
      toScale: toScale ?? this.toScale,
      alpha: alpha ?? this.alpha,
      toAlpha: toAlpha ?? this.toAlpha,
      size: size ?? this.size,
    );
  }
}

/// Item 动画组件
///
/// 负责执行 item 的补位动画（位置平移、缩放、透明度和尺寸变化）。
/// 使用 AnimationWidget 实现 offset/scale/alpha 动画，
/// 使用 AnimatedSizeBox 实现尺寸动画。
class ItemAnimator extends StatefulWidget {
  final String itemId;
  final ValueNotifier<ItemAnimatorParams> paramsNotifier;
  final ValueListenable<LayoutParams> layoutParamsListenable;
  final void Function(String itemId) onDispose;
  final Widget child;
  final Duration duration;
  final Curve curve;

  const ItemAnimator({
    super.key,
    required this.itemId,
    required this.paramsNotifier,
    required this.layoutParamsListenable,
    required this.onDispose,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeInOut,
  });

  @override
  State<ItemAnimator> createState() => _ItemAnimatorState();
}

class _ItemAnimatorState extends State<ItemAnimator> {
  late SizeAnimationParamsMerger _sizeParamsMerger;

  @override
  void initState() {
    super.initState();
    _sizeParamsMerger = SizeAnimationParamsMerger(
      paramsNotifier: widget.paramsNotifier,
      layoutParamsListenable: widget.layoutParamsListenable,
    );
  }

  @override
  void didUpdateWidget(ItemAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sizeParamsMerger.layoutParamsListenable = widget.layoutParamsListenable;
  }

  @override
  void dispose() {
    _sizeParamsMerger.dispose();
    widget.onDispose(widget.itemId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimationWidget(
      animParams: widget.paramsNotifier,
      child: AnimatedSizeBox(
        key: ValueKey('size_${widget.itemId}'),
        sizeParamsNotifier: _sizeParamsMerger,
        duration: widget.duration,
        curve: widget.curve,
        onEnd: () {
          _sizeParamsMerger.markAnimationEnd();
        },
        child: widget.child,
      ),
    );
  }
}
