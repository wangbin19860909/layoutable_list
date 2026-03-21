import 'package:flutter/material.dart';
import 'layoutablelist/drag/drag_manager.dart';
import 'layoutablelist/drag/drop_target.dart';
import 'layoutablelist/drag/item_draggable.dart';

const double _itemHeight = 56;
const double _itemSpacing = 8;
const double _listPadding = 12;
// 每个 item 占用的总高度（含间距）
const double _itemStride = _itemHeight + _itemSpacing;

class DragDemo extends StatefulWidget {
  const DragDemo({super.key});

  @override
  State<DragDemo> createState() => _DragDemoState();
}

class _DragDemoState extends State<DragDemo> {
  final _dragManager = DragManager<_Item>();

  final _leftItems = <_Item>[
    _Item(id: 1, label: 'A', color: Colors.red),
    _Item(id: 2, label: 'B', color: Colors.orange),
    _Item(id: 3, label: 'C', color: Colors.amber),
    _Item(id: 4, label: 'D', color: Colors.green),
  ];

  final _rightItems = <_Item>[
    _Item(id: 5, label: 'E', color: Colors.teal),
    _Item(id: 6, label: 'F', color: Colors.blue),
    _Item(id: 7, label: 'G', color: Colors.indigo),
  ];

  final _leftBounds = ValueNotifier<Rect>(Rect.zero);
  final _rightBounds = ValueNotifier<Rect>(Rect.zero);

  final _leftKey = GlobalKey();
  final _rightKey = GlobalKey();

  // item GlobalKey 映射，用于定位目标位置
  final _leftItemKeys = <int, GlobalKey>{};
  final _rightItemKeys = <int, GlobalKey>{};

  String _log = '长按 item 开始拖拽';

  // 待插入的预览 index（hover 时高亮）
  int? _leftInsertIndex;
  int? _rightInsertIndex;

  @override
  void dispose() {
    _dragManager.dispose();
    _leftBounds.dispose();
    _rightBounds.dispose();
    super.dispose();
  }

