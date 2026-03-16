import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'service_holder.dart';
import 'recents/layoutable_list_widget.dart';
import 'recents/algorithms/stack_layout_algorithm.dart';
import 'recents/animator/list_adapter.dart';
import 'recents/animator/item_animator.dart';
import 'recents/animator/item_animator_controller.dart';
import 'recents/animator/animation_widget.dart';
import 'recents/physics/stack_scroll_physics.dart';
import 'recents/drag/item_draggable.dart';

/// 堆叠布局 Demo
/// 使用 StackLayoutAlgorithm 和 ListAdapter 实现补位动画
class StackDemo extends StatefulWidget {
  const StackDemo({super.key});

  @override
  State<StackDemo> createState() => _StackDemoState();
}

class _StackDemoState extends State<StackDemo> implements ItemDragListener {
  final _layoutManagerHolder = ServiceHolder<LayoutManager>();
  late ListAdapter<CardItem> _adapter;
  late ItemAnimatorController _animatorController;
  int _nextId = 0;
  
  // 追踪新添加的 item，用于执行添加动画
  final Set<String> _newItemIds = {};

  // 左右 padding，三档循环：zero → left → right → zero
  int _paddingStep = 0;
  EdgeInsets _padding = EdgeInsets.zero;
  // 当前 item 尺寸（随 paddingStep 变化）
  Size? _itemSize; // null 表示使用默认尺寸

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
      springConfig: const SpringConfig(stiffness: 200.0, damping: 22.0),
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

  void _togglePadding(double cardWidth, double cardHeight) {
    final half = cardWidth / 2;
    _paddingStep = (_paddingStep + 1) % 3;
    final newPadding = switch (_paddingStep) {
      1 => EdgeInsets.only(left: cardWidth / 2),
      2 => EdgeInsets.only(right: cardWidth / 2),
      _ => EdgeInsets.zero,
    };
    // step=0 恢复原始尺寸，其他步骤宽度减半
    final newItemSize = _paddingStep == 0
        ? Size(cardWidth, cardHeight)
        : Size(half, cardHeight);
    _animatorController.performLayoutAnimations(
      adapter: _adapter,
      padding: newPadding,
      itemSize: newItemSize,
    );
    setState(() {
      _padding = newPadding;
      _itemSize = _paddingStep == 0 ? null : newItemSize;
    });
  }

  void _addItem() {
    final newItem = CardItem(
      id: _nextId,
      title: '卡片 $_nextId',
      color: _getColor(_nextId),
    );
    _nextId++;
    
    _newItemIds.add(newItem.id.toString());
    
    _animatorController.performLayoutAnimations(
      adapter: _adapter,
      addIndexes: [0],
    );
    _adapter.addItem(newItem, index: 0);
    
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
      _animatorController.performLayoutAnimations(
        adapter: _adapter,
        removeIndexes: [0],
      );
      _adapter.removeAt(0);
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
        // 回弹，不做处理
        break;
        
      case Swipe(:final direction):
        // 根据方向删除 item
        if (direction == AxisDirection.up || direction == AxisDirection.down) {
          final index = _adapter.findChildIndex(itemId);
          if (index != null) {
            _animatorController.performLayoutAnimations(
              adapter: _adapter,
              removeIndexes: [index],
            );
          }
          _adapter.removeById(itemId);
          
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
    // 获取屏幕尺寸
    final screenSize = MediaQuery.of(context).size;
    final containerWidth = screenSize.width;
    final containerHeight = screenSize.height - kToolbarHeight - MediaQuery.of(context).padding.top;
    
    // 卡片高度是容器高度的 0.8
    final cardHeight = containerHeight * 0.8;
    // 卡片宽高比与容器一致
    final cardWidth = cardHeight * (containerWidth / containerHeight);
    // 实际使用的 item 尺寸（_itemSize 非 null 时覆盖）
    final itemWidth = _itemSize?.width ?? cardWidth;
    final itemHeight = _itemSize?.height ?? cardHeight;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('堆叠布局 (${_adapter.itemCount} 张卡片)'),
        backgroundColor: Colors.blue,
      ),
      body: LayoutableListWidget(
        itemWidth: itemWidth,
        itemHeight: itemHeight,
        scrollDirection: Axis.horizontal,
        reverseLayout: false,
        reversePaint: true,
        layoutManagerHolder: _layoutManagerHolder,
        cacheExtent: 300,
        physics: StackSnapScrollPhysics(layoutManager: _layoutManagerHolder),
        layoutAlgorithm: StackLayoutAlgorithm(),
        padding: _padding,
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
                  paramsNotifier: _animatorController.listenAnimatorParams(itemId, index),
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
                    key: ValueKey('animator_$itemId'),
                    itemId: itemId,
                    paramsNotifier: _animatorController.listenAnimatorParams(itemId, index),
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
            heroTag: 'padding',
            onPressed: () => _togglePadding(cardWidth, cardHeight),
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
              radius: 50,
              child: Text(
                '${item.id}',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ID: ${item.id}',
              style: const TextStyle(
                fontSize: 16,
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
