import 'package:flutter/material.dart';
import 'service_holder.dart';
import 'layoutablelist/layoutable_list_widget.dart';
import 'layoutablelist/algorithms/grid_layout_algorithm.dart';
import 'layoutablelist/list_adapter.dart';
import 'layoutablelist/animator/item_animator.dart';
import 'layoutablelist/animator/item_animator_controller.dart';
import 'layoutablelist/animator/animation_widget.dart';

class LayoutAnimationDemo extends StatefulWidget {
  const LayoutAnimationDemo({super.key});

  @override
  State<LayoutAnimationDemo> createState() => _LayoutAnimationDemoState();
}

class _LayoutAnimationDemoState extends State<LayoutAnimationDemo> {
  final _layoutManagerHolder = ServiceHolder<LayoutManager>();
  late ListAdapter<_Item> _adapter;
  late ItemAnimatorController _animatorController;
  int _nextId = 10;

  static const _itemSize = Size(80, 80);
  static const _colors = [
    Colors.red, Colors.orange, Colors.amber, Colors.green,
    Colors.teal, Colors.blue, Colors.indigo, Colors.purple,
    Colors.pink, Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    _adapter = ListAdapter<_Item>(
      items: List.generate(5, (i) => _Item(id: i, label: '$i')),
      idExtractor: (item) => item.id,
    );
    _animatorController = ItemAnimatorController(
      layoutManagerHolder: _layoutManagerHolder,
      curveConfig: const CurveConfig(curve: Curves.easeInOut, durationMs: 400),
    );
    _adapter.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _adapter.dispose();
    _animatorController.dispose();
    super.dispose();
  }

  // ── 操作方法 ──────────────────────────────────────────

  void _addFirst() {
    final item = _Item(id: _nextId++, label: '${_nextId - 1}');
    _animatorController.performLayoutAnimations(adapter: _adapter, addIndexes: [0]);
    _adapter.addItem(item, index: 0);
  }

  void _addMiddle() {
    if (_adapter.itemCount == 0) return;
    final mid = _adapter.itemCount ~/ 2;
    final item = _Item(id: _nextId++, label: '${_nextId - 1}');
    _animatorController.performLayoutAnimations(adapter: _adapter, addIndexes: [mid]);
    _adapter.addItem(item, index: mid);
  }

  void _addLast() {
    final item = _Item(id: _nextId++, label: '${_nextId - 1}');
    final idx = _adapter.itemCount;
    _animatorController.performLayoutAnimations(adapter: _adapter, addIndexes: [idx]);
    _adapter.addItem(item, index: idx);
  }

  void _removeFirst() {
    if (_adapter.itemCount == 0) return;
    _animatorController.performLayoutAnimations(adapter: _adapter, removeIndexes: [0]);
    _adapter.removeAt(0);
  }

  void _removeMiddle() {
    if (_adapter.itemCount < 2) return;
    final mid = _adapter.itemCount ~/ 2;
    _animatorController.performLayoutAnimations(adapter: _adapter, removeIndexes: [mid]);
    _adapter.removeAt(mid);
  }

  void _removeLast() {
    if (_adapter.itemCount == 0) return;
    final last = _adapter.itemCount - 1;
    _animatorController.performLayoutAnimations(adapter: _adapter, removeIndexes: [last]);
    _adapter.removeAt(last);
  }

  void _moveFirstToLast() {
    if (_adapter.itemCount < 2) return;
    final newItems = [...List.generate(_adapter.itemCount, _adapter.getItem)];
    final moved = newItems.removeAt(0);
    newItems.add(moved);
    final diff = _adapter.diffItems(newItems);
    _animatorController.performLayoutAnimations(
      adapter: _adapter,
      addIndexes: diff.addIndexes,
      removeIndexes: diff.removeIndexes,
      moveIndexes: diff.moveIndexes,
    );
    _adapter.applyDiff(newItems);
  }

  void _moveLastToFirst() {
    if (_adapter.itemCount < 2) return;
    final newItems = [...List.generate(_adapter.itemCount, _adapter.getItem)];
    final moved = newItems.removeLast();
    newItems.insert(0, moved);
    final diff = _adapter.diffItems(newItems);
    _animatorController.performLayoutAnimations(
      adapter: _adapter,
      addIndexes: diff.addIndexes,
      removeIndexes: diff.removeIndexes,
      moveIndexes: diff.moveIndexes,
    );
    _adapter.applyDiff(newItems);
  }

