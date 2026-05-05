import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'service_holder.dart';
import 'layoutablelist/layoutable_list_widget.dart';
import 'layoutablelist/algorithms/grid_layout_algorithm.dart';
import 'layoutablelist/list_adapter.dart';
import 'layoutablelist/animator/item_animator.dart';
import 'layoutablelist/animator/item_animator_controller.dart';
import 'layoutablelist/animator/animation_widget.dart';
import 'layoutablelist/drag/item_swippable.dart';

/// 网格布局 Demo（横向一行）
/// 使用 GridLayoutAlgorithm 和 ListAdapter 实现补位动画
class GridDemo extends StatefulWidget {
  const GridDemo({super.key});

  @override
  State<GridDemo> createState() => _GridDemoState();
}

class _GridDemoState extends State<GridDemo> with ItemSwipeListener {
  final _layoutManagerHolder = ServiceHolder<LayoutManager>();
  late ListAdapter<CardItem> _adapter;
  late ItemAnimatorController _animatorController;
  int _nextId = 0;

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

    _animatorController.performLayoutAnimations(
      adapter: _adapter,
      addIndexes: [0],
    );
    _adapter.addItem(newItem, index: 0);

    // 新 item 入场动画：延迟等补位动画结束后，从 scale=0, alpha=0 → scale=1, alpha=1
    final itemId = newItem.id.toString();
    _animatorController.performItemAnimation(
      itemId,
      0,
      curveConfig: const CurveConfig(curve: Curves.easeOut, durationMs: 400),
      delayMs: 500,
      fromScale: 0.0,
      scalle: 1.0,
      fromAlpha: 0.0,
      alpha: 1.0,
    );
  }

  AnimationInterrupter? _removeInterrupter;

  void _removeItem() {
    if (_adapter.itemCount == 0) return;

    // 中断上一次未完成的删除，先同步数据
    _removeInterrupter?.interrupt();
    _removeInterrupter = null;

    final removeId = _adapter.getItemId(0);
    const itemHeight = 250.0;

    // 被删除的 item 执行上移消失动画
    _animatorController.performItemAnimation(
      removeId,
      0,
      curveConfig: const CurveConfig(curve: Curves.easeIn, durationMs: 300),
      offsetY: -itemHeight,
      alpha: 0.0,
      onComplete: _adapter.itemCount == 1 ? () => _adapter.removeAt(0) : null,
    );

    if (_adapter.itemCount > 1) {
      // 其他 item 补位动画，结束后刷新数据
      _removeInterrupter = _animatorController.performLayoutAnimations(
        adapter: _adapter,
        removeIndexes: [0],
        startDelayMs: 300,
        onComplete: () {
          _removeInterrupter = null;
          _adapter.removeAt(0);
        },
        refreshAfterAnimation: true,
      );
    }
  }

  AnimationInterrupter? _swipeRemoveInterrupter;

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
        if (direction == AxisDirection.up || direction == AxisDirection.down) {
          // 先 interrupt，触发 onComplete → removeById，数据同步后再查 index
          _swipeRemoveInterrupter?.interrupt();
          _swipeRemoveInterrupter = null;

          debugPrint(
            '[Swipe] after interrupt, findChildIndex(${itemId})=${_adapter.findChildIndex(itemId)} itemCount=${_adapter.itemCount}',
          );

          final index = _adapter.findChildIndex(itemId);
          if (index != null) {
            const itemHeight = 250.0;
            final flyOutY =
                direction == AxisDirection.up ? -itemHeight : itemHeight;
            _animatorController.performItemAnimation(
              itemId,
              index,
              curveConfig: const CurveConfig(
                curve: Curves.easeIn,
                durationMs: 300,
              ),
              offsetY: flyOutY,
              alpha: 0.0,
            );

            _swipeRemoveInterrupter = _animatorController
                .performLayoutAnimations(
                  adapter: _adapter,
                  removeIndexes: [index],
                  refreshAfterAnimation: true,
                  onComplete: () {
                    _swipeRemoveInterrupter = null;
                    _adapter.removeById(itemId);
                  },
                );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已删除卡片 $itemId'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
        return true;
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
        itemSize: const Size(200, 250),
        scrollDirection: Axis.horizontal,
        reverseLayout: true,
        layoutManagerHolder: _layoutManagerHolder,
        cacheExtent: 200,
        physics: const BouncingScrollPhysics(),
        edgeSpacing: const EdgeInsets.all(16),
        itemSpacing: const Size(16, 16),
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
                key: ValueKey('animator_$itemId'),
                itemId: itemId,
                paramsNotifier: _animatorController.listenAnimatorParams(
                  itemId,
                  index,
                ),
                layoutParamsListenable: _layoutManagerHolder.target!
                    .listenLayoutParamsForPosition(index),
                onDispose: _animatorController.onItemUnmounted,
                child: ItemSwippable(
                  key: ValueKey('draggable_$itemId'),
                  itemId: itemId,
                  paramsNotifier: _animatorController.listenAnimatorParams(
                    itemId,
                    index,
                  ),
                  scrollDirection: Axis.horizontal,
                  listener: this,
                  swipeThreshold: const SwipeThreshold(
                    velocityThreshold: 800.0,
                    offsetThreshold: 300.0,
                  ),
                  dragThreshold: const OffsetThreshold(min: -150, max: 150),
                  gestureSettings: const DeviceGestureSettings(touchSlop: 30.0),
                  child: _buildCard(item),
                ),
              ),
            );
          },
          childCount: _adapter.itemCount,
          findChildIndexCallback: (Key key) {
            final valueKey = key as ValueKey<String>;
            return _adapter.findChildIndex(valueKey.value);
          },
          addRepaintBoundaries: false,
          addSemanticIndexes: false,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [item.color, item.color.withValues(alpha: 0.7)],
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
              style: const TextStyle(fontSize: 14, color: Colors.white70),
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

  CardItem({required this.id, required this.title, required this.color});
}
