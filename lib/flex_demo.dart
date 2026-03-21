import 'package:flutter/material.dart';
import 'service_holder.dart';
import 'layoutablelist/layoutable_list_widget.dart';
import 'layoutablelist/algorithms/flex_layout_algorithm.dart';
import 'layoutablelist/algorithms/layout_algorithm.dart';
import 'layoutablelist/list_adapter.dart';
import 'layoutablelist/animator/item_animator.dart';
import 'layoutablelist/animator/item_animator_controller.dart';
import 'layoutablelist/animator/animation_widget.dart';

/// 分割线使用负数 ID，普通 item 使用非负 ID
const _dividerId = -1;

bool _isDivider(int id) => id == _dividerId;

/// 为分割线提供不同尺寸的 ItemSizeProvider
///
/// 分割线的主轴宽度为 [dividerBaseWidth]，按 defaultSize 与 baseItemSize 的比例缩放。
/// totalOffsetUpTo 返回 [0, index) 范围内所有尺寸差值的累积。
class _DividerSizeProvider implements ItemSizeProvider {
  final ListAdapter<int> adapter;
  final double dividerBaseWidth;
  final double baseItemSize;

  _DividerSizeProvider({
    required this.adapter,
    required this.dividerBaseWidth,
    required this.baseItemSize,
  });

  double _scaledDividerWidth(Size defaultSize) =>
      dividerBaseWidth * (defaultSize.width / baseItemSize);

  @override
  Size sizeOf(int index, Size defaultSize) {
    if (index < adapter.itemCount && _isDivider(adapter.getItem(index))) {
      return Size(_scaledDividerWidth(defaultSize), defaultSize.height);
    }
    return defaultSize;
  }

  @override
  Offset totalOffsetUpTo(int index, Size defaultSize) {
    final delta = _scaledDividerWidth(defaultSize) - defaultSize.width;
    final count = index.clamp(0, adapter.itemCount);
    int dividers = 0;
    for (int i = 0; i < count; i++) {
      if (_isDivider(adapter.getItem(i))) dividers++;
    }
    return Offset(delta * dividers, 0);
  }
}

class FlexDemo extends StatefulWidget {
  const FlexDemo({super.key});

  @override
  State<FlexDemo> createState() => _FlexDemoState();
}

class _FlexDemoState extends State<FlexDemo> {
  final _layoutManagerHolder = ServiceHolder<LayoutManager>();
  late ListAdapter<int> _adapter;
  late ItemAnimatorController _animatorController;
  late _DividerSizeProvider _sizeProvider;
  int _nextId = 0;

  FlexJustifyContent _justify = FlexJustifyContent.start;
  FlexAlignItems _align = FlexAlignItems.center;

  static const _baseItemSize = 80.0;
  static const _baseSpacing = 8.0;
  static const _edgeH = 12.0;
  static const _dividerWidth = 2.0;
  static const _colors = [
    Colors.red, Colors.orange, Colors.yellow, Colors.green,
    Colors.teal, Colors.blue, Colors.purple, Colors.pink,
  ];

  /// 分割线在 adapter 中的 index（固定为 9）
  static const _dividerIndex = 9;

  @override
  void initState() {
    super.initState();
    // 生成 10 个普通 item + 1 个分割线 + 3 个普通 item = 14 个
    final items = <int>[];
    for (int i = 0; i < 9; i++) items.add(_nextId++);
    items.add(_dividerId);
    for (int i = 0; i < 3; i++) items.add(_nextId++);

    _adapter = ListAdapter<int>(
      items: items,
      idExtractor: (item) => item == _dividerId ? _dividerId : item,
    );
    _sizeProvider = _DividerSizeProvider(
      adapter: _adapter,
      dividerBaseWidth: _dividerWidth,
      baseItemSize: _baseItemSize,
    );
    _animatorController = ItemAnimatorController(
      layoutManagerHolder: _layoutManagerHolder,
    );
    _adapter.addListener(_onAdapterChanged);
  }

  @override
  void dispose() {
    _adapter.removeListener(_onAdapterChanged);
    _layoutManagerHolder.target?.removeListener(_onItemBoundsChanged);
    _adapter.dispose();
    _animatorController.dispose();
    super.dispose();
  }

  double _containerWidth = 0;
  Rect _itemBounds = Rect.zero;
  bool _boundsListenerRegistered = false;

  void _onAdapterChanged() => setState(() {});

  void _onItemBoundsChanged(Rect bounds) {
    if (mounted) setState(() => _itemBounds = bounds);
  }

  /// 分割线后面的 item 数量（不含分割线本身）
  int get _afterDividerCount => _adapter.itemCount - _dividerIndex - 1;

  ({Size itemSize, Size itemSpacing, EdgeInsetsGeometry edgeSpacing}) _scaledParams(int itemCount) {
    final s = _scale(_containerWidth, itemCount);
    return (
      itemSize: Size(_baseItemSize * s, _baseItemSize * s),
      itemSpacing: Size(_baseSpacing * s, 0),
      edgeSpacing: EdgeInsets.symmetric(horizontal: _edgeH * s, vertical: 8),
    );
  }

