import 'package:flutter/material.dart';
import 'logger.dart';

/// diff 结果，描述列表从旧状态到新状态的变更
///
/// - [addIndexes] 新增 item 在新列表中的 index
/// - [removeIndexes] 删除 item 在旧列表中的 index
/// - [moveIndexes] itemId → newIndex，位置有变化的 item（包含 move/swap）
class DiffResult {
  final List<int> addIndexes;
  final List<int> removeIndexes;
  final Map<String, int> moveIndexes;

  const DiffResult({
    this.addIndexes = const [],
    this.removeIndexes = const [],
    this.moveIndexes = const {},
  });
}

/// 列表适配器
///
/// 只负责管理列表数据的增删，动画由外部 ItemAnimatorController 驱动。
class ListAdapter<T> extends ChangeNotifier {
  static final _log = Logger('ListAdapter');
  final List<T> _items;
  final int Function(T) idExtractor;
  final Map<String, int> _idToIndexMap = {};

  ListAdapter({
    required List<T> items,
    required this.idExtractor,
  }) : _items = List.from(items) {
    _rebuildIndexMap();
  }

  void _rebuildIndexMap() {
    _idToIndexMap.clear();
    for (int i = 0; i < _items.length; i++) {
      _idToIndexMap[idExtractor(_items[i]).toString()] = i;
    }
  }

  int get itemCount => _items.length;

  int? findChildIndex(String itemId) => _idToIndexMap[itemId];

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

  void addItem(T item, {int index = 0}) {
    final clampedIndex = index.clamp(0, _items.length);
    _items.insert(clampedIndex, item);
    _rebuildIndexMap();
    _log.d('addItem at $clampedIndex, count=${_items.length}');
    notifyListeners();
  }

  bool removeItem(T item) {
    final index = _items.indexOf(item);
    if (index == -1) return false;
    return removeAt(index);
  }

  bool removeById(String itemId) {
    final index = findChildIndex(itemId);
    if (index == null) return false;
    return removeAt(index);
  }

  bool removeAt(int index) {
    if (index < 0 || index >= _items.length) {
      throw RangeError('Index $index out of range');
    }
    _items.removeAt(index);
    _rebuildIndexMap();
    _log.d('removeAt $index, count=${_items.length}');
    notifyListeners();
    return true;
  }

  /// 替换指定位置的 item，不触发 add/remove 动画
  void replaceAt(int index, T newItem) {
    if (index < 0 || index >= _items.length) {
      throw RangeError('Index $index out of range');
    }
    _items[index] = newItem;
    _rebuildIndexMap();
    _log.d('replaceAt $index, count=${_items.length}');
    notifyListeners();
  }

  /// 用新列表替换当前数据，触发一次 notifyListeners
  void applyDiff(List<T> newItems) {
    _items
      ..clear()
      ..addAll(newItems);
    _rebuildIndexMap();
    _log.d('applyDiff count=${_items.length}');
    notifyListeners();
  }

  /// 与新列表做 diff，返回 DiffResult
  ///
  /// 基于 id 匹配：
  /// - 旧列表有、新列表没有 → remove
  /// - 新列表有、旧列表没有 → add
  /// - 两者都有但 index 不同 → move（记入 moves）
  /// - index 相同 → 不变（不记入 moves）
  DiffResult diffItems(List<T> newItems) {
    final oldIdToIndex = <String, int>{};
    for (int i = 0; i < _items.length; i++) {
      oldIdToIndex[idExtractor(_items[i]).toString()] = i;
    }

    final newIdToIndex = <String, int>{};
    for (int i = 0; i < newItems.length; i++) {
      newIdToIndex[idExtractor(newItems[i]).toString()] = i;
    }

    final removeIndexes = <int>[];
    for (final entry in oldIdToIndex.entries) {
      if (!newIdToIndex.containsKey(entry.key)) {
        removeIndexes.add(entry.value);
      }
    }

    final addIndexes = <int>[];
    for (final entry in newIdToIndex.entries) {
      if (!oldIdToIndex.containsKey(entry.key)) {
        addIndexes.add(entry.value);
      }
    }

    final moves = <String, int>{};
    for (final entry in newIdToIndex.entries) {
      final oldIndex = oldIdToIndex[entry.key];
      if (oldIndex != null && oldIndex != entry.value) {
        moves[entry.key] = entry.value;
      }
    }

    return DiffResult(
      addIndexes: addIndexes..sort(),
      removeIndexes: removeIndexes..sort(),
      moveIndexes: moves,
    );
  }
}
