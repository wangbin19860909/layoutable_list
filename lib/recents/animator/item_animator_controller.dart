import 'package:flutter/material.dart';
import '../layoutable_list_widget.dart';
import 'animation_widget.dart';
import 'item_animator.dart';
import 'list_adapter.dart';

/// Item 动画控制器
///
/// 管理所有 item 的动画参数，提供自由的动画控制能力。
/// 支持 add/remove/padding 等变更的补位动画，可在同一帧内合并。
///
/// 使用流程（手动）：
/// 1. snapshotLayout() — 记录当前每个 item 的屏幕绝对位置
/// 2. 执行数据变更（add/remove/改 padding 等）
/// 3. commitLayout() — 根据快照和新布局计算偏移，触发动画
///
/// 或者直接使用 requestLayoutAnimations() 一步完成。
class ItemAnimatorController extends ChangeNotifier {
  final LayoutManager layoutManager;
  final SpringConfig? springConfig;
  final CurveConfig? curveConfig;

  final Map<String, ValueNotifier<ItemAnimatorParams>> _params = {};

  /// 布局快照：itemId → 屏幕绝对位置
  Map<String, Offset>? _layoutSnapshot;

  ItemAnimatorController({
    required this.layoutManager,
    this.springConfig,
    this.curveConfig,
  });

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
      _params[itemId] = _createDefaultNotifier();
    }
  }

  /// 记录当前所有 item 的屏幕绝对位置快照
  ///
  /// 在执行数据变更（add/remove/改 padding）之前调用。
  /// 绝对位置 = 布局位置 + 当前视觉偏移
  ///
  /// [itemIds] - 当前 item id 列表（按 index 顺序）
  /// [scrollOffset] - 可选，指定滚动偏移（默认用当前值）
  void snapshotLayout({
    required List<String> itemIds,
    double? scrollOffset,
  }) {
    _layoutSnapshot = {};
    for (int i = 0; i < itemIds.length; i++) {
      final itemId = itemIds[i];
      final layoutParams = layoutManager.getLayoutParamsForPosition(
        index: i,
        itemCount: itemIds.length,
        scrollOffset: scrollOffset,
      );
      final currentOffset = _params[itemId]?.value.offset ?? Offset.zero;
      _layoutSnapshot![itemId] = layoutParams.rect.topLeft + currentOffset;
    }
  }

  /// 根据快照和新布局计算补位偏移，触发动画
  ///
  /// 在数据变更完成后调用。
  ///
  /// [itemIds] - 变更后的 item id 列表（按 index 顺序）
  /// [excludeIds] - 不参与补位动画的 item（如新添加的）
  /// [scrollOffset] - 可选，指定滚动偏移（默认用当前值）
  /// [padding] - 可选，变更后的 padding
  void commitLayout({
    required List<String> itemIds,
    Set<String> excludeIds = const {},
    double? scrollOffset,
    EdgeInsetsGeometry? padding,
  }) {
    final snapshot = _layoutSnapshot;
    _layoutSnapshot = null;

    for (int i = 0; i < itemIds.length; i++) {
      final itemId = itemIds[i];
      if (excludeIds.contains(itemId)) continue;

      final newLayoutParams = layoutManager.getLayoutParamsForPosition(
        index: i,
        itemCount: itemIds.length,
        scrollOffset: scrollOffset,
        padding: padding,
      );

      final oldAbsolutePos = snapshot?[itemId];
      if (oldAbsolutePos == null) continue;

      final offset = oldAbsolutePos - newLayoutParams.rect.topLeft;
      if (offset.distance < 0.5) continue;

      final notifier = listenAnimatorParams(itemId);
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
  }

  /// 根据 add/remove 变更计算并触发补位动画
  ///
  /// 在数据变更之前调用，传入变更前的 adapter 状态。
  /// 内部自动推算每个 item 的旧/新 index，并处理 remove 时的 scrollOffset 预测。
  ///
  /// [adapter] - 变更前的 adapter
  /// [addIndexes] - 本次新增的插入位置（变更后的 index，升序）
  /// [removeIndexes] - 本次删除的位置（变更前的 index，升序）
  /// [padding] - 可选，变更后的 padding
  /// [scrollOffset] - 可选，覆盖当前 scrollOffset
  void requestLayoutAnimations({
    required ListAdapter adapter,
    List<int> addIndexes = const [],
    List<int> removeIndexes = const [],
    EdgeInsetsGeometry? padding,
    double? scrollOffset,
  }) {
    final oldItemCount = adapter.items.length;
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
      );

      // 旧绝对位置 = 旧布局位置 + 当前视觉偏移
      final currentVisualOffset = notifier.value.offset;
      final oldAbsolutePos = oldLayoutParams.rect.topLeft + currentVisualOffset;
      final offset = oldAbsolutePos - newLayoutParams.rect.topLeft;

      if (offset.distance < 0.5) continue;

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
