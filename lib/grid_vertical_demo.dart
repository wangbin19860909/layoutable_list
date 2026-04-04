import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'service_holder.dart';
import 'layoutablelist/layoutable_list_widget.dart';
import 'layoutablelist/algorithms/grid_layout_algorithm.dart';
import 'layoutablelist/list_adapter.dart';
import 'layoutablelist/animator/item_animator.dart';
import 'layoutablelist/animator/item_animator_controller.dart';
import 'layoutablelist/drag/item_swippable.dart';

class GridVerticalDemo extends StatefulWidget {
  const GridVerticalDemo({super.key});

  @override
  State<GridVerticalDemo> createState() => _GridVerticalDemoState();
}

class _GridVerticalDemoState extends State<GridVerticalDemo>
    with ItemSwipeListener {
  final _layoutManagerHolder = ServiceHolder<LayoutManager>();
  late ListAdapter<_CardItem> _adapter;
  late ItemAnimatorController _animatorController;
  final ScrollController _scrollController = ScrollController();
  int _nextId = 0;
  final Set<String> _newItemIds = {};

  @override
  void initState() {
    super.initState();
    final items = List.generate(10, (i) {
      return _CardItem(
          id: _nextId++, title: '卡片 ${i + 1}', color: _color(i));
    });
    _adapter = ListAdapter<_CardItem>(
      items: items,
      idExtractor: (item) => item.id,
    );
    _animatorController = ItemAnimatorController(
      layoutManagerHolder: _layoutManagerHolder,
    );
    _adapter.addListener(_onChanged);
  }

  @override
  void dispose() {
    _adapter.removeListener(_onChanged);
    _adapter.dispose();
    _animatorController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Color _color(int i) {
    const colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple,
      Colors.teal, Colors.pink, Colors.amber, Colors.cyan, Colors.red,
    ];
    return colors[i % colors.length];
  }

  void _addItem() {
    final item = _CardItem(
        id: _nextId, title: '卡片 $_nextId', color: _color(_nextId));
    _nextId++;
    _newItemIds.add(item.id.toString());
    _animatorController.performLayoutAnimations(
        adapter: _adapter, addIndexes: [0]);
    _adapter.addItem(item, index: 0);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _newItemIds.remove(item.id.toString()));
    });
  }

  @override
  void onSwipeStart(String itemId) {}

  @override
  void onSwipeMove(String itemId, Offset offset) {}

  @override
  bool onSwipeEnd(String itemId, SwipeResult result) {
    switch (result) {
      case SnapBack():
        return true;
      case Swipe(:final direction):
        if (direction == AxisDirection.left ||
            direction == AxisDirection.right) {
          final index = _adapter.findChildIndex(itemId);
          if (index != null) {
            final scrollBefore = _scrollController.hasClients
                ? _scrollController.offset
                : -1;
            final maxBefore = _scrollController.hasClients
                ? _scrollController.position.maxScrollExtent
                : -1;
            print('DEMO before performLayout: '
                'scroll=${scrollBefore.toStringAsFixed(1)} '
                'max=${maxBefore.toStringAsFixed(1)} '
                'itemCount=${_adapter.itemCount}');

            _animatorController.performLayoutAnimations(
              adapter: _adapter,
              removeIndexes: [index],
              refreshAfterAnimation: true,
              onComplete: () {
                final scrollMid = _scrollController.hasClients
                    ? _scrollController.offset
                    : -1;
                final maxMid = _scrollController.hasClients
                    ? _scrollController.position.maxScrollExtent
                    : -1;
                print('DEMO onComplete before remove: '
                    'scroll=${scrollMid.toStringAsFixed(1)} '
                    'max=${maxMid.toStringAsFixed(1)} '
                    'itemCount=${_adapter.itemCount}');

                _adapter.removeById(itemId);

                final scrollAfter = _scrollController.hasClients
                    ? _scrollController.offset
                    : -1;
                final maxAfter = _scrollController.hasClients
                    ? _scrollController.position.maxScrollExtent
                    : -1;
                print('DEMO onComplete after remove: '
                    'scroll=${scrollAfter.toStringAsFixed(1)} '
                    'max=${maxAfter.toStringAsFixed(1)} '
                    'itemCount=${_adapter.itemCount}');
              },
            );
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('已删除 $itemId'),
                duration: const Duration(seconds: 1)),
          );
        }
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('纵向网格 2列 (${_adapter.itemCount})'),
        backgroundColor: Colors.teal,
      ),
      body: LayoutableListWidget(
        itemSize: const Size(150, 408),
        scrollDirection: Axis.vertical,
        reverseLayout: false,
        layoutManagerHolder: _layoutManagerHolder,
        cacheExtent: 200,
        physics: const BouncingScrollPhysics(),
        scrollController: _scrollController,
        edgeSpacing: const EdgeInsets.all(12),
        itemSpacing: const Size(12, 12),
        layoutAlgorithm: GridLayoutAlgorithm(
          scrollDirection: Axis.vertical,
          spanCount: 2,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = _adapter.getItem(index);
            final itemId = _adapter.getItemId(index);
            final isNew = _newItemIds.contains(itemId);
            return KeyedSubtree(
              key: ValueKey(itemId),
              child: TweenAnimationBuilder<double>(
                key: ValueKey('tween_$itemId'),
                tween: Tween(begin: isNew ? 0.0 : 1.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(scale: value, child: child),
                  );
                },
                child: ItemSwippable(
                  key: ValueKey('draggable_$itemId'),
                  itemId: itemId,
                  paramsNotifier: _animatorController.listenAnimatorParams(
                      itemId, index),
                  scrollDirection: Axis.vertical,
                  listener: this,
                  swipeThreshold: const SwipeThreshold(
                    velocityThreshold: 800.0,
                    offsetThreshold: 200.0,
                  ),
                  dragThreshold:
                      const OffsetThreshold(min: -120, max: 120),
                  gestureSettings:
                      const DeviceGestureSettings(touchSlop: 30.0),
                  child: ItemAnimator(
                    key: ValueKey('animator_$itemId'),
                    itemId: itemId,
                    paramsNotifier:
                        _animatorController.listenAnimatorParams(
                            itemId, index),
                    layoutParamsListenable: _layoutManagerHolder.target!
                        .listenLayoutParamsForPosition(index),
                    onDispose: _animatorController.onItemUnmounted,
                    child: _buildCard(item),
                  ),
                ),
              ),
            );
          },
          childCount: _adapter.itemCount,
          findChildIndexCallback: (Key key) {
            final vk = key as ValueKey<String>;
            return _adapter.findChildIndex(vk.value);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add),
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
            colors: [item.color, item.color.withValues(alpha: 0.6)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 28,
                  child: Text('${item.id}',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: item.color))),
              const SizedBox(height: 8),
              Text(item.title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardItem {
  final int id;
  final String title;
  final Color color;

  _CardItem({required this.id, required this.title, required this.color});
}
