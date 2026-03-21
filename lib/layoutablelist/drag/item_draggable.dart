import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'drag_manager.dart';

/// 拖拽触发 widget
///
/// longPress 触发拖拽，后续 pointer 事件直接通过 [Listener] 接收，
/// 绕过手势竞争（避免被 ListView 等滚动容器抢走事件）。
class ItemDraggable<T> extends StatefulWidget {
  final DragManager<T> dragManager;
  final T data;
  final Widget Function(T data) shadowBuilder;
  final Widget child;
  final Duration longPressDuration;

  /// 覆盖 shadow 尺寸（不传则用 item 自身的 RenderBox 尺寸）
  final Size? shadowSize;

  const ItemDraggable({
    super.key,
    required this.dragManager,
    required this.data,
    required this.shadowBuilder,
    required this.child,
    this.shadowSize,
    this.longPressDuration = const Duration(milliseconds: 500),
  });

  @override
  State<ItemDraggable<T>> createState() => _ItemDraggableState<T>();
}

class _ItemDraggableState<T> extends State<ItemDraggable<T>> {
  bool _dragging = false;
  Offset _dragOffset = Offset.zero;
  int? _activePointer; // 触发 longPress 的 pointer id

  // 用 LongPressGestureRecognizer 检测 longPress，触发后切换到 Listener 模式
  late LongPressGestureRecognizer _longPressRecognizer;

  @override
  void initState() {
    super.initState();
    _longPressRecognizer = LongPressGestureRecognizer(
      duration: widget.longPressDuration,
    )
      ..onLongPressStart = _onLongPressStart
      ..onLongPressEnd = _onLongPressEnd
      ..onLongPressCancel = _onLongPressCancel;
  }

  @override
  void dispose() {
    _longPressRecognizer.dispose();
    super.dispose();
  }

  Rect _getGlobalRect() {
    final box = context.findRenderObject() as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _dragging = true;
    final rect = _getGlobalRect();
    final origin = widget.shadowSize != null
        ? Rect.fromCenter(
            center: rect.center,
            width: widget.shadowSize!.width.isInfinite ? rect.width : widget.shadowSize!.width,
            height: widget.shadowSize!.height.isInfinite ? rect.height : widget.shadowSize!.height,
          )
        : rect;
    _dragOffset = details.globalPosition - origin.center;
    widget.dragManager.startDrag(
      context: context,
      data: widget.data,
      origin: origin,
      shadowBuilder: widget.shadowBuilder,
    );
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    _activePointer = null;
    widget.dragManager.endDrag(details.globalPosition - _dragOffset);
  }

  void _onLongPressCancel() {
    if (!_dragging) return;
    _dragging = false;
    _activePointer = null;
    widget.dragManager.cancelDrag();
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointer = event.pointer;
    _longPressRecognizer.addPointer(event);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_dragging || event.pointer != _activePointer) return;
    // 直接用 pointer 事件，完全绕过手势竞争
    widget.dragManager.updateDrag(event.position - _dragOffset);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_dragging || event.pointer != _activePointer) return;
    _dragging = false;
    _activePointer = null;
    widget.dragManager.endDrag(event.position - _dragOffset);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (!_dragging || event.pointer != _activePointer) return;
    _dragging = false;
    _activePointer = null;
    widget.dragManager.cancelDrag();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}
