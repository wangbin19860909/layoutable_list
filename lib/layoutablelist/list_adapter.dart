import 'package:flutter/material.dart';
import 'logger.dart';

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
}
