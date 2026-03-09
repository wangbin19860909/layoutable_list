import 'package:flutter/material.dart';
import 'item_animator_params.dart';

/// Item 动画组件
///
/// 只负责执行 item 的补位动画（位置平移）。
/// 添加动画和删除动画需要由外部实现。
class ItemAnimator extends StatefulWidget {
  final int itemId;
  final ValueNotifier<ItemAnimatorParams> paramsNotifier;
  final void Function(int itemId) onDispose;
  final Widget child;
  final Duration duration;
  final Curve curve;

  const ItemAnimator({
    super.key,
    required this.itemId,
    required this.paramsNotifier,
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
        // 直接渲染，不执行动画（添加动画由外部实现）
        if (params.offset == null) {
          return child!;
        }

        // 执行位置动画
        return _PositionAnimation(
          offsetNotifier: params.offset!,
          toOffset: params.toOffset,
          animationId: params.animationId,
          animated: params.animated,
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
  final ValueNotifier<Offset> offsetNotifier;
  final Offset toOffset;
  final int animationId;
  final bool animated;
  final Duration duration;
  final Curve curve;
  final Widget child;

  const _PositionAnimation({
    required this.offsetNotifier,
    required this.toOffset,
    required this.animationId,
    required this.animated,
    required this.duration,
    required this.curve,
    required this.child,
  });

  @override
  State<_PositionAnimation> createState() => _PositionAnimationState();
}

class _PositionAnimationState extends State<_PositionAnimation> {
  late final ValueNotifier<Offset> _offsetNotifier;

  @override
  void initState() {
    super.initState();
    _offsetNotifier = ValueNotifier(widget.offsetNotifier.value);
  }

  @override
  void dispose() {
    _offsetNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _offsetNotifier.value = widget.offsetNotifier.value;
    
    return ValueListenableBuilder<Offset>(
      valueListenable: _offsetNotifier,
      builder: (context, fromOffset, child) {
        // 使用 TweenAnimationBuilder 执行动画
        // - animated=true: 从 fromOffset 动画到 toOffset
        // - animated=false: duration=0，立即显示 toOffset
        return TweenAnimationBuilder<Offset>(
          key: ValueKey(widget.animationId),
          tween: Tween<Offset>(
            begin: fromOffset,
            end: widget.toOffset,
          ),
          duration: widget.animated ? widget.duration : Duration.zero,
          curve: widget.curve,
          builder: (context, currentOffset, child) {
            widget.offsetNotifier.value = currentOffset;
            return Transform.translate(offset: currentOffset, child: child);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