  void _swapFirstLast() {
    if (_adapter.itemCount < 2) return;
    final newItems = [...List.generate(_adapter.itemCount, _adapter.getItem)];
    final tmp = newItems[0];
    newItems[0] = newItems[newItems.length - 1];
    newItems[newItems.length - 1] = tmp;
    final diff = _adapter.diffItems(newItems);
    _animatorController.performLayoutAnimations(
      adapter: _adapter,
      addIndexes: diff.addIndexes,
      removeIndexes: diff.removeIndexes,
      moveIndexes: diff.moveIndexes,
    );
    _adapter.applyDiff(newItems);
  }

  void _reverse() {
    if (_adapter.itemCount < 2) return;
    final newItems = List.generate(_adapter.itemCount, _adapter.getItem).reversed.toList();
    final diff = _adapter.diffItems(newItems);
    _animatorController.performLayoutAnimations(
      adapter: _adapter,
      addIndexes: diff.addIndexes,
      removeIndexes: diff.removeIndexes,
      moveIndexes: diff.moveIndexes,
    );
    _adapter.applyDiff(newItems);
  }

  void _addAndRemove() {
    if (_adapter.itemCount == 0) return;
    final item = _Item(id: _nextId++, label: '${_nextId - 1}');
    _animatorController.performLayoutAnimations(
      adapter: _adapter,
      addIndexes: [0],
      removeIndexes: [_adapter.itemCount - 1],
    );
    _adapter.removeAt(_adapter.itemCount - 1);
    _adapter.addItem(item, index: 0);
  }

  // ── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('补位动画 Demo (${_adapter.itemCount} items)'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          _buildList(),
          const Divider(height: 1),
          Expanded(child: _buildControls()),
        ],
      ),
    );
  }

  Widget _buildList() {
    return SizedBox(
      height: 120,
      child: LayoutableListWidget(
        itemSize: _itemSize,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        layoutManagerHolder: _layoutManagerHolder,
        edgeSpacing: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        itemSpacing: const Size(8, 0),
        layoutAlgorithm: GridLayoutAlgorithm(
          scrollDirection: Axis.horizontal,
          spanCount: 1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = _adapter.getItem(index);
            final itemId = _adapter.getItemId(index);
            return KeyedSubtree(
              key: ValueKey(itemId),
              child: ItemAnimator(
                key: ValueKey('anim_$itemId'),
                itemId: itemId,
                paramsNotifier: _animatorController.listenAnimatorParams(itemId, index),
                layoutParamsListenable: _layoutManagerHolder.target!.listenLayoutParamsForPosition(index),
                onDispose: _animatorController.onItemUnmounted,
                child: _buildItem(item, index),
              ),
            );
          },
          childCount: _adapter.itemCount,
          findChildIndexCallback: (key) {
            final id = (key as ValueKey<String>).value;
            return _adapter.findChildIndex(id);
          },
        ),
      ),
    );
  }

  Widget _buildItem(_Item item, int index) {
    final color = _colors[item.id % _colors.length];
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item.label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text('[$index]', style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section('Add', [
            _btn('头部插入', Colors.green, _addFirst),
            _btn('中间插入', Colors.green.shade700, _addMiddle),
            _btn('尾部插入', Colors.green.shade900, _addLast),
          ]),
          _section('Remove', [
            _btn('删除头部', Colors.red, _removeFirst),
            _btn('删除中间', Colors.red.shade700, _removeMiddle),
            _btn('删除尾部', Colors.red.shade900, _removeLast),
          ]),
          _section('Move', [
            _btn('首→尾', Colors.blue, _moveFirstToLast),
            _btn('尾→首', Colors.blue.shade700, _moveLastToFirst),
          ]),
          _section('Swap / Reverse', [
            _btn('首尾交换', Colors.purple, _swapFirstLast),
            _btn('全部反转', Colors.purple.shade700, _reverse),
          ]),
          _section('Combined', [
            _btn('头插+尾删', Colors.orange, _addAndRemove),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> buttons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: buttons),
      ],
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _Item {
  final int id;
  final String label;
  const _Item({required this.id, required this.label});
}
