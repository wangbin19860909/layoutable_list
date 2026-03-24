import 'package:flutter/material.dart';
import '../../service_holder.dart';
import '../logger.dart';
import '../layoutable_list_widget.dart';
import 'animation_widget.dart';
import 'item_animator.dart';
import '../list_adapter.dart';

/// 动画中断器，支持提前触发 onComplete
abstract class AnimationInterrupter {
  void interrupt();
}

/// 计数回调：所有持有者都调用后才触发 onComplete
/// 支持 interrupt()，立即触发 onComplete 并清空
class _CountCallback implements AnimationInterrupter {
  final List<VoidCallback> _callbacks = List.empty(growable: true);
  VoidCallback? onComplete;
  int _count = 0;

  _CountCallback({this.onComplete});

  void doOnComplete(VoidCallback callback) {
    _count++;
    _callbacks.add(callback);
  }

  void call() {
    _count--;
    if (_count <= 0) {
      final callbacks = List.of(_callbacks);
      _callbacks.clear();
      for (var callback in callbacks) {
        callback();
      }
      onComplete?.call();
      onComplete = null;
    }
  }

  /// 立即触发 onComplete 并清空，用于中断当前动画流程
  @override
  void interrupt() {
    onComplete?.call();
    onComplete = null;
    _callbacks.clear();
  }
}

class _ResetParamsCallback {
  final ValueNotifier<ItemAnimatorParams> notifer;

  late ItemAnimatorParams anchorParams;

  _ResetParamsCallback({required this.notifer});

  void call(int index) {
    if (notifer.value == anchorParams) {
      notifer.value = anchorParams.copy(
        index: index,
        offset: Offset.zero,
        toOffset: Offset.zero,
        size: Size.zero,
      );
    }
  }
}

///
/// 管理所有 item 的动画参数，提供自由的动画控制能力。
/// 支持 add/remove/padding 等变更的补位动画，可在同一帧内合并。
///
/// 使用流程：
/// 1. performLayoutAnimations() / performItemAnimation() — 在数据变更前调用，计算补位动画参数
/// 2. 执行数据变更（add/remove/改 padding 等）
class ItemAnimatorController extends ChangeNotifier {
  static final _log = Logger('ItemAnimatorController');
  final ServiceHolder<LayoutManager> _layoutManagerHolder;
  final SpringConfig? springConfig;
  final CurveConfig? curveConfig;

  LayoutManager get layoutManager {
    final manager = _layoutManagerHolder.target;
    if (manager == null) {
      throw StateError('LayoutManager not attached yet');
    }
    return manager;
  }

  final Map<String, ValueNotifier<ItemAnimatorParams>> _params = {};

  ItemAnimatorController({
    required ServiceHolder<LayoutManager> layoutManagerHolder,
    this.springConfig,
    this.curveConfig,
  }) : _layoutManagerHolder = layoutManagerHolder;

  /// 获取 item 当前的动画参数，不存在返回 null
  ItemAnimatorParams? getAnimatorParams(String itemId) {
    return _params[itemId]?.value;
  }

  /// 获取 item 的动画参数 ValueNotifier（用于 ItemAnimator / ItemDraggable 监听）
  /// 不存在时自动创建
  ValueNotifier<ItemAnimatorParams> listenAnimatorParams(
    String itemId,
    int index,
  ) {
    var notifier = _params.putIfAbsent(
      itemId,
      () => ValueNotifier(
        ItemAnimatorParams(
          index: index,
          offset: Offset.zero,
          toOffset: Offset.zero,
          scale: 1.0,
          alpha: 1.0,
        ),
      ),
    );
    notifier.value.index = index;
    return notifier;
  }

  /// item 被卸载时重置，避免重新挂载时执行残留动画
  void onItemUnmounted(String itemId) {
    _params.remove(itemId);
    _log.d('onItemUnmounted: $itemId');
  }

