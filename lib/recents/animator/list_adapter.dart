import 'package:flutter/material.dart';
import '../../service_holder.dart';
import '../layoutable_list_widget.dart';
import 'animation_widget.dart';
import 'item_animator.dart';

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
  final SpringConfig? springConfig;

  final Map<String, ValueNotifier<ItemAnimatorParams>> _animatorParams = {};
  final Map<String, int> _idToIndexMap = {};

  ListAdapter({
    required List<T> items,
    required ServiceHolder<LayoutManager> layoutManagerHolder,
    required this.idExtractor,
    this.animationDuration = const Duration(milliseconds: 400),
    this.springConfig,
  }) : _layoutManagerHolder = layoutManagerHolder,
       _items = List.from(items) {
    _initializeParams();
    _rebuildIndexMap();
  }

  void _rebuildIndexMap() {
    _idToIndexMap.clear();
    for (int i = 0; i < _items.length; i++) {
      final id = idExtractor(_items[i]);
      _idToIndexMap[id.toString()] = i;
    }
  }

  int? findChildIndex(String itemId) {
    return _idToIndexMap[itemId];
  }
  
  String getItemId(int index) {
    if (index < 0 || index >= _items.length) {
      throw RangeError('Index $index out of range');
    }
    return idExtractor(_items[index]).toString();
  }
  
  T getItem(int index) {
    if (index < 0 || index >= _items.length) {
      throw RangeError('Index $index out of range');
    }
    return _items[index];
  }

  void _initializeParams() {
    for (final item in _items) {
      final id = idExtractor(item).toString();
      _animatorParams[id] = ValueNotifier(
        ItemAnimatorParams(
          offset: Offset.zero,
          toOffset: Offset.zero,
          scale: 1.0,
          alpha: 1.0,
        ),
      );
    }
  }

  List<T> get items => List.unmodifiable(_items);

  ValueNotifier<ItemAnimatorParams> listenAnimatorParams(String id) {
    if (!_animatorParams.containsKey(id)) {
      throw StateError('AnimatorParams for id $id not found');
    }
    return _animatorParams[id]!;
  }

  void onItemUnmounted(String id) {
    if (_animatorParams.containsKey(id)) {
      _animatorParams[id] = ValueNotifier(
        ItemAnimatorParams(
          offset: Offset.zero,
          toOffset: Offset.zero,
          scale: 1.0,
          alpha: 1.0,
        ),
      );
    }
  }

  void addItem(T item, {int index = 0}) {
    index = index.clamp(0, _items.length);
    final itemId = idExtractor(item).toString();
    
    // 新 item：offset = toOffset = Offset.zero，不执行动画
    _animatorParams[itemId] = ValueNotifier(
      ItemAnimatorParams(
        offset: Offset.zero,
        toOffset: Offset.zero,
        scale: 1.0,
        alpha: 1.0,
      ),
    );
        
    _items.insert(index, item);

    for (int i = 0; i < _items.length; i++) {
      final id = idExtractor(_items[i]).toString();
      if (id == itemId) continue;

      final notifier = _animatorParams[id]!;
      
      if (!notifier.hasListeners) {
        notifier.value = ItemAnimatorParams(
          offset: Offset.zero,
          toOffset: Offset.zero,
          scale: 1.0,
          alpha: 1.0,
        );
        continue;
      }

      final currentParams = notifier.value;

      final oldIndex = i > index ? i - 1 : i;
      final oldLayoutParams = layoutManager.getLayoutParamsForPosition(
        index: oldIndex,
        itemCount: _items.length - 1,
      );

      final newLayoutParams = layoutManager.getLayoutParamsForPosition(
        index: i,
        itemCount: _items.length,
      );

      final layoutDelta = Offset(
        oldLayoutParams.rect.left - newLayoutParams.rect.left,
        oldLayoutParams.rect.top - newLayoutParams.rect.top,
      );

      final currentVisualOffset = currentParams.offset;
      final newOffset = currentVisualOffset + layoutDelta;

      notifier.value = ItemAnimatorParams(
        springConfig: springConfig,
        offset: newOffset,
        toOffset: Offset.zero,
        scale: 1.0,
        alpha: 1.0,
        size: newLayoutParams.rect.size,
      );
    }

    notifyListeners();
    _rebuildIndexMap();
  }

  bool removeItem(T item) {
    final index = _items.indexOf(item);
    if (index != -1) {
      return removeAt(index);
    }
    return false;
  }

  bool removeAt(int removingIndex) {
    if (removingIndex < 0 || removingIndex >= _items.length) {
      throw RangeError('Index $removingIndex out of range');
    }

    final removingItemId = idExtractor(_items[removingIndex]).toString();
    final removingNotifier = _animatorParams[removingItemId]!;
    final shouldAnimateRemoval = removingNotifier.hasListeners;

    final currentScrollOffset = layoutManager.scrollOffset;
    final viewportExtent = layoutManager.viewportMainAxisExtent;
    final oldMaxScrollOffset = layoutManager.getMaxScrollOffset(_items.length);
    final newMaxScrollOffset = layoutManager.getMaxScrollOffset(_items.length - 1);
    final isOverscrolling = currentScrollOffset < 0 ||
        currentScrollOffset > (oldMaxScrollOffset - viewportExtent);
    final newScrollOffset = isOverscrolling
        ? currentScrollOffset
        : currentScrollOffset.clamp(0.0, newMaxScrollOffset - viewportExtent);

    for (int i = 0; i < _items.length; i++) {
      if (i == removingIndex) continue;

      final itemId = idExtractor(_items[i]).toString();
      final notifier = _animatorParams[itemId]!;
      
      if (!notifier.hasListeners) {
        notifier.value = ItemAnimatorParams(
          offset: Offset.zero,
          toOffset: Offset.zero,
          scale: 1.0,
          alpha: 1.0,
        );
        continue;
      }

      final currentParams = notifier.value;

      final oldLayoutParams = layoutManager.getLayoutParamsForPosition(
        index: i,
        itemCount: _items.length,
        scrollOffset: currentScrollOffset,
      );

      final newIndex = i > removingIndex ? i - 1 : i;
      final newLayoutParams = layoutManager.getLayoutParamsForPosition(
        index: newIndex,
        itemCount: _items.length - 1,
        scrollOffset: newScrollOffset,
      );

      final layoutDelta = Offset(
        oldLayoutParams.rect.left - newLayoutParams.rect.left,
        oldLayoutParams.rect.top - newLayoutParams.rect.top,
      );

      final currentVisualOffset = currentParams.offset;
      final newOffset = currentVisualOffset + layoutDelta;

      notifier.value = ItemAnimatorParams(
        springConfig: springConfig,
        offset: newOffset,
        toOffset: Offset.zero,
        scale: 1.0,
        alpha: 1.0,
        size: newLayoutParams.rect.size,
      );
    }

    _items.removeAt(removingIndex);
    _animatorParams.remove(removingItemId);
    notifyListeners();
    _rebuildIndexMap();
    return shouldAnimateRemoval;
  }

  @override
  void dispose() {
    for (final notifier in _animatorParams.values) {
      notifier.dispose();
    }
    _animatorParams.clear();
    super.dispose();
  }
}
