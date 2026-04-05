import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../animator/animation_widget.dart';

/// onDrop 的返回值
class DropResult {
  /// 是否接受 drop
  final bool accepted;

  /// shadow 飞向的目标区域，**局部坐标**（相对于命中的 DropTarget bounds 左上角）
  /// accepted=true 时必须提供，DragManager 内部会自动转换为全局坐标
  final Rect? targetRect;

  const DropResult.accept(this.targetRect) : accepted = true;
  const DropResult.reject() : accepted = false, targetRect = null;
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

/// shadow 的飞行状态（center + scale）
class _ShadowState {
  final Offset center;
  final double scale;
  const _ShadowState(this.center, this.scale);
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

  final ValueNotifier<_ShadowState> _shadowState =
      ValueNotifier(const _ShadowState(Offset.zero, 1.0));
  Size _shadowSize = Size.zero;

  Offset get _shadowCenter => _shadowState.value.center;

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
    _shadowState.value = _ShadowState(origin.center, 1.0);
    debugPrint('[DragManager] startDrag origin=$origin shadowSize=$_shadowSize');

    _sourceTarget = _targetsReversed
        .where((e) => e.bounds.contains(origin.center))
        .firstOrNull;

    _overlayEntry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<_ShadowState>(
        valueListenable: _shadowState,
        builder: (_, state, child) => Positioned(
          left: state.center.dx - _shadowSize.width / 2,
          top: state.center.dy - _shadowSize.height / 2,
          width: _shadowSize.width,
          height: _shadowSize.height,
          child: Transform.scale(
            scale: state.scale,
            child: child!,
          ),
        ),
        child: IgnorePointer(child: shadowBuilder(data)),
      ),
    );

    _overlayState?.insert(_overlayEntry!);
  }

  /// 拖拽移动
  void updateDrag(Offset globalPoint) {
    if (_overlayEntry == null || _currentData == null) return;

    _shadowState.value = _ShadowState(globalPoint, 1.0);

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

    if (hitTarget != null && dropResult != null && dropResult.targetRect != null) {
      // 局部坐标转全局
      final globalRect = dropResult.targetRect!.shift(hitTarget.bounds.topLeft);
      _flyTo(
        targetRect: globalRect,
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

  /// shadow 飞回原点（尺寸恢复 1.0）
  void _flyBack(T data) {
    _sourceTarget?.onDropBack(data);
    _flyTo(
      targetRect: _origin!,
      onComplete: () {
        _sourceTarget?.onDropCompleted(data);
        _removeOverlay();
      },
    );
  }

  /// shadow 飞行动画：同时动画 center 和 scale
  ///
  /// scale = targetRect.size / _shadowSize，让 shadow 缩放到目标尺寸
  void _flyTo({required Rect targetRect, required VoidCallback onComplete}) {
    final overlay = _overlayState;
    if (overlay == null) {
      onComplete();
      return;
    }

    final fromCenter = _shadowCenter;
    final toCenter = targetRect.center;
    final toScaleX = _shadowSize.width > 0 ? targetRect.width / _shadowSize.width : 1.0;
    final toScaleY = _shadowSize.height > 0 ? targetRect.height / _shadowSize.height : 1.0;
    // 取较小的 scale 保持比例，或用平均值
    final toScale = (toScaleX + toScaleY) / 2;
    final fromScale = _shadowState.value.scale;

    debugPrint('[DragManager] flyTo from=$fromCenter→$toCenter scale=$fromScale→$toScale');

    if ((fromCenter - toCenter).distance < 1.0 && (fromScale - toScale).abs() < 0.01) {
      onComplete();
      return;
    }

    final controller = AnimationController(
      vsync: overlay,
      duration: Duration(milliseconds: flyConfig.durationMs),
    );

    final curved = CurvedAnimation(parent: controller, curve: flyConfig.curve);
    final centerAnim = Tween<Offset>(begin: fromCenter, end: toCenter).animate(curved);
    final scaleAnim = Tween<double>(begin: fromScale, end: toScale).animate(curved);

    void listener() {
      _shadowState.value = _ShadowState(centerAnim.value, scaleAnim.value);
    }

    controller.addListener(listener);
    controller.forward().whenComplete(() {
      controller.removeListener(listener);
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
    _shadowState.dispose();
    _targets.clear();
  }
}