  /// 设置单个 item 的动画参数，立即生效，无需 commit()。
  void performItemAnimation(
    String itemId,
    int index, {
    CurveConfig? curveConfig,
    double? offsetX,
    double? offsetY,
    double? scalle,
    double? fromAlpha,
    double? alpha,
    VoidCallback? onComplete
  }) {
    var notifier = _params[itemId];
    if (notifier == null) {
      _params[itemId] = ValueNotifier(
        ItemAnimatorParams(
          index: index,
          curveConfig: curveConfig,
          offset: Offset.zero,
          toOffset: Offset.zero,
          scale: 1.0,
          alpha: fromAlpha ?? 1.0,
          toAlpha: alpha ?? 1.0,
          onComplete: onComplete
        ),
      );
    } else {
      if (notifier.value.index == index) {
        notifier.value = notifier.value.copy(
          curveConfig: curveConfig,
          offset: fromAlpha != null ? notifier.value.offset : null,
          alpha: fromAlpha ?? notifier.value.alpha,
          toOffset: Offset(
            offsetX ?? notifier.value.offset.dx,
            offsetY ?? notifier.value.offset.dy,
          ),
          toScale: scalle ?? notifier.value.scale,
          toAlpha: alpha ?? notifier.value.alpha,
          onComplete: onComplete
        );
      } else {
        final origLayoutParams = layoutManager.getLayoutParamsForPosition(
          index: notifier.value.index,
        );

        final layoutParams = layoutManager.getLayoutParamsForPosition(
          index: index,
        );

        var offset = origLayoutParams.rect.topLeft + notifier.value.offset - layoutParams.rect.topLeft;
        notifier.value = notifier.value.copy(
          curveConfig: curveConfig,
          offset: offset,
          toOffset: Offset(
            offsetX ?? offset.dx,
            offsetY ?? offset.dy,
          ),
          toScale: scalle ?? notifier.value.scale,
          toAlpha: alpha ?? notifier.value.alpha,
          onComplete: onComplete
        );
      }
    }
  }

