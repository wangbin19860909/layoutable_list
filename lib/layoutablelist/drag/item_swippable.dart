import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../animator/item_animator.dart';
import '../animator/animation_widget.dart';

/// 拖拽位移阈值配置
///
/// [min] 负方向最大位移，double.negativeInfinity 表示不限制
/// [max] 正方向最大位移，double.infinity 表示不限制
/// [dampingFraction] 阻尼起始位置占 min/max 的比例（0~1），
///   例如 0.5 表示从 max*0.5 处开始施加阻尼，默认 0.5
///
/// 快到阈值时会产生阻尼效果（rubber band），越接近阈值阻力越大。
class OffsetThreshold {
  final double min;
  final double max;
  final double dampingFraction;

  const OffsetThreshold({
    this.min = double.negativeInfinity,
    this.max = double.infinity,
    this.dampingFraction = 0.5,
  });

  /// 对原始 delta 施加阻尼，返回实际应用的 delta
  double applyDamping(double current, double delta) {
    final next = current + delta;

    // 超出上限
    if (next > max) {
      return _rubberBand(current, delta, max).clamp(double.negativeInfinity, max - current);
    }
    // 超出下限
    if (next < min) {
      return _rubberBand(current, delta, min).clamp(min - current, double.infinity);
    }
    // 进入上限阻尼区间
    if (max != double.infinity && next > max * dampingFraction) {
      return _rubberBand(current, delta, max);
    }
    // 进入下限阻尼区间（min 是负数，乘以 fraction 后绝对值变小，即更靠近 0）
    if (min != double.negativeInfinity && next < min * dampingFraction) {
      return _rubberBand(current, delta, min);
    }

    return delta;
  }

  /// rubber band 阻尼：从 limit*dampingFraction 到 limit 线性衰减至 0
  double _rubberBand(double current, double delta, double limit) {
    final start = limit * dampingFraction;
    final range = (limit - start).abs(); // 阻尼区间长度
    if (range <= 0) return 0;
    final distToLimit = (limit - current).abs();
    final resistance = (distToLimit / range).clamp(0.0, 1.0);
    return delta * resistance;
  }
}

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
sealed class SwipeResult {
  const SwipeResult();
}

/// 回弹：拖拽未达到阈值，item 回到原位
class SnapBack extends SwipeResult {
  const SnapBack();
}

/// Swipe：拖拽达到阈值，触发滑动操作
class Swipe extends SwipeResult {
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
mixin ItemSwipeListener {
  void onSwipeStart(String itemId) {}
  void onSwipeMove(String itemId, Offset offset) {}
  /// 返回 false 时，即使 result 是 Swipe 也会执行 snapback
  bool onSwipeEnd(String itemId, SwipeResult result) => true;
  /// snapback 动画结束回调（可选覆盖）
  void onSnapBackEnd(String itemId) {}
}

/// Item 拖拽组件
/// 
/// 支持在交叉轴方向拖拽 item，提供两种使用模式：
/// 1. 配合动画系统：传入 paramsNotifier，由 ItemAnimator 处理动画
/// 2. 独立使用：不传 paramsNotifier，自己实现 Transform
class ItemSwippable extends StatefulWidget {
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
  final ItemSwipeListener? listener;
  
  /// Swipe 触发阈值
  final SwipeThreshold swipeThreshold;
  
  /// 回弹动画配置
  final CurveConfig snapBackConfig;
  
  /// 拖拽位移阈值（含阻尼效果）
  final OffsetThreshold dragThreshold;

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
  final DeviceGestureSettings? gestureSettings;
  
  const ItemSwippable({
    super.key,
    required this.itemId,
    this.paramsNotifier,
    required this.scrollDirection,
    required this.child,
    this.listener,
    this.swipeThreshold = const SwipeThreshold(),
    this.snapBackConfig = const CurveConfig(curve: Curves.easeOutBack, durationMs: 600),
    this.dragThreshold = const OffsetThreshold(),
    this.gestureSettings,
  });

  @override
  State<ItemSwippable> createState() => _ItemSwippableState();
}

class _ItemSwippableState extends State<ItemSwippable> with TickerProviderStateMixin {
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
        duration: Duration(milliseconds: widget.snapBackConfig.durationMs),
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
    
    // 根据 dragDirection 选择对应的手势识别器
    if (dragDirection == Axis.vertical) {
      return RawGestureDetector(
        gestures: {
          VerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<
              VerticalDragGestureRecognizer>(
            () => VerticalDragGestureRecognizer(debugOwner: this),
            (r) {
              r
                ..onStart = _handleDragStart
                ..onUpdate = _handleDragUpdate
                ..onEnd = _handleDragEnd
                ..onCancel = _handleDragCancel;
              if (widget.gestureSettings != null) {
                r.gestureSettings = widget.gestureSettings;
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
            () => HorizontalDragGestureRecognizer(debugOwner: this),
            (r) {
              r
                ..onStart = _handleDragStart
                ..onUpdate = _handleDragUpdate
                ..onEnd = _handleDragEnd
                ..onCancel = _handleDragCancel;
              if (widget.gestureSettings != null) {
                r.gestureSettings = widget.gestureSettings;
              }
            },
          ),
        },
        child: child,
      );
    }
  }

  /// 处理拖拽开始
  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    
    // 如果是独立模式且有回弹动画，取消动画
    if (widget.paramsNotifier == null) {
      _snapBackController?.stop();
      _snapBackAnimation = null;
    }
    
    widget.listener?.onSwipeStart(widget.itemId);
  }

  /// 处理拖拽更新
  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    
    // 计算交叉轴方向的偏移增量（施加阻尼）
    final rawDelta = _getCrossAxisDelta(details.delta);
    final delta = _applyThresholdDamping(rawDelta);
    
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
    widget.listener?.onSwipeMove(widget.itemId, currentOffset);
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
        final accepted = widget.listener?.onSwipeEnd(widget.itemId, result) ?? true;
        if (!accepted) {
          _snapBack(velocity: velocity.abs());
        }
      } else {
        // 方向不一致，回弹
        _snapBack(velocity: velocity.abs());
        widget.listener?.onSwipeEnd(widget.itemId, const SnapBack());
      }
    } else {
      // 未达到阈值，回弹
      _snapBack(velocity: velocity.abs());
      widget.listener?.onSwipeEnd(widget.itemId, const SnapBack());
    }
  }

  /// 处理拖拽取消
  void _handleDragCancel() {
    if (!_isDragging) return;
    _isDragging = false;
    
    // 回弹
    _snapBack();
    widget.listener?.onSwipeEnd(widget.itemId, const SnapBack());
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
        duration: Duration(milliseconds: widget.snapBackConfig.durationMs),
      );
      
      _mode1SnapBackAnimation = Tween<Offset>(
        begin: currentOffset,
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _mode1SnapBackController!,
        curve: widget.snapBackConfig.curve,
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
            widget.listener?.onSnapBackEnd(widget.itemId);
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
        curve: widget.snapBackConfig.curve,
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
          widget.listener?.onSnapBackEnd(widget.itemId);
        }
      });
    }
  }

  /// 对交叉轴 delta 施加阻尼
  Offset _applyThresholdDamping(Offset rawDelta) {
    final current = widget.paramsNotifier?.value.offset ?? _currentOffset;
    if (widget.scrollDirection == Axis.horizontal) {
      final dampedDy = widget.dragThreshold.applyDamping(current.dy, rawDelta.dy);
      return Offset(0, dampedDy);
    } else {
      final dampedDx = widget.dragThreshold.applyDamping(current.dx, rawDelta.dx);
      return Offset(dampedDx, 0);
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
