import 'package:flutter/material.dart';
import 'service_holder.dart';
import 'recents/layoutable_list_widget.dart';
import 'recents/algorithms/stack_layout_algorithm.dart';
import 'recents/animator/list_adapter.dart';
import 'recents/animator/item_animator.dart';
import 'recents/physics/limited_overscroll_physics.dart';

/// 堆叠布局 Demo
/// 使用 StackLayoutAlgorithm 和 ListAdapter 实现补位动画
class StackDemo extends StatefulWidget {
  const StackDemo({super.key});

  @override
  State<StackDemo> createState() => _StackDemoState();
}

class _StackDemoState extends State<StackDemo> {
  final _layoutManagerHolder = ServiceHolder<LayoutManager>();
  late ListAdapter<CardItem> _adapter;
  int _nextId = 0;
  
  // 追踪新添加的 item，用于执行添加动画
  final Set<int> _newItemIds = {};

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('堆叠布局 (${_adapter.items.length} 张卡片)'),
        backgroundColor: Colors.blue,
      ),
      body: LayoutableListWidget(
        itemWidth: 300,
        itemHeight: 400,
        scrollDirection: Axis.horizontal,
        reverse: false,
        layoutManagerHolder: _layoutManagerHolder,
        cacheExtent: 300,
        physics: const LimitedOverscrollPhysics(maxOverscrollExtent: 60.0),
        layoutAlgorithm: StackLayoutAlgorithm(),
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
                child: ItemAnimator(
                  key: ValueKey('animator_${item.id}'),
                  itemId: item.id,
                  paramsNotifier: _adapter.listenAnimatorParams(item.id),
                  onDispose: _adapter.onItemUnmounted,
                  child: _buildCard(item),
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
