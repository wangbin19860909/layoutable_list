import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../animator/item_animator.dart';
import 'drag_gesture_detector.dart';

/// Swipe 触发阈值配置
class SwipeThreshold {
  /// 速度阈值（像素/秒）
  final double velocityThreshold;
  
  /// 偏移量阈值（像素，绝对值）
  final double offsetThreshold;
  
  const SwipeThreshold({
    this.velocityThreshold = 800.0,
    this.offsetThreshold = 100.0,
  });
  
  /// 判断是否触发 swipe
  /// 满足以下任一条件即触发：
  /// 1. 速度绝对值 >= velocityThreshold
  /// 2. 偏移量绝对值 >= offsetThreshold
  bool shouldSwipe(double velocity, double offset) {
    return velocity.abs() >= velocityThreshold || 
           offset.abs() >= offsetThreshold;
  }
}

/// 拖拽结束的结果（密封类）
sealed class DragResult {
  const DragResult();
}

/// 回弹：拖拽未达到阈值，item 回到原位
class SnapBack extends DragResult {
  const SnapBack();
}

/// Swipe：拖拽达到阈值，触发滑动操作
class Swipe extends DragResult {
  /// 滑动方向
  final AxisDirection direction;
  
  /// 速度（像素/秒）
  final double velocity;
  
  /// 最终偏移量
  final Offset offset;
  
  const Swipe({
    required this.direction,
    required this.velocity,
    required this.offset,
  });
}

/// 拖拽状态监听器
abstract class ItemDragListener {
  void onDragStart(String itemId);
  void onDragMove(String itemId, Offset offset);
  void onDragEnd(String itemId, DragResult result);
}

/// Item 拖拽组件
/// 
/// 支持在交叉轴方向拖拽 item，提供两种使用模式：
/// 1. 配合动画系统：传入 paramsNotifier，由 ItemAnimator 处理动画
/// 2. 独立使用：不传 paramsNotifier，自己实现 Transform
class ItemDraggable extends StatefulWidget {
  /// Item ID
  final String itemId;
  
  /// 动画参数通知器（可选）
  /// - 如果传入，则通过修改 params 来控制位置
  /// - 如果为 null，则自己实现 Transform
  final ValueNotifier<ItemAnimatorParams>? paramsNotifier;
  
  /// 列表滚动方向
  /// - Axis.horizontal: 列表横向滚动，拖拽方向是纵向（上下）
  /// - Axis.vertical: 列表纵向滚动，拖拽方向是横向（左右）
  final Axis scrollDirection;
  
  /// 子组件
  final Widget child;
  
  /// 拖拽状态监听器
  final ItemDragListener? listener;
  
  /// Swipe 触发阈值
  final SwipeThreshold swipeThreshold;
  
  /// 回弹动画时长
  final Duration snapBackDuration;
  
  /// 回弹动画曲线
  final Curve snapBackCurve;
  
  /// 拖拽手势设置
  /// 
  /// 可以通过设置 touchSlop 来控制拖拽触发的灵敏度：
  /// - 增大 touchSlop：让拖拽更难触发，需要更接近纯交叉轴方向（类似角度限制）
  /// - 减小 touchSlop：让拖拽更容易触发
  /// 
  /// 例如，要求接近 80 度才触发拖拽：
  /// ```dart
  /// dragGestureSettings: DeviceGestureSettings(
  ///   touchSlop: 30.0,  // 默认约 18.0
  /// )
  /// ```
  final DeviceGestureSettings? dragGestureSettings;
  
  const ItemDraggable({
    super.key,
    required this.itemId,
    this.paramsNotifier,
    required this.scrollDirection,
    required this.child,
    this.listener,
    this.swipeThreshold = const SwipeThreshold(),
    this.snapBackDuration = const Duration(milliseconds: 600),  // 增加到 600ms
    this.snapBackCurve = Curves.easeOutBack,  // 使用带轻微回弹的曲线
    this.dragGestureSettings,
  });

  @override
  State<ItemDraggable> createState() => _ItemDraggableState();
}

class _ItemDraggableState extends State<ItemDraggable> with TickerProviderStateMixin {
  /// 当前偏移量（用于独立模式）
  Offset _currentOffset = Offset.zero;
  
  /// 是否正在拖拽
  bool _isDragging = false;
  
  /// 回弹动画控制器（用于独立模式）
  AnimationController? _snapBackController;
  Animation<Offset>? _snapBackAnimation;
  
  /// 回弹动画控制器（用于模式 1）
  AnimationController? _mode1SnapBackController;
  Animation<Offset>? _mode1SnapBackAnimation;

