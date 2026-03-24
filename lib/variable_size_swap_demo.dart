import 'package:flutter/material.dart';
import 'service_holder.dart';
import 'layoutablelist/layoutable_list_widget.dart';
import 'layoutablelist/algorithms/flex_layout_algorithm.dart';
import 'layoutablelist/algorithms/layout_algorithm.dart';
import 'layoutablelist/list_adapter.dart';
import 'layoutablelist/animator/item_animator.dart';
import 'layoutablelist/animator/item_animator_controller.dart';
import 'layoutablelist/animator/animation_widget.dart';

// ── tag 常量 ──────────────────────────────────────────────────────────────────

/// 传给 performLayoutAnimations(newTag:) 的 tag，
/// ItemSizeProvider 收到此 tag 时返回变更后的尺寸。
const _kNewLayoutTag = 'new';

// ── 数据模型 ──────────────────────────────────────────────────────────────────

class _Item {
  final int id;
  final String label;
  final double height; // 每个 item 自己的高度

  const _Item({required this.id, required this.label, required this.height});
}

// ── ItemSizeProvider 实现 ─────────────────────────────────────────────────────

/// 按 index 存储高度数组，根据 tag 决定返回哪套：
/// - tag == _kNewLayoutTag → newHeights（新布局各 index 的槽高）
/// - 其他              → currentHeights（当前布局各 index 的槽高）
class _VariableSizeProvider implements ItemSizeProvider {
  List<double> currentHeights;
  List<double> newHeights;

  _VariableSizeProvider({required this.currentHeights, required this.newHeights});

  List<double> _pick(Object? tag) => tag == _kNewLayoutTag ? newHeights : currentHeights;

  @override
  Size sizeOf(int index, Size defaultSize, {Object? tag}) {
    final heights = _pick(tag);
    if (index < 0 || index >= heights.length) return defaultSize;
    return Size(defaultSize.width, heights[index]);
  }

  @override
  Offset totalOffsetUpTo(int index, Size defaultSize, {Object? tag}) {
    final heights = _pick(tag);
    double dy = 0;
    final count = index.clamp(0, heights.length);
    for (int i = 0; i < count; i++) {
      dy += heights[i] - defaultSize.height;
    }
    return Offset(0, dy);
  }
}

// ── Demo Widget ───────────────────────────────────────────────────────────────

class VariableSizeSwapDemo extends StatefulWidget {
  const VariableSizeSwapDemo({super.key});

  @override
  State<VariableSizeSwapDemo> createState() => _VariableSizeSwapDemoState();
}

class _VariableSizeSwapDemoState extends State<VariableSizeSwapDemo> {
  final _layoutManagerHolder = ServiceHolder<LayoutManager>();
  late ListAdapter<_Item> _adapter;
  late ItemAnimatorController _animatorController;
  late _VariableSizeProvider _sizeProvider;

  // 默认 item 高度（用于 itemSize.height）
  static const double _defaultHeight = 60.0;
  static const double _listWidth = 300.0;

  // 初始数据：5 个不同高度的 item
  static final _initialItems = [
    const _Item(id: 0, label: 'A', height: 48),
    const _Item(id: 1, label: 'B', height: 80),
    const _Item(id: 2, label: 'C', height: 60),
    const _Item(id: 3, label: 'D', height: 100),
    const _Item(id: 4, label: 'E', height: 56),
  ];

  static const _colors = [
    Colors.red, Colors.orange, Colors.amber, Colors.green, Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _adapter = ListAdapter<_Item>(
      items: List.from(_initialItems),
      idExtractor: (item) => item.id,
    );
    final initialHeights = _initialItems.map((e) => e.height).toList();
    _sizeProvider = _VariableSizeProvider(
      currentHeights: List.from(initialHeights),
      newHeights: List.from(initialHeights),
    );
    _animatorController = ItemAnimatorController(
      layoutManagerHolder: _layoutManagerHolder,
      curveConfig: const CurveConfig(curve: Curves.easeInOut, durationMs: 500),
    );
    _adapter.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _adapter.dispose();
    _animatorController.dispose();
    super.dispose();
  }

