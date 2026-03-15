import 'package:flutter/material.dart';
import '../../service_holder.dart';
import '../../utils/logger.dart';
import '../layoutable_list_widget.dart';
import 'animation_widget.dart';
import 'item_animator.dart';
import 'list_adapter.dart';

/// Item 动画控制器
///
/// 管理所有 item 的动画参数，提供自由的动画控制能力。
/// 支持 add/remove/padding 等变更的补位动画，可在同一帧内合并。
///
/// 使用流程：
/// 1. prepareLayoutAnimations() / prepareItemAnimation() — 在数据变更前调用，计算补位动画参数
/// 2. 执行数据变更（add/remove/改 padding 等）
/// 3. commit() — 触发 UI 刷新
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
  ValueNotifier<ItemAnimatorParams> listenAnimatorParams(String itemId) {
    return _params.putIfAbsent(itemId, () => _createDefaultNotifier());
  }

  /// item 被卸载时重置，避免重新挂载时执行残留动画
  void onItemUnmounted(String itemId) {
    if (_params.containsKey(itemId)) {
      _log.d('onItemUnmounted: $itemId');
      _params[itemId] = _createDefaultNotifier();
    }
  }

  /// 触发 UI 刷新
  void commit() {
    _log.d('commit');
    notifyListeners();
  }

  /// 设置单个 item 的动画参数，立即生效，无需 commit()。
  void performItemAnimation(String itemId, ItemAnimatorParams params) {
    _log.d('performItemAnimation: $itemId offset=${params.offset}');
    listenAnimatorParams(itemId).value = params;
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
  void prepareLayoutAnimations({
    required ListAdapter adapter,
    List<int> addIndexes = const [],
    List<int> removeIndexes = const [],
    EdgeInsetsGeometry? padding,
    Size? itemSize,
    double? scrollOffset,
  }) {
    final oldItemCount = adapter.itemCount;
    final newItemCount = oldItemCount - removeIndexes.length + addIndexes.length;
    final currentScrollOffset = scrollOffset ?? layoutManager.scrollOffset;

    // 当 item 减少时，预测 ScrollView 会调整到的新 scrollOffset
    final newScrollOffset = _resolveNewScrollOffset(
      oldItemCount: oldItemCount,
      newItemCount: newItemCount,
      currentScrollOffset: currentScrollOffset,
    );

    // 构建 removeIndexes 的 Set，方便快速查找
    final removeIndexSet = removeIndexes.toSet();

    int animatedCount = 0;
    for (final itemId in _params.keys) {
      final notifier = _params[itemId];
      if (notifier == null || !notifier.hasListeners) continue;

      // 变更前的旧 index
      final oldIndex = adapter.findChildIndex(itemId);
      if (oldIndex == null) continue;

      // 该 item 被删除，不参与补位
      if (removeIndexSet.contains(oldIndex)) continue;

      // 推算变更后的新 index：
      // - 每个 removeIndex < oldIndex 的删除，新 index -1
      // - 每个 addIndex <= 新 index 的插入，新 index +1
      int newIndex = oldIndex;
      for (final ri in removeIndexes) {
        if (ri < oldIndex) newIndex--;
      }
      for (final ai in addIndexes) {
        if (ai <= newIndex) newIndex++;
      }

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

      // 旧绝对位置 = 旧布局位置 + 当前视觉偏移
      final currentVisualOffset = notifier.value.offset;
      final oldAbsolutePos = oldLayoutParams.rect.topLeft + currentVisualOffset;
      final offset = oldAbsolutePos - newLayoutParams.rect.topLeft;

      if (offset.distance < 0.5) continue;

      animatedCount++;
      notifier.value = ItemAnimatorParams(
        springConfig: springConfig,
        curveConfig: curveConfig,
        offset: offset,
        toOffset: Offset.zero,
        scale: 1.0,
        alpha: 1.0,
        size: newLayoutParams.rect.size,
      );
    }
    _log.d('prepareLayoutAnimations: add=$addIndexes remove=$removeIndexes animated=$animatedCount items');
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
    final isOverscrolling = currentScrollOffset < 0 ||
        currentScrollOffset > (oldMaxScroll - viewportExtent);

    return isOverscrolling
        ? currentScrollOffset
        : currentScrollOffset.clamp(0.0, newMaxScroll - viewportExtent);
  }

  ValueNotifier<ItemAnimatorParams> _createDefaultNotifier() {
    return ValueNotifier(
      ItemAnimatorParams(
        offset: Offset.zero,
        toOffset: Offset.zero,
        scale: 1.0,
        alpha: 1.0,
      ),
    );
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