  @override
  void initState() {
    super.initState();
    
    // 如果是独立模式，创建回弹动画控制器
    if (widget.paramsNotifier == null) {
      _snapBackController = AnimationController(
        vsync: this,
        duration: widget.snapBackDuration,
      );
    }
  }

  @override
  void dispose() {
    _snapBackController?.dispose();
    _mode1SnapBackController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    
    // 如果是独立模式，需要自己实现 Transform
    if (widget.paramsNotifier == null) {
      // 如果有回弹动画，使用动画值
      if (_snapBackAnimation != null) {
        child = AnimatedBuilder(
          animation: _snapBackAnimation!,
          builder: (context, child) {
            return Transform.translate(
              offset: _snapBackAnimation!.value,
              child: child,
            );
          },
          child: child,
        );
      } else {
        // 否则使用当前偏移量
        child = Transform.translate(
          offset: _currentOffset,
          child: child,
        );
      }
    }
    
    // 确定拖拽方向（交叉轴）
    final dragDirection = widget.scrollDirection == Axis.horizontal
        ? Axis.vertical  // 列表横向滚动，拖拽是纵向
        : Axis.horizontal;  // 列表纵向滚动，拖拽是横向
    
    // 使用 DragGestureDetector，支持自定义 gestureSettings
    return DragGestureDetector(
      dragDirection: dragDirection,
      gestureSettings: widget.dragGestureSettings,
      onDragStart: _handleDragStart,
      onDragUpdate: _handleDragUpdate,
      onDragEnd: _handleDragEnd,
      onDragCancel: _handleDragCancel,
      child: child,
    );
  }

  /// 处理拖拽开始
  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    
    // 如果是独立模式且有回弹动画，取消动画
    if (widget.paramsNotifier == null) {
      _snapBackController?.stop();
      _snapBackAnimation = null;
    }
    