  // ── 操作 ──────────────────────────────────────────────────────────────────

  void _swap(int i, int j) {
    if (i == j) return;
    final newItems = List.generate(_adapter.itemCount, _adapter.getItem);
    final tmp = newItems[i];
    newItems[i] = newItems[j];
    newItems[j] = tmp;

    final diff = _adapter.diffItems(newItems);
    final newHeights = newItems.map((e) => e.height).toList();

    _sizeProvider.newHeights = newHeights;

    // 1. 先用旧 currentHeights 计算起始偏移
    _animatorController.performLayoutAnimations(
      adapter: _adapter,
      addIndexes: diff.addIndexes,
      removeIndexes: diff.removeIndexes,
      moveIndexes: diff.moveIndexes,
      newTag: _kNewLayoutTag,
    );

    // 2. 切换 currentHeights，让 rebuild 时 layoutParamsListenable 返回正确槽高
    _sizeProvider.currentHeights = newHeights;

    // 3. applyDiff 触发 rebuild
    _adapter.applyDiff(newItems);
  }

  void _reverse() {
    final newItems = List.generate(_adapter.itemCount, _adapter.getItem).reversed.toList();
    final diff = _adapter.diffItems(newItems);
    final newHeights = newItems.map((e) => e.height).toList();

    _sizeProvider.newHeights = newHeights;

    _animatorController.performLayoutAnimations(
      adapter: _adapter,
      addIndexes: diff.addIndexes,
      removeIndexes: diff.removeIndexes,
      moveIndexes: diff.moveIndexes,
      newTag: _kNewLayoutTag,
    );

    _sizeProvider.currentHeights = newHeights;
    _adapter.applyDiff(newItems);
  }

  void _reset() {
    final newItems = List<_Item>.from(_initialItems);
    final diff = _adapter.diffItems(newItems);
    final newHeights = newItems.map((e) => e.height).toList();

    _sizeProvider.newHeights = newHeights;

    _animatorController.performLayoutAnimations(
      adapter: _adapter,
      addIndexes: diff.addIndexes,
      removeIndexes: diff.removeIndexes,
      moveIndexes: diff.moveIndexes,
      newTag: _kNewLayoutTag,
    );

    _sizeProvider.currentHeights = newHeights;
    _adapter.applyDiff(newItems);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('不同尺寸 Item 交换动画'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Row(
        children: [
          // 左侧：列表
          SizedBox(
            width: _listWidth,
            child: _buildList(),
          ),
          const VerticalDivider(width: 1),
          // 右侧：控制面板
          Expanded(child: _buildControls()),
        ],
      ),
    );
  }

  Widget _buildList() {
    return LayoutableListWidget(
      itemSize: const Size(_listWidth, _defaultHeight),
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(),
      layoutManagerHolder: _layoutManagerHolder,
      edgeSpacing: const EdgeInsets.symmetric(vertical: 8),
      itemSpacing: const Size(0, 6),
      layoutAlgorithm: FlexLayoutAlgorithm(
        direction: Axis.vertical,
        justifyContent: FlexJustifyContent.start,
        alignItems: FlexAlignItems.stretch,
        itemSizeProvider: _sizeProvider,
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
              child: _buildItem(item),
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
  }

  Widget _buildItem(_Item item) {
    final color = _colors[item.id % _colors.length];
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        '${item.label}  (h=${item.height.toInt()})',
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildControls() {
    final count = _adapter.itemCount;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('交换', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < count; i++)
                for (int j = i + 1; j < count; j++)
                  _btn('${_label(i)} ↔ ${_label(j)}', Colors.deepOrange, () => _swap(i, j)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('其他', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _btn('全部反转', Colors.indigo, _reverse),
              _btn('重置', Colors.grey, _reset),
            ],
          ),
        ],
      ),
    );
  }

  String _label(int index) {
    if (index >= _adapter.itemCount) return '?';
    return _adapter.getItem(index).label;
  }

  Widget _btn(String label, Color color, VoidCallback onTap) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
