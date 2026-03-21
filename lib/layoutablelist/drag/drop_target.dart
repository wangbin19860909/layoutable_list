import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'drag_manager.dart';

/// DropTarget widget
///
/// 自动向 [DragManager] 注册/注销，[boundsListenable] 提供实时全局 bounds。
class DropTarget<T> extends StatefulWidget {
  final DragManager<T> dragManager;
  final ValueListenable<Rect> boundsListenable;

  final void Function(T data) onEnter;
  final void Function(T data, Offset localOffset) onMove;
  final void Function(T data) onExit;

  /// 手指抬起时同步调用，返回是否接受及 shadow 飞向的目标全局坐标
  final DropResult Function(T data, Offset localOffset) onDrop;

  /// drop 被拒绝或没命中，shadow 开始飞回时触发
  final void Function(T data) onDropBack;

  /// shadow 飞行动画结束后调用（飞入或飞回都会触发）
  final void Function(T data) onDropCompleted;

  final Widget child;

  const DropTarget({
    super.key,
    required this.dragManager,
    required this.boundsListenable,
    required this.onEnter,
    required this.onMove,
    required this.onExit,
    required this.onDrop,
    required this.onDropBack,
    required this.onDropCompleted,
    required this.child,
  });

  @override
  State<DropTarget<T>> createState() => _DropTargetState<T>();
}

class _DropTargetState<T> extends State<DropTarget<T>> {
  late int _id;

  @override
  void initState() {
    super.initState();
    _id = widget.dragManager.register(
      boundsListenable: widget.boundsListenable,
      onEnter: widget.onEnter,
      onMove: widget.onMove,
      onExit: widget.onExit,
      onDrop: widget.onDrop,
      onDropBack: widget.onDropBack,
      onDropCompleted: widget.onDropCompleted,
    );
  }

  @override
  void dispose() {
    widget.dragManager.unregister(_id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