    widget.listener?.onDragStart(widget.itemId);
  }

  /// 处理拖拽更新
  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    
    // 计算交叉轴方向的偏移增量
    final delta = _getCrossAxisDelta(details.delta);
    
    if (widget.paramsNotifier != null) {
      // 模式 1：offset 和 toOffset 相同，不触发动画
      final params = widget.paramsNotifier!.value;
      final currentOffset = params.offset;
      final newOffset = currentOffset + delta;
      
      widget.paramsNotifier!.value = params.copy(
        offset: newOffset,
        toOffset: newOffset,
      );
    } else {
      // 模式 2：更新本地 offset
      setState(() {
        _currentOffset += delta;
      });
    }
    
    // 通知监听器
    final currentOffset = widget.paramsNotifier?.value.offset ?? _currentOffset;
    widget.listener?.onDragMove(widget.itemId, currentOffset);
  }

  /// 处理拖拽结束
  void _handleDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
    
    // 获取当前偏移量
    final currentOffset = widget.paramsNotifier?.value.offset ?? _currentOffset;
    
    // 计算交叉轴方向的速度
    final velocity = _getCrossAxisVelocity(details.velocity.pixelsPerSecond);
    
    // 获取交叉轴方向的偏移量
    final crossAxisOffset = _getCrossAxisOffset(currentOffset);
    
    // 判断是否触发 swipe
    if (widget.swipeThreshold.shouldSwipe(velocity, crossAxisOffset)) {
      // 根据速度判断方向
      final direction = _getSwipeDirectionFromVelocity(velocity);
      
      // 检查速度和偏移的方向是否一致
      final isDirectionConsistent = _isDirectionConsistent(direction, crossAxisOffset);
      
      if (isDirectionConsistent) {
        // 方向一致，触发 swipe
        final result = Swipe(
          direction: direction,
          velocity: velocity,
          offset: currentOffset,
        );
        widget.listener?.onDragEnd(widget.itemId, result);
      } else {
        // 方向不一致，回弹（传入速度）
        _snapBack(velocity: velocity.abs());
        widget.listener?.onDragEnd(widget.itemId, const SnapBack());
      }
    } else {
      // 未达到阈值，回弹（传入速度）
      _snapBack(velocity: velocity.abs());
      widget.listener?.onDragEnd(widget.itemId, const SnapBack());
    }
  }

  /// 处理拖拽取消
  void _handleDragCancel() {
    if (!_isDragging) return;
    _isDragging = false;
    
    // 回弹
    _snapBack();
    widget.listener?.onDragEnd(widget.itemId, const SnapBack());
  }

  /// 执行回弹动画
  void _snapBack({double velocity = 0.0}) {
    if (widget.paramsNotifier != null) {
      // 模式 1：自己执行动画，每帧更新 params.offset
      final params = widget.paramsNotifier!.value;
      final currentOffset = params.offset;
      
      if (currentOffset == Offset.zero) {
        return;
      }
      
      // 清理旧的动画控制器
      _mode1SnapBackController?.dispose();
      
      _mode1SnapBackController = AnimationController(
        vsync: this,
        duration: widget.snapBackDuration,
      );
      
      _mode1SnapBackAnimation = Tween<Offset>(
        begin: currentOffset,
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _mode1SnapBackController!,
        curve: widget.snapBackCurve,
      ));
      
      _mode1SnapBackAnimation!.addListener(() {
        if (mounted && widget.paramsNotifier != null) {
          final currentParams = widget.paramsNotifier!.value;
          final newValue = _mode1SnapBackAnimation!.value;
          widget.paramsNotifier!.value = currentParams.copy(
            offset: newValue,
            toOffset: newValue,
          );
        }
      });
      
      _mode1SnapBackController!.addStatusListener((status) {
        if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
          if (mounted) {
            _mode1SnapBackController?.dispose();
            _mode1SnapBackController = null;
            _mode1SnapBackAnimation = null;
          }
        }
      });
      
      final distance = currentOffset.distance;
      final normalizedVelocity = distance > 0 ? velocity / distance : 0.0;
      final clampedVelocity = (normalizedVelocity / 200.0).clamp(0.0, 0.5);
      
      _mode1SnapBackController!.fling(velocity: clampedVelocity);
      
    } else {
      // 模式 2：自己实现回弹动画，支持初速度
      if (_currentOffset == Offset.zero) {
        return;
      }
      
      // 使用 fling 方法支持初速度
      // velocity 需要归一化到 0-1 范围
      final distance = _currentOffset.distance;
      final normalizedVelocity = velocity / distance;
      
      _snapBackAnimation = Tween<Offset>(
        begin: _currentOffset,
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _snapBackController!,
        curve: widget.snapBackCurve,
      ));
      
      // 使用 fling 启动动画，传入初速度
      // 调整速度范围，让动画更平滑
      // 注意：使用正值，fling 是从 0 向 1 运动
      final clampedVelocity = (normalizedVelocity / 200.0).clamp(0.0, 0.5);
      
      _snapBackController!.fling(
        velocity: clampedVelocity,
      ).then((_) {
        if (mounted) {
          setState(() {
            _currentOffset = Offset.zero;
            _snapBackAnimation = null;
          });
        }
      });
    }
  }

  /// 获取交叉轴方向的偏移增量
  Offset _getCrossAxisDelta(Offset delta) {
    if (widget.scrollDirection == Axis.horizontal) {
      // 列表横向滚动，拖拽是纵向
      return Offset(0, delta.dy);
    } else {
      // 列表纵向滚动，拖拽是横向
      return Offset(delta.dx, 0);
    }
  }

  /// 获取交叉轴方向的速度
  double _getCrossAxisVelocity(Offset velocity) {
    if (widget.scrollDirection == Axis.horizontal) {
      // 列表横向滚动，拖拽是纵向
      return velocity.dy;
    } else {
      // 列表纵向滚动，拖拽是横向
      return velocity.dx;
    }
  }

  /// 获取交叉轴方向的偏移量
  double _getCrossAxisOffset(Offset offset) {
    if (widget.scrollDirection == Axis.horizontal) {
      // 列表横向滚动，拖拽是纵向
      return offset.dy;
    } else {
      // 列表纵向滚动，拖拽是横向
      return offset.dx;
    }
  }

  /// 根据速度获取 swipe 方向
  AxisDirection _getSwipeDirectionFromVelocity(double velocity) {
    if (widget.scrollDirection == Axis.horizontal) {
      // 列表横向滚动，拖拽是纵向
      return velocity > 0 ? AxisDirection.down : AxisDirection.up;
    } else {
      // 列表纵向滚动，拖拽是横向
      return velocity > 0 ? AxisDirection.right : AxisDirection.left;
    }
  }
  
  /// 检查速度方向和偏移方向是否一致
  /// 
  /// 例如：
  /// - up 方向（velocity < 0）必须要求 offset < 0
  /// - down 方向（velocity > 0）必须要求 offset > 0
  bool _isDirectionConsistent(AxisDirection direction, double offset) {
    switch (direction) {
      case AxisDirection.up:
      case AxisDirection.left:
        return offset < 0;
      case AxisDirection.down:
      case AxisDirection.right:
        return offset > 0;
    }
  }
}
