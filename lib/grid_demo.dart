import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'service_holder.dart';
import 'recents/layoutable_list_widget.dart';
import 'recents/algorithms/grid_layout_algorithm.dart';
import 'recents/animator/list_adapter.dart';
import 'recents/animator/item_animator.dart';
import 'recents/animator/item_animator_controller.dart';
import 'recents/drag/item_draggable.dart';

/// 网格布局 Demo（横向一行）
/// 使用 GridLayoutAlgorithm 和 ListAdapter 实现补位动画
class GridDemo extends StatefulWidget {
  const GridDemo({super.key});

  @override
  State<GridDemo> createState() => _GridDemoState();
}

class _GridDemoState extends State<GridDemo> implements ItemDragListener {
  final _layoutManagerHolder = ServiceHolder<LayoutManager>();
  late ListAdapter<CardItem> _adapter;
  late ItemAnimatorController _animatorController;
  int _nextId = 0;
  
  // 追踪新添加的 item，用于执行添加动画
  final Set<String> _newItemIds = {};

  @override
  void initState() {
    super.initState();
    
    // 初始化 5 个卡片
    final initialItems = List.generate(5, (index) {
      return CardItem(
        id: _nextId++,
        title: '卡片 ${index + 1}',
        color: _getColor(index),
      );
    });

    _adapter = ListAdapter<CardItem>(
      items: initialItems,
      idExtractor: (item) => item.id,
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

  void _onAdapterChanged() {
    setState(() {});
  }

  Color _getColor(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
      Colors.red,
    ];
    return colors[index % colors.length];
  }

  void _addItem() {
    final newItem = CardItem(
      id: _nextId,
      title: '卡片 $_nextId',
      color: _getColor(_nextId),
    );
    _nextId++;
    
    _newItemIds.add(newItem.id.toString());
    
    _animatorController.prepareLayoutAnimations(
      adapter: _adapter,
      addIndexes: [0],
    );
    _adapter.addItem(newItem, index: 0);
    _animatorController.commit();
    
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _newItemIds.remove(newItem.id.toString());
        });
      }
    });
  }

  void _removeItem() {
    if (_adapter.itemCount > 0) {
      _animatorController.prepareLayoutAnimations(
        adapter: _adapter,
        removeIndexes: [0],
      );
      _adapter.removeAt(0);
      _animatorController.commit();
    }
  }

  @override
  void onDragStart(String itemId) {}

  @override
  void onDragMove(String itemId, Offset offset) {}

  @override
  void onDragEnd(String itemId, DragResult result) {
    switch (result) {
      case SnapBack():
        // 回弹，不做任何操作
        break;
        
      case Swipe(:final direction):
        if (direction == AxisDirection.up || direction == AxisDirection.down) {
          final index = _adapter.findChildIndex(itemId);
          if (index != null) {
            _animatorController.prepareLayoutAnimations(
              adapter: _adapter,
              removeIndexes: [index],
            );
          }
          _adapter.removeById(itemId);
          _animatorController.commit();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已删除卡片 $itemId'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('网格布局 - 横向一行 (${_adapter.itemCount} 张卡片)'),
        backgroundColor: Colors.green,
      ),
      body: LayoutableListWidget(
        itemWidth: 200,
        itemHeight: 250,
        scrollDirection: Axis.horizontal,
        reverseLayout: false,
        layoutManagerHolder: _layoutManagerHolder,
        cacheExtent: 200,
        physics: const BouncingScrollPhysics(),
        layoutAlgorithm: GridLayoutAlgorithm(
          scrollDirection: Axis.horizontal,
          spanCount: 1, // 一行
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          mainAxisPadding: 16,
          crossAxisPadding: 16,
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
                    child: Transform.scale(
                      scale: value,
                      child: child,
                    ),
                  );
                },
                child: ItemDraggable(
                  key: ValueKey('draggable_$itemId'),
                  itemId: itemId,
                  paramsNotifier: _animatorController.listenAnimatorParams(itemId),
                  scrollDirection: Axis.horizontal,
                  listener: this,
                  swipeThreshold: const SwipeThreshold(
                    velocityThreshold: 800.0,
                    offsetThreshold: 300.0,
                  ),
                  dragGestureSettings: const DeviceGestureSettings(
                    touchSlop: 30.0,
                  ),
                  child: ItemAnimator(
                    key: ValueKey('animator_$itemId'),
                    itemId: itemId,
                    paramsNotifier: _animatorController.listenAnimatorParams(itemId),
                    layoutParamsListenable: _layoutManagerHolder.target!.listenLayoutParamsForPosition(index),
                    onDispose: _animatorController.onItemUnmounted,
                    child: _buildCard(item),
                  ),
                ),
              ),
            );
          },
          childCount: _adapter.itemCount,
          findChildIndexCallback: (Key key) {
            final valueKey = key as ValueKey<String>;
            return _adapter.findChildIndex(valueKey.value);
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _addItem,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'remove',
            onPressed: _adapter.itemCount > 0 ? _removeItem : null,
            backgroundColor: _adapter.itemCount == 0 ? Colors.grey : Colors.red,
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(CardItem item) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              item.color,
              item.color.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 40,
              child: Text(
                '${item.id}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ID: ${item.id}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CardItem {
  final int id;
  final String title;
  final Color color;

  CardItem({
    required this.id,
    required this.title,
    required this.color,
  });
}
