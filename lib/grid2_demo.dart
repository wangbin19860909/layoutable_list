import 'package:flutter/material.dart';
import 'service_holder.dart';
import 'layoutablelist/layoutable_list_widget.dart';
import 'layoutablelist/algorithms/grid_layout_algorithm.dart';
import 'layoutablelist/list_adapter.dart';
import 'layoutablelist/animator/item_animator.dart';
import 'layoutablelist/animator/item_animator_controller.dart';
import 'layoutablelist/animator/animation_widget.dart';

class Grid2Demo extends StatefulWidget {
  const Grid2Demo({super.key});

  @override
  State<Grid2Demo> createState() => _Grid2DemoState();
}

class _Grid2DemoState extends State<Grid2Demo> {
  final _layoutManagerHolder = ServiceHolder<LayoutManager>();
  late ListAdapter<_CardItem> _adapter;
  late ItemAnimatorController _animatorController;
  int _nextId = 0;

  // padding 档位：0=无, 1=左, 2=右
  int _paddingStep = 0;
  EdgeInsets _padding = EdgeInsets.zero;

  static const _colors = [
    Colors.blue, Colors.green, Colors.orange, Colors.purple,
    Colors.teal, Colors.pink, Colors.amber, Colors.cyan, Colors.red,
  ];

  @override
  void initState() {
    super.initState();
    _adapter = ListAdapter<_CardItem>(
      items: List.generate(8, (i) => _CardItem(id: _nextId++, color: _colors[i % _colors.length])),
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

  /// 根据容器尺寸和当前 padding 计算 itemSize 和 edgeSpacing
  ({Size itemSize, EdgeInsets edgeSpacing, Size itemSpacing}) _computeLayout(
    double containerWidth,
    double containerHeight,
    EdgeInsets padding,
  ) {
    final availableWidth = containerWidth - padding.horizontal;
    // edgeSpacing top/bottom = H * 0.24，item 行间距 = H * 0.12
    final edgeV = containerHeight * 0.24;
    final rowSpacing = containerHeight * 0.12;
    // 卡片高度 = (H - 2*edgeV - rowSpacing) / 2
    final cardHeight = (containerHeight - 2 * edgeV - rowSpacing) / 2;
    // 卡片宽高比与减去 padding 后的容器一致
    final cardWidth = cardHeight * availableWidth / containerHeight;

    return (
      itemSize: Size(cardWidth, cardHeight),
      edgeSpacing: EdgeInsets.symmetric(vertical: edgeV),
      itemSpacing: Size(cardWidth * 0.1, rowSpacing), // 主轴间距取卡片宽的 10%
    );
  }

  void _togglePadding(double containerWidth, double containerHeight) {
    _paddingStep = (_paddingStep + 1) % 3;
    final newPadding = switch (_paddingStep) {
      1 => EdgeInsets.only(left: containerWidth * 0.25),
      2 => EdgeInsets.only(right: containerWidth * 0.25),
      _ => EdgeInsets.zero,
    };
    final layout = _computeLayout(containerWidth, containerHeight, newPadding);
    _animatorController.performLayoutAnimations(
      adapter: _adapter,
      padding: newPadding,
      itemSize: layout.itemSize,
      edgeSpacing: layout.edgeSpacing,
      itemSpacing: layout.itemSpacing,
    );
    setState(() => _padding = newPadding);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Grid 2行 Demo (${_adapter.itemCount})'),
        backgroundColor: Colors.indigo,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final W = constraints.maxWidth;
          final H = constraints.maxHeight;
          final layout = _computeLayout(W, H, _padding);

          return LayoutableListWidget(
            itemSize: layout.itemSize,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            layoutManagerHolder: _layoutManagerHolder,
            padding: _padding,
            edgeSpacing: layout.edgeSpacing,
            itemSpacing: layout.itemSpacing,
            layoutAlgorithm: GridLayoutAlgorithm(
              scrollDirection: Axis.horizontal,
              spanCount: 2,
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
                    layoutParamsListenable:
                        _layoutManagerHolder.target!.listenLayoutParamsForPosition(index),
                    onDispose: _animatorController.onItemUnmounted,
                    child: _buildCard(item),
                  ),
                );
              },
              childCount: _adapter.itemCount,
              findChildIndexCallback: (key) {
                final id = (key as ValueKey<String>).value;
                return _adapter.findChildIndex(id);
              },
            ),
          );
        },
      ),
      floatingActionButton: Builder(
        builder: (context) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                heroTag: 'padding',
                onPressed: () {
                  final size = MediaQuery.of(context).size;
                  final H = size.height - kToolbarHeight - MediaQuery.of(context).padding.top;
                  _togglePadding(size.width, H);
                },
                backgroundColor: Colors.indigo,
                child: Icon(switch (_paddingStep) {
                  1 => Icons.align_horizontal_left,
                  2 => Icons.align_horizontal_right,
                  _ => Icons.expand,
                }),
              ),
              const SizedBox(height: 16),
              FloatingActionButton(
                heroTag: 'add',
                onPressed: () {
                  final item = _CardItem(id: _nextId, color: _colors[_nextId % _colors.length]);
                  _nextId++;
                  _animatorController.performLayoutAnimations(adapter: _adapter, addIndexes: [0]);
                  _adapter.addItem(item, index: 0);
                },
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 16),
              FloatingActionButton(
                heroTag: 'remove',
                backgroundColor: _adapter.itemCount == 0 ? Colors.grey : Colors.red,
                onPressed: _adapter.itemCount == 0
                    ? null
                    : () {
                        _animatorController.performLayoutAnimations(
                            adapter: _adapter, removeIndexes: [0]);
                        _adapter.removeAt(0);
                      },
                child: const Icon(Icons.remove),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(_CardItem item) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [item.color, item.color.withValues(alpha: 0.65)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          '${item.id}',
          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _CardItem {
  final int id;
  final Color color;
  const _CardItem({required this.id, required this.color});
}
