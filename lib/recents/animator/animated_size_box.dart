import 'package:flutter/material.dart';
import 'size_animation_params.dart';

/// 尺寸动画组件
///
/// 监听 SizeAnimationParams 的变化，自动执行尺寸动画
class AnimatedSizeBox extends StatefulWidget {
  /// 尺寸动画参数的 ValueNotifier
  final ValueNotifier<SizeAnimationParams> sizeParamsNotifier;
  
  /// 子组件
  final Widget child;
  
  /// 动画时长
  final Duration duration;
  
  /// 动画曲线
  final Curve curve;
  
  /// 对齐方式
  final Alignment alignment;
  
  /// 动画结束回调
  /// 
  /// 只有在真正执行动画时才会调用（animate = true）
  final VoidCallback? onEnd;

  const AnimatedSizeBox({
    super.key,
    required this.sizeParamsNotifier,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeInOut,
    this.alignment = Alignment.topLeft,
    this.onEnd,
  });

  @override
  State<AnimatedSizeBox> createState() => _AnimatedSizeBoxState();
}

class _AnimatedSizeBoxState extends State<AnimatedSizeBox> {
  late Size _currentSize;

  @override
  void initState() {
    super.initState();
    _currentSize = widget.sizeParamsNotifier.value.size;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SizeAnimationParams>(
      valueListenable: widget.sizeParamsNotifier,
      builder: (context, params, child) {
        return OverflowBox(
          alignment: widget.alignment,
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: TweenAnimationBuilder<Size>(
            key: ValueKey(params), // 使用 params 作为 key，确保动画状态正确
            tween: Tween<Size>(
              begin: _currentSize,
              end: params.size,
            ),
            duration: params.animate ? widget.duration : Duration.zero,
            curve: widget.curve,
            onEnd: () {
              _currentSize = params.size;
              // 只有在真正执行动画时才调用回调
              if (params.animate && widget.onEnd != null) {
                widget.onEnd!();
              }
            },
            builder: (context, animatedSize, child) {
              return SizedBox(
                width: animatedSize.width,
                height: animatedSize.height,
                child: child,
              );
            },
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
