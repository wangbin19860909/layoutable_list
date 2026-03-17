import 'package:flutter/material.dart';
import 'service_holder.dart';
import 'recents/layoutable_list_widget.dart';
import 'recents/algorithms/flex_layout_algorithm.dart';
import 'recents/animator/list_adapter.dart';
import 'recents/animator/item_animator.dart';
import 'recents/animator/item_animator_controller.dart';
import 'recents/animator/animation_widget.dart';

class FlexDemo extends StatefulWidget {
  const FlexDemo({super.key});

  @override
  State<FlexDemo> createState() => _FlexDemoState();
}

class _FlexDemoState extends State<FlexDemo> {
  final _layoutManagerHolder = ServiceHolder<LayoutManager>();
  late ListAdapter<int> _adapter;
  late ItemAnimatorController _animatorController;
  int _nextId = 0;

  FlexJustifyContent _justify = FlexJustifyContent.start;
  FlexAlignItems _align = FlexAlignItems.center;

  static const _itemSize = 30.0;
  static const _colors = [
    Colors.red, Colors.orange, Colors.yellow, Colors.green,
    Colors.teal, Colors.blue, Colors.purple, Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    _adapter = ListAdapter<int>(
      items: List.generate(5, (i) => _nextId++),
      idExtractor: (item) => item,
    );
    _animatorController = ItemAnimatorController(
      layoutManagerHolder: _layoutManagerHolder,
    );
    _adapter.addListener(_onAdapterChanged);
  }

  @override
  void dispose() {
    _adapter.removeListener(_onAdapterChanged);
    _adapter.dispose();
    _animatorController.dispose();
    super.dispose();
  }

  void _onAdapterChanged() => setState(() {});

  void _addItem() {
    final newId = _nextId++;
    final newIndex = _adapter.itemCount;
    final itemId = newId.toString();

    _animatorController.performLayoutAnimations(
      adapter: _adapter,
      addIndexes: [newIndex],
    );
    _adapter.addItem(newId, index: newIndex);

    _animatorController.performItemAnimation(
      itemId,
      newIndex,
      fromAlpha: 0.0,
      alpha: 1.0,
      curveConfig: const CurveConfig(curve: Curves.easeOut, durationMs: 300),
    );
  }

  void _removeItem() {
    if (_adapter.itemCount == 0) return;
    final lastIndex = _adapter.itemCount - 1;
    _animatorController.performLayoutAnimations(
      adapter: _adapter,
      removeIndexes: [lastIndex],
    );
    _adapter.removeAt(lastIndex);
  }

  FlexLayoutAlgorithm get _algorithm => FlexLayoutAlgorithm(
        justifyContent: _justify,
        alignItems: _align,
        scrollDirection: Axis.horizontal,
        itemSpacing: 8,
        mainAxisPadding: 12,
        crossAxisPadding: 8,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FlexBox Demo (${_adapter.itemCount} items)'),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          _buildControls(),
          Expanded(
            child: LayoutableListWidget(
              itemWidth: _itemSize,
              itemHeight: _itemSize,
              scrollDirection: Axis.horizontal,
              layoutManagerHolder: _layoutManagerHolder,
              layoutAlgorithm: _algorithm,
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final itemId = _adapter.getItemId(index);
                  final color = _colors[_adapter.getItem(index) % _colors.length];
                  return KeyedSubtree(
                    key: ValueKey(itemId),
                    child: ItemAnimator(
                      key: ValueKey('animator_$itemId'),
                      itemId: itemId,
                      paramsNotifier: _animatorController.listenAnimatorParams(itemId, index),
                      layoutParamsListenable:
                          _layoutManagerHolder.target!.listenLayoutParamsForPosition(index),
                      onDispose: _animatorController.onItemUnmounted,
                      child: _buildBox(index, color),
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
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'add',
            mini: true,
            onPressed: _addItem,
            child: const Icon(Icons.add),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'remove',
            mini: true,
            backgroundColor: _adapter.itemCount == 0 ? Colors.grey : Colors.red,
            onPressed: _adapter.itemCount > 0 ? _removeItem : null,
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }

  Widget _buildBox(int index, Color color) {
    return Container(
      width: _itemSize,
      height: _itemSize,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        '$index',
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('justify-content: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<FlexJustifyContent>(
                  value: _justify,
                  isExpanded: true,
                  onChanged: (v) => setState(() => _justify = v!),
                  items: FlexJustifyContent.values
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('align-items:      ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<FlexAlignItems>(
                  value: _align,
                  isExpanded: true,
                  onChanged: (v) => setState(() => _align = v!),
                  items: FlexAlignItems.values
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
