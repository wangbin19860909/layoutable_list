import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'item_animator_params.dart';
import 'animated_size_box.dart';
import 'size_animation_params.dart';
import '../layout_algorithm.dart';

/// Item 动画组件
///
/// 负责执行 item 的补位动画（位置平移和尺寸变化）。
/// 添加动画和删除动画需要由外部实现。
class ItemAnimator extends StatefulWidget {
  final int itemId;
  final ValueNotifier<ItemAnimatorParams> paramsNotifier;
  final ValueListenable<LayoutParams> layoutParamsListenable;
  final void Function(int itemId) onDispose;
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
  @override
  void dispose() {
    // 通知 ListAdapter item 已卸载
    widget.onDispose(widget.itemId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ItemAnimatorParams>(
      valueListenable: widget.paramsNotifier,
      builder: (context, params, child) {
        // 如果 offset 为 null，说明是新添加的 item
        // 创建一个初始值为 Offset.zero 的 ValueNotifier
        final offsetNotifier = params.offset ?? ValueNotifier(Offset.zero);

        // 执行位置动画
        return _PositionAnimation(
          itemId: widget.itemId,
          offsetNotifier: offsetNotifier,
          toOffset: params.toOffset,
          size: params.size,
          animationId: params.animationId,
          animated: params.animated,
          paramsNotifier: widget.paramsNotifier,
          layoutParamsListenable: widget.layoutParamsListenable,
          duration: widget.duration,
          curve: widget.curve,
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

/// 位置动画（平移）
class _PositionAnimation extends StatefulWidget {
  final int itemId;
  final ValueNotifier<Offset> offsetNotifier;
  final Offset toOffset;
  final Size size;
  final int animationId;
  final bool animated;
  final ValueNotifier<ItemAnimatorParams> paramsNotifier;
  final ValueListenable<LayoutParams> layoutParamsListenable;
  final Duration duration;
  final Curve curve;
  final Widget child;

  const _PositionAnimation({
    required this.itemId,
    required this.offsetNotifier,
    required this.toOffset,
    required this.size,
    required this.animationId,
    required this.animated,
    required this.paramsNotifier,
    required this.layoutParamsListenable,
    required this.duration,
    required this.curve,
    required this.child,
  });

  @override
  State<_PositionAnimation> createState() => _PositionAnimationState();
}

class _PositionAnimationState extends State<_PositionAnimation> with SingleTickerProviderStateMixin {
  int _currentAnimationId = -1; // 初始为 -1，确保第一次会触发动画
  
  late AnimationController _controller;
  late Animation<Offset> _animation;
  late SizeAnimationParamsMerger _sizeParamsMerger;

  @override
  void initState() {
    super.initState();
    
    // 创建尺寸参数合并器
    _sizeParamsMerger = SizeAnimationParamsMerger(
      paramsNotifier: widget.paramsNotifier,
      layoutParamsListenable: widget.layoutParamsListenable,
    );
    
    // 创建动画控制器
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    // 创建初始动画
    _updateOffsetAnimation();
  }
  
  void _updateOffsetAnimation() {
    // 检测新动画开始
    if (_currentAnimationId == widget.animationId) {
      return; // 相同的 animationId，不需要重新启动动画
    }
    
    // 更新 animationId
    _currentAnimationId = widget.animationId;
    
    // 更新动画参数
    final begin = widget.offsetNotifier.value;
    final end = widget.toOffset;
    
    _animation = Tween<Offset>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));
    
    // 启动动画
    if (widget.animated) {
      _controller.duration = widget.duration;
      _controller.forward(from: 0.0);
    } else {
      _controller.duration = Duration.zero;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _sizeParamsMerger.dispose();
    _controller.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(_PositionAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 更新 layoutParamsListenable（内部会判断是否变化）
    _sizeParamsMerger.layoutParamsListenable = widget.layoutParamsListenable;
    
    // 尝试更新动画（内部会检测 animationId 是否变化）
    _updateOffsetAnimation();
  }

  @override
  Widget build(BuildContext context) {
    // 使用 AnimatedBuilder 执行位置动画
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final currentOffset = _animation.value;
        widget.offsetNotifier.value = currentOffset;
        return Transform.translate(
          offset: currentOffset,
          child: child,
        );
      },
      child: AnimatedSizeBox(
        key: ValueKey('size_${widget.itemId}'),
        sizeParamsNotifier: _sizeParamsMerger,
        duration: widget.duration,
        curve: widget.curve,
        onEnd: () {
          // Size 动画结束后，通知合并器
          _sizeParamsMerger.markAnimationEnd();
        },
        child: widget.child,
      ),
    );
  }
}