  /// 在分割线前面添加 item（插入到 _dividerIndex 位置，分割线后移）
  void _addBefore() {
    final newId = _nextId++;
    final insertIndex = _dividerIndex;
    final itemId = newId.toString();
    final newParams = _scaledParams(_adapter.itemCount + 1);

    _animatorController.performLayoutAnimations(
      adapter: _adapter,
      addIndexes: [insertIndex],
      itemSize: newParams.itemSize,
      itemSpacing: newParams.itemSpacing,
      edgeSpacing: newParams.edgeSpacing,
    );
    _adapter.addItem(newId, index: insertIndex);

    _animatorController.performItemAnimation(
      itemId,
      insertIndex,
      fromAlpha: 0.0,
      alpha: 1.0,
      curveConfig: const CurveConfig(curve: Curves.easeOut, durationMs: 300),
    );
  }

  /// 在分割线后面添加 item（固定插入到 index=10，即分割线后第一个位置）
  /// 当后面的 item 数量 > 3 时，替换 index=10 的 item（无动画）
  void _addAfter() {
    final newId = _nextId++;
    final insertIndex = _dividerIndex + 1;

    if (_afterDividerCount > 3) {
      _adapter.replaceAt(insertIndex, newId);
    } else {
      final itemId = newId.toString();
      final newParams = _scaledParams(_adapter.itemCount + 1);

      _animatorController.performLayoutAnimations(
        adapter: _adapter,
        addIndexes: [insertIndex],
        itemSize: newParams.itemSize,
        itemSpacing: newParams.itemSpacing,
        edgeSpacing: newParams.edgeSpacing,
      );
      _adapter.addItem(newId, index: insertIndex);

      _animatorController.performItemAnimation(
        itemId,
        insertIndex,
        fromAlpha: 0.0,
        alpha: 1.0,
        curveConfig: const CurveConfig(curve: Curves.easeOut, durationMs: 300),
      );
    }
  }

  void _removeItem() {
    if (_adapter.itemCount == 0) return;
    final lastIndex = _adapter.itemCount - 1;
    final newParams = _scaledParams(_adapter.itemCount - 1);

    _animatorController.performLayoutAnimations(
      adapter: _adapter,
      removeIndexes: [lastIndex],
      itemSize: newParams.itemSize,
      itemSpacing: newParams.itemSpacing,
      edgeSpacing: newParams.edgeSpacing,
    );
    _adapter.removeAt(lastIndex);
  }

  double _scale(double containerWidth, int itemCount) {
    if (itemCount == 0) return 1.0;
    // 分割线占 _dividerWidth 而非 _baseItemSize
    final dividerCount = _adapter.itemCount > _dividerIndex ? 1 : 0;
    final normalCount = itemCount - dividerCount;
    final totalContent = _edgeH * 2 +
        normalCount * _baseItemSize +
        dividerCount * _dividerWidth +
        (itemCount - 1) * _baseSpacing;
    return (containerWidth / totalContent).clamp(0.0, 1.0);
  }

  FlexLayoutAlgorithm get _algorithm => FlexLayoutAlgorithm(
        justifyContent: _justify,
        alignItems: _align,
        direction: Axis.horizontal,
        itemSizeProvider: _sizeProvider,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                _containerWidth = constraints.maxWidth;
                final s = _scale(constraints.maxWidth, _adapter.itemCount);
                final scaledItem = _baseItemSize * s;
                final scaledSpacing = _baseSpacing * s;
                final scaledEdge = _edgeH * s;

                if (!_boundsListenerRegistered &&
                    _layoutManagerHolder.target != null) {
                  _boundsListenerRegistered = true;
                  _layoutManagerHolder.target!.addListener(_onItemBoundsChanged);
                }

                final list = LayoutableListWidget(
                  itemSize: Size(scaledItem, scaledItem),
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  layoutManagerHolder: _layoutManagerHolder,
                  layoutAlgorithm: _algorithm,
                  edgeSpacing: EdgeInsets.symmetric(
                    horizontal: scaledEdge,
                    vertical: 8,
                  ),
                  itemSpacing: Size(scaledSpacing, 0),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final itemId = _adapter.getItemId(index);
                      final rawItem = _adapter.getItem(index);

                      if (_isDivider(rawItem)) {
                        return KeyedSubtree(
                          key: ValueKey(itemId),
                          child: ItemAnimator(
                            key: ValueKey('animator_$itemId'),
                            itemId: itemId,
                            paramsNotifier: _animatorController
                                .listenAnimatorParams(itemId, index),
                            layoutParamsListenable: _layoutManagerHolder
                                .target!
                                .listenLayoutParamsForPosition(index),
                            onDispose: _animatorController.onItemUnmounted,
                            child: Center(
                              child: Container(
                                width: _dividerWidth,
                                height: scaledItem * 0.8,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        );
                      }

                      final color = _colors[rawItem % _colors.length];
                      return KeyedSubtree(
                        key: ValueKey(itemId),
                        child: ItemAnimator(
                          key: ValueKey('animator_$itemId'),
                          itemId: itemId,
                          paramsNotifier: _animatorController
                              .listenAnimatorParams(itemId, index),
                          layoutParamsListenable: _layoutManagerHolder.target!
                              .listenLayoutParamsForPosition(index),
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
                );

                return Stack(
                  children: [
                    if (_itemBounds != Rect.zero)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        left: _itemBounds.left,
                        top: _itemBounds.top,
                        width: _itemBounds.width,
                        height: _itemBounds.height,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    list,
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'addBefore',
            mini: true,
            onPressed: _addBefore,
            tooltip: '分割线前添加',
            child: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            heroTag: 'addAfter',
            mini: true,
            onPressed: _addAfter,
            tooltip: '分割线后添加',
            child: const Icon(Icons.arrow_forward),
          ),
          const SizedBox(width: 8),
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