  /// 根据 add/remove 变更批量计算补位动画参数，需配合 commit() 触发 UI 刷新。
  ///
  /// 在数据变更之前调用，传入变更前的 adapter 状态。
  /// 内部自动推算每个 item 的旧/新 index，并处理 remove 时的 scrollOffset 预测。
  ///
  /// [adapter] - 变更前的 adapter
  /// [addIndexes] - 本次新增的插入位置（变更后的 index，升序）
  /// [removeIndexes] - 本次删除的位置（变更前的 index，升序）
  /// [padding] - 可选，变更后的 padding
  /// [itemSize] - 可选，变更后的 item 尺寸（width x height），用于计算新布局参数
  /// [scrollOffset] - 可选，覆盖当前 scrollOffset
  /// [refreshAfterAnimation] - 动画结束后是否触发数据刷新（默认 false）
  ///
  /// ## refreshAfterAnimation 的两种模式
  ///
  /// **false（默认）：先变更数据，再执行动画**
  /// 调用顺序：performLayoutAnimations → applyDiff（数据变更）
  /// - 数据变更后 Flutter 立即 rebuild，item 已在新位置
  /// - 动画从"旧位置相对新位置的偏移"开始，向 Offset.zero 运动
  /// - index 设为 newIndex，rebuild 后 widget 能正确找到对应的 notifier
  ///
  /// **true：先执行动画，动画结束后再变更数据**
  /// 调用顺序：performLayoutAnimations → 动画播放 → onComplete 回调中 applyDiff
  /// - 数据变更前 item 仍在旧位置，动画从当前视觉位置向新位置运动
  /// - fromOffset 基于 origLayoutParams（当前视觉位置）计算，toOffset 为新旧位置之差
  /// - index 保持 oldIndex，动画期间 widget 仍能找到对应的 notifier
  /// - 适用于需要"先看到动画效果、动画完成后数据才生效"的场景（如不同尺寸 item 交换）
  AnimationInterrupter? performLayoutAnimations({
    required ListAdapter adapter,
    List<int> addIndexes = const [],
    List<int> removeIndexes = const [],
    Map<String, int> moveIndexes = const {},
    EdgeInsetsGeometry? padding,
    Size? itemSize,
    double? scrollOffset,
    EdgeInsetsGeometry? edgeSpacing,
    Size? itemSpacing,
    Object? newTag,
    VoidCallback? onComplete,
    bool refreshAfterAnimation = false,
  }) {
    final oldItemCount = adapter.itemCount;
    final newItemCount = oldItemCount - removeIndexes.length + addIndexes.length;
    final currentScrollOffset = scrollOffset ?? layoutManager.scrollOffset;

    // 预测变更后 ScrollView 会调整到的新 scrollOffset
    // 不仅处理 item 减少，也处理 padding/itemSize/edgeSpacing 变化导致 maxScroll 缩小的情况
    final newScrollOffset = _resolveNewScrollOffset(
      newItemCount: newItemCount,
      currentScrollOffset: currentScrollOffset,
      padding: padding,
      itemSize: itemSize,
      edgeSpacing: edgeSpacing,
      itemSpacing: itemSpacing,
    );

    // 构建 removeIndexes 的 Set，方便快速查找
    final removeIndexSet = removeIndexes.toSet();

    final _CountCallback countCallback = _CountCallback(onComplete: onComplete);

    for (final itemId in _params.keys) {
      final notifier = _params[itemId];
      if (notifier == null || !notifier.hasListeners) continue;

      final oldIndex = adapter.findChildIndex(itemId);
      if (oldIndex == null) continue;

      if (removeIndexSet.contains(oldIndex)) continue;

      int newIndex;
      if (moveIndexes.containsKey(itemId)) {
        // moveIndexes 直接指定 newIndex
        newIndex = moveIndexes[itemId]!;
      } else {
        // 原有推算逻辑
        newIndex = oldIndex;
        for (final ri in removeIndexes) {
          if (ri < oldIndex) newIndex--;
        }
        for (final ai in addIndexes) {
          if (ai <= newIndex) newIndex++;
        }
      }

      final origLayoutParams = layoutManager.getLayoutParamsForPosition(
        index: notifier.value.index,
        scrollOffset: currentScrollOffset,
      );

      final oldLayoutParams = layoutManager.getLayoutParamsForPosition(
        index: oldIndex,
        itemCount: oldItemCount,
        scrollOffset: currentScrollOffset,
      );

      final newLayoutParams = layoutManager.getLayoutParamsForPosition(
        index: newIndex,
        itemCount: newItemCount,
        scrollOffset: newScrollOffset,
        padding: padding,
        itemSize: itemSize,
        edgeSpacing: edgeSpacing,
        itemSpacing: itemSpacing,
        tag: newTag,
      );

      final fromOffset =
          refreshAfterAnimation
              // 动画先行模式：数据未变更，item 仍在旧位置
              // 从当前视觉位置（origLayoutParams + 残留 offset）换算到 oldLayoutParams 坐标系
              ? origLayoutParams.rect.topLeft +
                  notifier.value.offset -
                  oldLayoutParams.rect.topLeft
              // 数据先行模式：数据已变更，item 已在新位置
              // 从旧位置换算出相对于新位置的偏移，作为动画起点
              : oldLayoutParams.rect.topLeft +
                  notifier.value.offset -
                  newLayoutParams.rect.topLeft;

      final toOffset =
          refreshAfterAnimation
              // 动画先行模式：目标是新位置相对旧位置的偏移，动画结束时 item 视觉上到达新位置
              ? newLayoutParams.rect.topLeft - oldLayoutParams.rect.topLeft
              // 数据先行模式：目标是 Offset.zero，即 item 回到自身的布局位置
              : Offset.zero;

      if (fromOffset == toOffset && newLayoutParams.rect.size == oldLayoutParams.rect.size) {
        _log.d('skip $itemId[$oldIndex→$newIndex] fromOffset==toOffset=$fromOffset size unchanged=${oldLayoutParams.rect.size}');
        continue;
      }

      _ResetParamsCallback resetCallback = _ResetParamsCallback(
        notifer: notifier,
      );
      countCallback.doOnComplete(() => resetCallback.call(newIndex));

      notifier.value = ItemAnimatorParams(
        // 动画先行模式保持 oldIndex：数据未变更，widget 仍以旧 index 查找 notifier
        // 数据先行模式用 newIndex：数据已变更，rebuild 后 widget 以新 index 查找 notifier
        index: refreshAfterAnimation ? oldIndex : newIndex,
        springConfig: springConfig,
        curveConfig: curveConfig,
        offset: fromOffset,
        toOffset: toOffset,
        scale: 1.0,
        alpha: 1.0,
        onComplete: () {
          countCallback.call();
        },
        size: newLayoutParams.rect.size,
      );
      resetCallback.anchorParams = notifier.value;
    }

    _log.d(
      'prepareLayoutAnimations: add=$addIndexes remove=$removeIndexes animated=${countCallback._count} items',
    );
    if (countCallback._count == 0) {
      countCallback.call();
    }

    return countCallback;
  }

  /// 预测变更后 ScrollView 会调整到的新 scrollOffset
  double _resolveNewScrollOffset({
    required int newItemCount,
    required double currentScrollOffset,
    EdgeInsetsGeometry? padding,
    Size? itemSize,
    EdgeInsetsGeometry? edgeSpacing,
    Size? itemSpacing,
  }) {
    final viewportExtent = layoutManager.viewportMainAxisExtent;
    final newMaxScroll = layoutManager.getMaxScrollOffset(
      newItemCount,
      padding: padding,
      itemSize: itemSize,
      edgeSpacing: edgeSpacing,
      itemSpacing: itemSpacing,
    );

    final effectiveMax = newMaxScroll - viewportExtent;
    final newScrollOffset = currentScrollOffset.clamp(0.0, effectiveMax > 0 ? effectiveMax : 0.0);
    _log.d('resolveNewScrollOffset: current=$currentScrollOffset effectiveMax=${effectiveMax.toStringAsFixed(1)} → new=$newScrollOffset');
    return newScrollOffset;
  }

  @override
  void dispose() {
    for (final notifier in _params.values) {
      notifier.dispose();
    }
    _params.clear();
    super.dispose();
  }
}
