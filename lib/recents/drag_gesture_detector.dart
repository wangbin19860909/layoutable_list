import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 单向拖拽手势检测器
/// 
/// 封装 RawGestureDetector，根据 dragDirection 自动选择对应的手势识别器。
/// 支持自定义 gestureSettings（如 touchSlop）来精确控制手势触发条件。
class DragGestureDetector extends StatelessWidget {
  /// 拖拽方向
  /// - Axis.vertical: 纵向拖拽（使用 VerticalDragGestureRecognizer）
  /// - Axis.horizontal: 横向拖拽（使用 HorizontalDragGestureRecognizer）
  final Axis dragDirection;
  
  /// 拖拽开始回调
  final GestureDragStartCallback? onDragStart;
  
  /// 拖拽更新回调
  final GestureDragUpdateCallback? onDragUpdate;
  
  /// 拖拽结束回调
  final GestureDragEndCallback? onDragEnd;
  
  /// 拖拽取消回调
  final GestureDragCancelCallback? onDragCancel;
  
  /// 手势设置
  /// 
  /// 可以通过设置 touchSlop 来控制手势触发的灵敏度：
  /// - 增大 touchSlop：让拖拽更难触发（需要更大的偏移量）
  /// - 减小 touchSlop：让拖拽更容易触发
  /// 
  /// 例如：
  /// ```dart
  /// gestureSettings: DeviceGestureSettings(
  ///   touchSlop: 30.0,  // 默认约 18.0
  /// )
  /// ```
  final DeviceGestureSettings? gestureSettings;
  
  /// 子组件
  final Widget child;
  
  const DragGestureDetector({
    super.key,
    required this.dragDirection,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
    this.gestureSettings,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // 根据 dragDirection 选择对应的 Recognizer 类型
    if (dragDirection == Axis.vertical) {
      return RawGestureDetector(
        gestures: {
          VerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            VerticalDragGestureRecognizer>(
            () => VerticalDragGestureRecognizer(
              debugOwner: this,
            ),
            (recognizer) {
              recognizer
                ..onStart = onDragStart
                ..onUpdate = onDragUpdate
                ..onEnd = onDragEnd
                ..onCancel = onDragCancel;
              
              // 应用自定义的 gestureSettings
              if (gestureSettings != null) {
                recognizer.gestureSettings = gestureSettings;
              }
            },
          ),
        },
        child: child,
      );
    } else {
      return RawGestureDetector(
        gestures: {
          HorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            HorizontalDragGestureRecognizer>(
            () => HorizontalDragGestureRecognizer(
              debugOwner: this,
            ),
            (recognizer) {
              recognizer
                ..onStart = onDragStart
                ..onUpdate = onDragUpdate
                ..onEnd = onDragEnd
                ..onCancel = onDragCancel;
              
              // 应用自定义的 gestureSettings
              if (gestureSettings != null) {
                recognizer.gestureSettings = gestureSettings;
              }
            },
          ),
        },
        child: child,
      );
    }
  }
}
