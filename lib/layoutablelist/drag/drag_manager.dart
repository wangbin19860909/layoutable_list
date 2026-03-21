import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../animator/animation_widget.dart';

/// onDrop 的返回值
class DropResult {
  /// 是否接受 drop
  final bool accepted;

  /// shadow 飞向的目标全局坐标（accepted=true 时必须提供）
  final Offset? targetPosition;

  const DropResult.accept(this.targetPosition) : accepted = true;
  const DropResult.reject() : accepted = false, targetPosition = null;
}

/// 单个 DropTarget 的注册信息
class _DropTargetEntry<T> {
  final ValueListenable<Rect> boundsListenable;
  final void Function(T data) onEnter;
  final void Function(T data, Offset localOffset) onMove;
  final void Function(T data) onExit;
  final DropResult Function(T data, Offset localOffset) onDrop;
  final void Function(T data) onDropBack;
  final void Function(T data) onDropCompleted;

  bool isHovered = false;

  _DropTargetEntry({
    required this.boundsListenable,
    required this.onEnter,
    required this.onMove,
    required this.onExit,
    required this.onDrop,
    required this.onDropBack,
    required this.onDropCompleted,
  });

  Rect get bounds => boundsListenable.value;
}

/// 拖拽管理器
///
/// 泛型 [T] 为拖拽携带的业务数据类型。
class DragManager<T> {
  /// 飞行动画配置
  final CurveConfig flyConfig;

  DragManager({
    this.flyConfig = const CurveConfig(curve: Curves.easeInOut, durationMs: 300),
  });

  final Map<int, _DropTargetEntry<T>> _targets = {};
  int _nextId = 0;

  T? _currentData;
  Rect? _origin;
  OverlayEntry? _overlayEntry;
  OverlayState? _overlayState;
  _DropTargetEntry<T>? _sourceTarget;

  final ValueNotifier<Offset> _shadowCenter = ValueNotifier(Offset.zero);
  Size _shadowSize = Size.zero;

  /// 注册 DropTarget，返回唯一 id
  int register({
    required ValueListenable<Rect> boundsListenable,
    required void Function(T data) onEnter,
    required void Function(T data, Offset localOffset) onMove,
    required void Function(T data) onExit,
    required DropResult Function(T data, Offset localOffset) onDrop,
    required void Function(T data) onDropBack,
    required void Function(T data) onDropCompleted,
  }) {
    final id = _nextId++;
    _targets[id] = _DropTargetEntry(
      boundsListenable: boundsListenable,
      onEnter: onEnter,
      onMove: onMove,
      onExit: onExit,
      onDrop: onDrop,
      onDropBack: onDropBack,
      onDropCompleted: onDropCompleted,
    );
    return id;
  }

  void unregister(int id) => _targets.remove(id);

  /// 按注册逆序遍历（后注册的在上层，优先响应）
  Iterable<_DropTargetEntry<T>> get _targetsReversed =>
      _targets.keys.toList().reversed.map((k) => _targets[k]!);

  /// 开始拖拽
  ///
  /// [context] 用于查找 OverlayState，只在此处使用，不持久持有
  void startDrag({
    required BuildContext context,
    required T data,
    required Rect origin,
    required Widget Function(T data) shadowBuilder,
  }) {
    if (_overlayEntry != null) return;

    _overlayState ??= Overlay.of(context);

    _currentData = data;
    _origin = origin;
    _shadowSize = origin.size;
    _shadowCenter.value = origin.center;
    debugPrint('[DragManager] startDrag origin=$origin shadowSize=$_shadowSize');

    // 找到包含 origin 中心的 DropTarget 作为 source
    _sourceTarget = _targetsReversed
        .where((e) => e.bounds.contains(origin.center))
        .firstOrNull;

    _overlayEntry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<Offset>(
        valueListenable: _shadowCenter,
        builder: (_, center, child) => Positioned(
          left: center.dx - _shadowSize.width / 2,
          top: center.dy - _shadowSize.height / 2,
          width: _shadowSize.width,
          height: _shadowSize.height,
          child: child!,
        ),
        child: IgnorePointer(child: shadowBuilder(data)),
      ),
    );

    _overlayState?.insert(_overlayEntry!);
  }

  /// 拖拽移动
  void updateDrag(Offset globalPoint) {
    if (_overlayEntry == null || _currentData == null) return;

    _shadowCenter.value = globalPoint;

    for (final entry in _targetsReversed) {
      final bounds = entry.bounds;
      final hit = bounds.contains(globalPoint);
      final localOffset = globalPoint - bounds.topLeft;

      if (hit) {
        if (!entry.isHovered) {
          entry.isHovered = true;
          entry.onEnter(_currentData as T);
        }
        entry.onMove(_currentData as T, localOffset);
      } else if (entry.isHovered) {
        entry.isHovered = false;
        entry.onExit(_currentData as T);
      }
    }
  }

  /// 结束拖拽
  void endDrag(Offset globalPoint) {
    if (_overlayEntry == null || _currentData == null) return;

    final data = _currentData as T;

    // 找到命中且 hover 中的 target
    _DropTargetEntry<T>? hitTarget;
    DropResult? dropResult;

    for (final entry in _targetsReversed) {
      if (entry.isHovered) {
        final localOffset = globalPoint - entry.bounds.topLeft;
        final result = entry.onDrop(data, localOffset);
        if (result.accepted) {
          hitTarget = entry;
          dropResult = result;
        } else {
          entry.isHovered = false;
        }
        break;
      }
    }

    if (hitTarget != null && dropResult != null && dropResult.targetPosition != null) {
      _flyTo(
        target: dropResult.targetPosition!,
        onComplete: () {
          hitTarget!.isHovered = false;
          hitTarget.onDropCompleted(data);
          _removeOverlay();
        },
      );
    } else {
      _flyBack(data);
    }
  }

  /// 取消拖拽（不触发 onDrop，直接飞回）
  void cancelDrag() {
    if (_overlayEntry == null || _currentData == null) return;

    final data = _currentData as T;

    for (final entry in _targetsReversed) {
      if (entry.isHovered) {
        entry.isHovered = false;
        entry.onExit(data);
      }
    }

    _flyBack(data);
  }

  /// shadow 飞回原点
  void _flyBack(T data) {
    _sourceTarget?.onDropBack(data);
    _flyTo(
      target: _origin!.center,
      onComplete: () {
        _sourceTarget?.onDropCompleted(data);
        _removeOverlay();
      },
    );
  }

  /// shadow 飞行动画
  void _flyTo({required Offset target, required VoidCallback onComplete}) {
    final overlay = _overlayState;
    if (overlay == null) {
      onComplete();
      return;
    }

    final from = _shadowCenter.value;
    debugPrint('[DragManager] flyTo from=$from target=$target shadowSize=$_shadowSize');
    if ((from - target).distance < 1.0) {
      onComplete();
      return;
    }

    // 用 AnimationController 驱动，挂在临时 OverlayEntry 上
    // 直接用 ticker 驱动 ValueNotifier
    final controller = AnimationController(
      vsync: overlay,
      duration: Duration(milliseconds: flyConfig.durationMs),
    );

    final animation = Tween<Offset>(begin: from, end: target)
        .animate(CurvedAnimation(parent: controller, curve: flyConfig.curve));

    animation.addListener(() => _shadowCenter.value = animation.value);

    controller.forward().whenComplete(() {
      controller.dispose();
      onComplete();
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _currentData = null;
    _origin = null;
    _sourceTarget = null;
  }

  void dispose() {
    _removeOverlay();
    _shadowCenter.dispose();
    _targets.clear();
  }
}
