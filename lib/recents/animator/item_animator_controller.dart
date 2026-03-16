import 'package:flutter/material.dart';
import '../../service_holder.dart';
import '../../utils/logger.dart';
import '../layoutable_list_widget.dart';
import 'animation_widget.dart';
import 'item_animator.dart';
import 'list_adapter.dart';

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
    if (_count == 0) {
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
      print("_ResetParamsCallback call from ${notifer.value.index} to $index");
      notifer.value = anchorParams.copy(
        index: index,
        offset: Offset.zero,
        toOffset: Offset.zero,
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
    print('listenAnimatorParams: $itemId $index');
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
    print('onItemUnmounted: $itemId');
  }

  /// 设置单个 item 的动画参数，立即生效，无需 commit()。
  void performItemAnimation(
    String itemId,
    int index, {
    CurveConfig? curveConfig,
    double? offsetX,
    double? offsetY,
    double? scalle,
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
          alpha: 1.0,
          onComplete: onComplete
        ),
      );
    } else {
      if (notifier.value.index == index) {
        notifier.value = notifier.value.copy(
          curveConfig: curveConfig,
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
  AnimationInterrupter? performLayoutAnimations({
    required ListAdapter adapter,
    List<int> addIndexes = const [],
    List<int> removeIndexes = const [],
    EdgeInsetsGeometry? padding,
    Size? itemSize,
    double? scrollOffset,
    VoidCallback? onComplete,
    bool refreshAfterAnimation = false,
  }) {
    final oldItemCount = adapter.itemCount;
    final newItemCount =
        oldItemCount - removeIndexes.length + addIndexes.length;
    final currentScrollOffset = scrollOffset ?? layoutManager.scrollOffset;

    // 当 item 减少时，预测 ScrollView 会调整到的新 scrollOffset
    final newScrollOffset = _resolveNewScrollOffset(
      oldItemCount: oldItemCount,
      newItemCount: newItemCount,
      currentScrollOffset: currentScrollOffset,
    );

    // 构建 removeIndexes 的 Set，方便快速查找
    final removeIndexSet = removeIndexes.toSet();

    final _CountCallback countCallback = _CountCallback(onComplete: onComplete);

    for (final itemId in _params.keys) {
      final notifier = _params[itemId];
      if (notifier == null || !notifier.hasListeners) continue;

      final oldIndex = adapter.findChildIndex(itemId);
      if (oldIndex == -1) continue;

      if (removeIndexSet.contains(oldIndex)) continue;

      int newIndex = oldIndex;
      for (final ri in removeIndexes) {
        if (ri < oldIndex) newIndex--;
      }
      for (final ai in addIndexes) {
        if (ai <= newIndex) newIndex++;
      }

      print(
        "index=$oldIndex oldItemCount=$oldItemCount newItentCount=$newItemCount current=${layoutManager.itemCount}",
      );

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
        itemWidth: itemSize?.width,
        itemHeight: itemSize?.height,
      );

      final fromOffset =
          refreshAfterAnimation
              ? origLayoutParams.rect.topLeft +
                  notifier.value.offset -
                  oldLayoutParams.rect.topLeft
              : oldLayoutParams.rect.topLeft +
                  notifier.value.offset -
                  newLayoutParams.rect.topLeft;

      final toOffset =
          refreshAfterAnimation
              ? newLayoutParams.rect.topLeft - oldLayoutParams.rect.topLeft
              : Offset.zero;

      print(
        "index=$oldIndex itemId=$itemId origIndex=${notifier.value.index} fromOffset=${fromOffset} toOffset=${toOffset} notifier.value.offset=${notifier.value.offset} origLayoutParams.rect.topLeft=${origLayoutParams.rect.topLeft} oldLayoutParams.rect.topLeft=${oldLayoutParams.rect.topLeft}",
      );

      if (fromOffset == toOffset) {
        continue;
      }

      _ResetParamsCallback resetCallback = _ResetParamsCallback(
        notifer: notifier,
      );
      countCallback.doOnComplete(() => resetCallback.call(newIndex));

      notifier.value = ItemAnimatorParams(
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
      onComplete?.call();
    }

    return countCallback;
  }

  /// 当 item 减少时，预测 ScrollView 会调整到的新 scrollOffset
  double _resolveNewScrollOffset({
    required int oldItemCount,
    required int newItemCount,
    required double currentScrollOffset,
  }) {
    if (newItemCount >= oldItemCount) return currentScrollOffset;

    final viewportExtent = layoutManager.viewportMainAxisExtent;
    final oldMaxScroll = layoutManager.getMaxScrollOffset(oldItemCount);
    final newMaxScroll = layoutManager.getMaxScrollOffset(newItemCount);
    final isOverscrolling =
        currentScrollOffset < 0 ||
        currentScrollOffset > (oldMaxScroll - viewportExtent);

    return isOverscrolling
        ? currentScrollOffset
        : currentScrollOffset.clamp(0.0, newMaxScroll - viewportExtent);
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
