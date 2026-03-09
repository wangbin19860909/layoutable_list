import 'package:flutter/material.dart';
import '../../service_holder.dart';
import '../layoutable_list_widget.dart';
import 'item_animator_params.dart';

/// 列表适配器
///
/// 管理列表数据和动画协调，提供以下功能：
/// 1. 管理 item 列表的增删操作
/// 2. 在增删时自动计算布局变化并触发动画
/// 3. 为每个 item 维护动画参数
class ListAdapter<T> extends ChangeNotifier {
  final List<T> _items;
  final ServiceHolder<LayoutManager> _layoutManagerHolder;

  LayoutManager get layoutManager {
    final manager = _layoutManagerHolder.target;
    if (manager == null) {
      throw StateError('LayoutManager not attached yet');
    }
    return manager;
  }

  final int Function(T) idExtractor;
  final Duration animationDuration;

  /// 为每个 item 维护的动画参数
  final Map<int, ValueNotifier<ItemAnimatorParams>> _animatorParams = {};

  ListAdapter({
    required List<T> items,
    required ServiceHolder<LayoutManager> layoutManagerHolder,
    required this.idExtractor,
    this.animationDuration = const Duration(milliseconds: 400),
  }) : _layoutManagerHolder = layoutManagerHolder,
       _items = List.from(items) {
    _initializeParams();
  }

  /// 初始化所有 item 的动画参数
  void _initializeParams() {
    for (final item in _items) {
      final id = idExtractor(item);
      // 初始状态：所有 item 都在正确位置，无需动画
      _animatorParams[id] = ValueNotifier(
        ItemAnimatorParams(offset: ValueNotifier(Offset.zero)),
      );
    }
  }

  /// 获取当前的 item 列表（只读）
  List<T> get items => List.unmodifiable(_items);

  /// 监听指定 item 的动画参数
  ///
  /// 返回一个 ValueNotifier，ItemAnimator 可以监听它来响应参数变化
  ValueNotifier<ItemAnimatorParams> listenAnimatorParams(int id) {
    if (!_animatorParams.containsKey(id)) {
      throw StateError('AnimatorParams for id $id not found');
    }
    return _animatorParams[id]!;
  }

  /// 当 ItemAnimator 被卸载时调用
  ///
  /// 重置 params 为 zero，避免下次重新挂载时执行不必要的动画
  void onItemUnmounted(int id) {
    if (_animatorParams.containsKey(id)) {
      // 重置为 zero
      _animatorParams[id]!.value = ItemAnimatorParams(offset: ValueNotifier(Offset.zero));
    }
  }

  /// 添加 item 到指定位置
  void addItem(T item, {int index = 0}) {
    index = index.clamp(0, _items.length);
    final itemId = idExtractor(item);

    
    _animatorParams[itemId] = ValueNotifier(
      ItemAnimatorParams(offset: null),
    );
        
    // 2. 插入数据
    _items.insert(index, item);

    for (int i = 0; i < _items.length; i++) {
      final id = idExtractor(_items[i]);
      if (id == itemId) {
        continue; // 跳过新添加的 item
      }

      final notifier = _animatorParams[id]!;
      
      // 如果 item 从未被渲染过（没有监听器），设置为 zero 避免后续执行 add 动画
      if (!notifier.hasListeners) {
        notifier.value = ItemAnimatorParams(offset: ValueNotifier(Offset.zero));
        continue;
      }

      final currentParams = notifier.value;

      // 计算 item 在旧布局中的位置
      final oldIndex = i > index ? i - 1 : i;
      final oldLayoutParams = layoutManager.getLayoutParamsForPosition(
        index: oldIndex,
        itemCount: _items.length - 1,
      );

      // 计算 item 在新布局中的位置
      final newLayoutParams = layoutManager.getLayoutParamsForPosition(
        index: i,
        itemCount: _items.length,
      );

      // 计算布局位置差异
      final layoutDelta = Offset(
        oldLayoutParams.rect.left - newLayoutParams.rect.left,
        oldLayoutParams.rect.top - newLayoutParams.rect.top,
      );

      // 当前的视觉偏移
      final currentVisualOffset = currentParams.offset?.value ?? Offset.zero;
      // 新的 offset = 当前视觉偏移 + 布局差异
      final newOffset = currentVisualOffset + layoutDelta;

      // 更新 offset
      if (currentParams.offset != null) {
        currentParams.offset!.value = newOffset;
        // 创建新的 params 以触发动画（animationId 自动递增）
        notifier.value = ItemAnimatorParams(
          offset: currentParams.offset,
          size: newLayoutParams.rect.size,
        );
      } else {
        notifier.value = ItemAnimatorParams(
          offset: ValueNotifier(newOffset),
          size: newLayoutParams.rect.size,
        );
      }
    }

    notifyListeners();
  }

