import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'service_holder.dart';
import 'recents/layoutable_list_widget.dart';
import 'recents/algorithms/grid_layout_algorithm.dart';
import 'recents/animator/list_adapter.dart';
import 'recents/animator/item_animator.dart';
import 'recents/physics/limited_overscroll_physics.dart';
import 'recents/item_draggable.dart';

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
  int _nextId = 0;
  
  // 追踪新添加的 item，用于执行添加动画
  final Set<int> _newItemIds = {};
  
  // 追踪正在拖拽的 item
  int? _draggingItemId;

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
      layoutManagerHolder: _layoutManagerHolder,
      idExtractor: (item) => item.id,
    );
    
    _adapter.addListener(_onAdapterChanged);
  }

  @override
  void dispose() {
    _adapter.removeListener(_onAdapterChanged);
    _adapter.dispose();
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
    
    // 标记为新添加的 item
    _newItemIds.add(newItem.id);
    
    _adapter.addItem(newItem, index: 0);
    
    // 400ms 后移除标记（添加动画完成）
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _newItemIds.remove(newItem.id);
        });
      }
    });
  }

  void _removeItem() {
    if (_adapter.items.isNotEmpty) {
      _adapter.removeAt(0);
    }
  }

  @override
  void onDragStart(int itemId) {
    setState(() {
      _draggingItemId = itemId;
    });
    debugPrint('开始拖拽: $itemId');
  }

  @override
  void onDragMove(int itemId, Offset offset) {
    // 可以在这里实时更新 UI，比如显示删除提示
    debugPrint('拖拽中: $itemId, offset: $offset');
  }

  @override
  void onDragEnd(int itemId, DragResult result) {
    setState(() {
      _draggingItemId = null;
    });
    
    switch (result) {
      case SnapBack():
        debugPrint('回弹: $itemId');
        
      case Swipe(:final direction, :final velocity, :final offset):
        debugPrint('Swipe: $itemId, 方向: $direction, 速度: $velocity, 偏移: $offset');
        
        // 根据方向删除 item
        if (direction == AxisDirection.up || direction == AxisDirection.down) {
          final item = _adapter.items.firstWhere((item) => item.id == itemId);
          _adapter.removeItem(item);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已删除卡片 $itemId'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('网格布局 - 横向一行 (${_adapter.items.length} 张卡片)'),
        backgroundColor: Colors.green,
      ),
      body: LayoutableListWidget(
        itemWidth: 200,
        itemHeight: 250,
        scrollDirection: Axis.horizontal,
        reverse: false,
        layoutManagerHolder: _layoutManagerHolder,
        cacheExtent: 200,
        physics: const LimitedOverscrollPhysics(maxOverscrollExtent: 60.0),
        layoutAlgorithm: GridLayoutAlgorithm(
          scrollDirection: Axis.horizontal,
          spanCount: 1, // 一行
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          mainAxisPadding: 16,
          crossAxisPadding: 16,
        ),
        delegate: SliverChildListDelegate(
          _adapter.items.map((item) {
            final isNew = _newItemIds.contains(item.id);

            return KeyedSubtree(
              key: ValueKey(item.id),
              child: TweenAnimationBuilder<double>(
                key: ValueKey('tween_${item.id}'),
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
                  key: ValueKey('draggable_${item.id}'),
                  itemId: item.id,
                  paramsNotifier: _adapter.listenAnimatorParams(item.id),
                  scrollDirection: Axis.horizontal,
                  listener: this,
                  swipeThreshold: const SwipeThreshold(
                    velocityThreshold: 800.0,
                    offsetThreshold: 300.0,
                  ),
                  dragGestureSettings: const DeviceGestureSettings(
                    touchSlop: 30.0,  // 增大阈值，让拖拽更难触发（接近 80 度才触发）
                  ),
                  child: ItemAnimator(
                    key: ValueKey('animator_${item.id}'),
                    itemId: item.id,
                    paramsNotifier: _adapter.listenAnimatorParams(item.id),
                    onDispose: _adapter.onItemUnmounted,
                    child: _buildCard(item),
                  ),
                ),
              ),
            );
          }).toList(),
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
            onPressed: _adapter.items.isNotEmpty ? _removeItem : null,
            backgroundColor: _adapter.items.isEmpty ? Colors.grey : Colors.red,
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