  void _updateBounds() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _leftBounds.value = _getGlobalRect(_leftKey);
      _rightBounds.value = _getGlobalRect(_rightKey);
    });
  }

  Rect _getGlobalRect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Rect.zero;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  void initState() {
    super.initState();
    _updateBounds();
  }

  /// 根据 localOffset.dy 计算插入 index
  int _calcInsertIndex(Offset localOffset, int itemCount) {
    final dy = localOffset.dy - _listPadding;
    final index = (dy / _itemStride).round().clamp(0, itemCount);
    return index;
  }

  Offset _calcTargetPosition(
    int insertIndex,
    List<_Item> items,
    Map<int, GlobalKey> keys,
    Rect listBounds,
  ) {
    final clampedIndex = insertIndex.clamp(0, items.length);

    // 优先用 GlobalKey 精确定位
    // 插入到中间/头部：取该位置现有 item
    // 插入到末尾：取最后一个 item，再加一个 stride
    final keyIndex = clampedIndex < items.length ? clampedIndex : items.length - 1;
    final offset = clampedIndex < items.length ? 0.0 : _itemStride;

    if (keyIndex >= 0 && keyIndex < items.length) {
      final key = keys[items[keyIndex].id];
      if (key != null) {
        final box = key.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          final topLeft = box.localToGlobal(Offset.zero);
          final center = topLeft + Offset(box.size.width / 2, box.size.height / 2 + offset);
          debugPrint('[DragDemo] targetIndex=$clampedIndex keyIndex=$keyIndex topLeft=$topLeft size=${box.size} center=$center offset=$offset');
          return center;
        }
      }
    }

    // 最终 fallback（列表为空时）
    final top = listBounds.top + _listPadding + _itemHeight / 2;
    final fallback = Offset(listBounds.center.dx, top);
    debugPrint('[DragDemo] fallback targetIndex=$clampedIndex fallback=$fallback');
    return fallback;
  }

  // ── Drop 处理 ──────────────────────────────────────────

  DropResult _onDropToLeft(_Item data, Offset localOffset) {
    final insertIndex = _calcInsertIndex(localOffset, _leftItems.length);
    final target = _calcTargetPosition(insertIndex, _leftItems, _leftItemKeys, _leftBounds.value);
    return DropResult.accept(target);
  }

  void _onDropCompletedLeft(_Item data) {
    setState(() {
      _leftInsertIndex = null;
      _rightInsertIndex = null;
      _rightItems.removeWhere((e) => e.id == data.id);
      if (!_leftItems.any((e) => e.id == data.id)) {
        _leftItems.add(data);
      }
      _log = '✅ ${data.label} 移入左侧列表';
    });
  }

  DropResult _onDropToRight(_Item data, Offset localOffset) {
    if (_rightItems.length >= 3 && !_rightItems.any((e) => e.id == data.id)) {
      _log = '❌ 右侧列表已满，拒绝 drop';
      setState(() {});
      return const DropResult.reject();
    }
    final insertIndex = _calcInsertIndex(localOffset, _rightItems.length);
    final target = _calcTargetPosition(insertIndex, _rightItems, _rightItemKeys, _rightBounds.value);
    return DropResult.accept(target);
  }

  void _onDropCompletedRight(_Item data) {
    setState(() {
      _leftInsertIndex = null;
      _rightInsertIndex = null;
      _leftItems.removeWhere((e) => e.id == data.id);
      if (!_rightItems.any((e) => e.id == data.id)) {
        _rightItems.add(data);
      }
      _log = '✅ ${data.label} 移入右侧列表';
    });
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _updateBounds();
    return Scaffold(
      appBar: AppBar(
        title: const Text('拖拽 Demo'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.deepPurple.shade50,
            child: Text(_log, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: DropTarget<_Item>(
                    dragManager: _dragManager,
                    boundsListenable: _leftBounds,
                    onEnter: (data) => setState(() => _log = '👉 ${data.label} 进入左侧'),
                    onMove: (data, offset) {
                      final idx = _calcInsertIndex(offset, _leftItems.length);
                      if (_leftInsertIndex != idx) setState(() => _leftInsertIndex = idx);
                    },
                    onExit: (data) => setState(() {
                      _leftInsertIndex = null;
                      _log = '👈 ${data.label} 离开左侧';
                    }),
                    onDrop: _onDropToLeft,
                    onDropBack: (data) => setState(() {
                      _leftInsertIndex = null;
                      _rightInsertIndex = null;
                      _log = '↩️ ${data.label} 飞回左侧';
                    }),
                    onDropCompleted: _onDropCompletedLeft,
                    child: _buildList(
                      key: _leftKey,
                      title: '列表 A',
                      color: Colors.deepPurple,
                      items: _leftItems,
                      itemKeys: _leftItemKeys,
                      insertIndex: _leftInsertIndex,
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: DropTarget<_Item>(
                    dragManager: _dragManager,
                    boundsListenable: _rightBounds,
                    onEnter: (data) => setState(() => _log = '👉 ${data.label} 进入右侧'),
                    onMove: (data, offset) {
                      final idx = _calcInsertIndex(offset, _rightItems.length);
                      if (_rightInsertIndex != idx) setState(() => _rightInsertIndex = idx);
                    },
                    onExit: (data) => setState(() {
                      _rightInsertIndex = null;
                      _log = '👈 ${data.label} 离开右侧';
                    }),
                    onDrop: _onDropToRight,
                    onDropBack: (data) => setState(() {
                      _leftInsertIndex = null;
                      _rightInsertIndex = null;
                      _log = '↩️ ${data.label} 飞回右侧';
                    }),
                    onDropCompleted: _onDropCompletedRight,
                    child: _buildList(
                      key: _rightKey,
                      title: '列表 B（最多 3 个）',
                      color: Colors.teal,
                      items: _rightItems,
                      itemKeys: _rightItemKeys,
                      insertIndex: _rightInsertIndex,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList({
    required GlobalKey key,
    required String title,
    required Color color,
    required List<_Item> items,
    required Map<int, GlobalKey> itemKeys,
    int? insertIndex,
  }) {
    return Container(
      key: key,
      color: color.withValues(alpha: 0.05),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: color.withValues(alpha: 0.15),
            child: Text(
              '$title (${items.length})',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ),
          Expanded(
            child: items.isEmpty && insertIndex == null
                ? Center(child: Text('空', style: TextStyle(color: Colors.grey.shade400)))
                : ListView.builder(
                    padding: const EdgeInsets.all(_listPadding),
                    itemCount: items.length + (insertIndex != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      // 插入预览占位
                      if (insertIndex != null && index == insertIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: _itemSpacing),
                          child: Container(
                            height: _itemHeight,
                            decoration: BoxDecoration(
                              border: Border.all(color: color, width: 2),
                              borderRadius: BorderRadius.circular(10),
                              color: color.withValues(alpha: 0.08),
                            ),
                          ),
                        );
                      }
                      // 实际 item index（跳过占位）
                      final itemIndex = insertIndex != null && index > insertIndex ? index - 1 : index;
                      final item = items[itemIndex];
                      itemKeys.putIfAbsent(item.id, () => GlobalKey());
                      final itemKey = itemKeys[item.id]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: _itemSpacing),
                        child: ItemDraggable<_Item>(
                          dragManager: _dragManager,
                          data: item,
                          shadowBuilder: (data) => _buildItemCard(data, dragging: true),
                          shadowSize: const Size(double.infinity, _itemHeight),
                          child: _buildItemCard(item, itemKey: itemKey),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(_Item item, {bool dragging = false, GlobalKey? itemKey}) {
    return Material(
      key: itemKey,
      elevation: dragging ? 8 : 2,
      borderRadius: BorderRadius.circular(10),
      color: item.color,
      child: Container(
        height: _itemHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(Icons.drag_handle, color: Colors.white.withValues(alpha: 0.7), size: 20),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (dragging) ...[
              const Spacer(),
              const Icon(Icons.open_with, color: Colors.white, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _Item {
  final int id;
  final String label;
  final Color color;
  const _Item({required this.id, required this.label, required this.color});
}