  /// 移除指定的 item
  ///
  /// 返回被删除的 item 是否需要执行删除动画（是否已被渲染）
  bool removeItem(T item) {
    final index = _items.indexOf(item);
    if (index != -1) {
      return removeAt(index);
    }
    return false;
  }

  /// 移除指定索引的 item
  ///
  /// 返回被删除的 item 是否需要执行删除动画（是否已被渲染）
  bool removeAt(int removingIndex) {
    if (removingIndex < 0 || removingIndex >= _items.length) {
      throw RangeError('Index $removingIndex out of range');
    }

    final removingItemId = idExtractor(_items[removingIndex]);
    final removingNotifier = _animatorParams[removingItemId]!;
    
    // 检查被删除的 item 是否已被渲染
    final shouldAnimateRemoval = removingNotifier.hasListeners;

    // 1. 计算其他 item 的新位置（在删除数据之前）
    for (int i = 0; i < _items.length; i++) {
      if (i == removingIndex) {
        continue; // 跳过被删除的 item
      }

      final itemId = idExtractor(_items[i]);
      final notifier = _animatorParams[itemId]!;
      
      // 如果 item 从未被渲染过（没有监听器），设置为 zero 避免后续执行 add 动画
      if (!notifier.hasListeners) {
        notifier.value = ItemAnimatorParams(offset: ValueNotifier(Offset.zero));
        continue;
      }

      final currentParams = notifier.value;

      // 计算 item 在旧布局中的位置
      final oldLayoutParams = layoutManager.getLayoutParamsForPosition(
        index: i,
        itemCount: _items.length,
        scrollOffset: 0.0, // 使用绝对位置，不受当前滚动位置影响
      );

      // 计算 item 在新布局中的位置（删除后）
      final newIndex = i > removingIndex ? i - 1 : i;
      final newLayoutParams = layoutManager.getLayoutParamsForPosition(
        index: newIndex,
        itemCount: _items.length - 1,
        scrollOffset: 0.0, // 使用绝对位置，不受当前滚动位置影响
      );

      // 计算布局位置差异
      final layoutDelta = Offset(
        oldLayoutParams.rect.left - newLayoutParams.rect.left,
        oldLayoutParams.rect.top - newLayoutParams.rect.top,
      );

      // 当前的视觉偏移
      final currentVisualOffset = currentParams.offset?.value ?? Offset.zero;

      // 新的 offset = 当前视觉偏移 + 布局差异
      final newOffset = currentVisualOffset + layoutDelta;

      // 更新 params
      if (currentParams.offset != null) {
        currentParams.offset!.value = newOffset;
        // 创建新的 params 以触发动画（animationId 自动递增）
        notifier.value = ItemAnimatorParams(
          offset: currentParams.offset,
          size: newLayoutParams.rect.size,
        );
      } else {
        notifier.value = ItemAnimatorParams(
          offset: ValueNotifier(newOffset),
          size: newLayoutParams.rect.size,
        );
      }
    }

    // 2. 删除数据
    _items.removeAt(removingIndex);

    // 3. 清理被删除 item 的 params
    _animatorParams.remove(removingItemId);

    // 4. 通知 UI 刷新
    notifyListeners();
    
    // 5. 返回是否需要执行删除动画
    return shouldAnimateRemoval;
  }

  @override
  void dispose() {
    // 释放所有 ValueNotifier 和 ItemAnimatorParams
    for (final notifier in _animatorParams.values) {
      notifier.value.dispose();
      notifier.dispose();
    }
    _animatorParams.clear();
    super.dispose();
  }
}
