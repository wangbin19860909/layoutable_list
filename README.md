# LayoutableList

一个高度可定制的 Flutter 列表组件，支持自定义布局算法、补位动画、拖拽交互和弹性滚动。

---

## 目录结构

```
lib/layoutablelist/
├── layoutable_list_widget.dart   # 核心 Widget
├── list_adapter.dart             # 数据适配器
├── algorithms/                   # 布局算法
│   ├── layout_algorithm.dart     # 抽象接口
│   ├── grid_layout_algorithm.dart
│   ├── flex_layout_algorithm.dart
│   └── stack_layout_algorithm.dart
├── animator/                     # 动画系统
│   ├── animation_widget.dart     # 底层动画 Widget
│   ├── item_animator.dart        # Item 动画包装
│   └── item_animator_controller.dart  # 动画控制器
├── drag/                         # 拖拽系统
│   └── item_draggable.dart
└── physics/                      # 滚动物理
    └── stack_scroll_physics.dart
```

---

## 核心组件

### LayoutableListWidget

列表的入口 Widget，内部封装 `CustomScrollView` + `LayoutableSliverList`。

```dart
LayoutableListWidget(
  itemSize: const Size(100, 100),
  scrollDirection: Axis.horizontal,
  layoutAlgorithm: GridLayoutAlgorithm(
    scrollDirection: Axis.horizontal,
    spanCount: 1,
  ),
  layoutManagerHolder: _layoutManagerHolder,
  edgeSpacing: const EdgeInsets.all(16),
  itemSpacing: const Size(12, 0),
  paintConfig: const PaintConfig(reverse: true),  // Stack 布局用
  delegate: SliverChildBuilderDelegate(
    (context, index) => YourItemWidget(),
    childCount: itemCount,
  ),
)
```

**主要参数：**

| 参数 | 说明 |
|------|------|
| `itemSize` | item 的基准尺寸 |
| `layoutAlgorithm` | 布局算法实例 |
| `layoutManagerHolder` | 用于外部访问 LayoutManager |
| `edgeSpacing` | 容器边缘间距 |
| `itemSpacing` | item 间距（主轴 width，交叉轴 height）|
| `paintConfig` | 绘制配置，支持 reverse 顺序和 topMostIndex |
| `physics` | 滚动物理效果 |

---

### PaintConfig

控制 item 的绘制顺序。

```dart
// Stack 布局：index 大的先画（在下层）
PaintConfig(reverse: true)

// 拖拽时让某个 item 显示在最上层
PaintConfig(reverse: true, topMostIndex: draggingIndex)
```

---

### ListAdapter

管理列表数据，提供增删改和 diff 能力。

```dart
final _adapter = ListAdapter<MyItem>(
  items: initialItems,
  idExtractor: (item) => item.id,  // 返回唯一 int id
);

// 增删
_adapter.addItem(item, index: 0);
_adapter.removeAt(0);
_adapter.removeById('itemId');
_adapter.replaceAt(0, newItem);

// 批量替换（用于 move/swap/reverse）
_adapter.applyDiff(newItems);

// diff：生成 DiffResult，传给 performLayoutAnimations
final diff = _adapter.diffItems(newItems);
```

**DiffResult：**

```dart
class DiffResult {
  final List<int> addIndexes;       // 新增 item 在新列表中的 index
  final List<int> removeIndexes;    // 删除 item 在旧列表中的 index
  final Map<String, int> moveIndexes; // itemId → newIndex（位置变化的 item）
}
```

`diffItems` 基于 id 匹配，时间复杂度 O(n)。

---

## 布局算法

所有算法实现 `LayoutAlgorithm` 接口，可自由替换。

### GridLayoutAlgorithm

标准网格布局，支持横向/纵向滚动和多列/多行。

```dart
GridLayoutAlgorithm(
  scrollDirection: Axis.horizontal,
  spanCount: 2,  // 交叉轴方向的列数/行数
)
```

### FlexLayoutAlgorithm

类 CSS Flexbox 布局，支持 `justify-content` 和 `align-items`。

```dart
FlexLayoutAlgorithm(
  direction: Axis.horizontal,
  justifyContent: FlexJustifyContent.center,
  alignItems: FlexAlignItems.center,
  itemSizeProvider: myProvider,  // 可选，支持不同 item 尺寸
)
```

**ItemSizeProvider** — 支持不同尺寸的 item：

```dart
class MyProvider implements ItemSizeProvider {
  @override
  Size sizeOf(int index, Size defaultSize) {
    return index == dividerIndex
        ? Size(2, defaultSize.height)  // 分割线
        : defaultSize;
  }

  @override
  Offset totalOffsetUpTo(int index, Size defaultSize) {
    // 返回 [0, index) 范围内所有尺寸差值的累积偏移
  }
}
```

### StackLayoutAlgorithm

堆叠卡片布局，配合 `StackSnapScrollPhysics` 实现卡片吸附滚动。

```dart
LayoutableListWidget(
  layoutAlgorithm: StackLayoutAlgorithm(),
  physics: StackSnapScrollPhysics(layoutManager: _layoutManagerHolder),
  paintConfig: const PaintConfig(reverse: true),
  ...
)
```

---

## 动画系统

### ItemAnimatorController

管理所有 item 的动画参数，在数据变更前调用，计算补位动画。

```dart
final _controller = ItemAnimatorController(
  layoutManagerHolder: _layoutManagerHolder,
  // 全局动画配置（可选）
  curveConfig: const CurveConfig(curve: Curves.easeInOut, durationMs: 400),
  // 或弹簧动画
  springConfig: const SpringConfig(stiffness: 200, damping: 22),
);

// 1. 先调用 performLayoutAnimations（数据变更前）
_controller.performLayoutAnimations(
  adapter: _adapter,
  addIndexes: [0],
  removeIndexes: [3],
  moveIndexes: diff.moveIndexes,  // move/swap 场景
);

// 2. 再变更数据
_adapter.addItem(newItem, index: 0);
_adapter.removeAt(3);
```

**performLayoutAnimations 参数：**

| 参数 | 说明 |
|------|------|
| `addIndexes` | 新增 item 的插入位置（变更后的 index）|
| `removeIndexes` | 删除 item 的位置（变更前的 index）|
| `moveIndexes` | itemId → newIndex，直接指定目标位置 |
| `padding` / `itemSize` / `edgeSpacing` / `itemSpacing` | 变更后的布局参数（可选）|
| `onComplete` | 所有动画完成后的回调 |

返回 `AnimationInterrupter`，可调用 `interrupt()` 提前结束动画。

**单个 item 动画：**

```dart
_controller.performItemAnimation(
  itemId,
  index,
  offsetY: -100,
  alpha: 0.0,
  curveConfig: const CurveConfig(curve: Curves.easeIn, durationMs: 300),
  onComplete: () => _adapter.removeAt(index),
);
```

### ItemAnimator

包装 item widget，监听 `ItemAnimatorController` 的参数变化并执行动画。

```dart
ItemAnimator(
  itemId: itemId,
  paramsNotifier: _controller.listenAnimatorParams(itemId, index),
  layoutParamsListenable: _layoutManagerHolder.target!
      .listenLayoutParamsForPosition(index),
  onDispose: _controller.onItemUnmounted,
  child: YourItemWidget(),
)
```

### 动画配置

```dart
// 曲线动画
CurveConfig(curve: Curves.easeInOut, durationMs: 400)

// 弹簧动画
SpringConfig(stiffness: 200, damping: 22)
```

---

## 拖拽系统

### ItemDraggable

为 item 添加交叉轴方向的拖拽能力（列表横向滚动时支持上下拖拽）。

```dart
ItemDraggable(
  itemId: itemId,
  paramsNotifier: _controller.listenAnimatorParams(itemId, index),
  scrollDirection: Axis.horizontal,
  listener: this,  // implements/with ItemDragListener
  swipeThreshold: const SwipeThreshold(
    velocityThreshold: 800,
    offsetThreshold: 300,
  ),
  dragThreshold: const DragThreshold(
    min: -150,   // 向上最大位移
    max: 150,    // 向下最大位移
    dampingFraction: 0.5,  // 从 50% 处开始阻尼
  ),
  snapBackConfig: const CurveConfig(curve: Curves.easeOutBack, durationMs: 600),
  child: YourItemWidget(),
)
```

**ItemDragListener：**

```dart
class MyState extends State<MyWidget> with ItemDragListener {
  @override
  void onDragStart(String itemId) { /* 拖拽开始，可设置 topMostIndex */ }

  @override
  void onDragMove(String itemId, Offset offset) { /* 拖拽中 */ }

  @override
  bool onDragEnd(String itemId, DragResult result) {
    // 返回 true 表示消费事件
    // 返回 false 则强制执行 snapback（即使是 Swipe）
    switch (result) {
      case SnapBack(): return true;
      case Swipe(:final direction):
        // 处理滑动删除等逻辑
        return true;
    }
  }

  @override
  void onSnapBackEnd(String itemId) { /* snapback 动画结束，可还原 topMostIndex */ }
}
```

**DragThreshold 阻尼效果：**

接近阈值时自动施加 rubber band 阻尼，越接近阈值阻力越大，到达阈值后完全锁死。`dampingFraction` 控制阻尼起始位置（相对于阈值的比例）。

---

## 完整使用示例

```dart
class MyListPage extends StatefulWidget { ... }

class _MyListPageState extends State<MyListPage> with ItemDragListener {
  final _layoutManagerHolder = ServiceHolder<LayoutManager>();
  late ListAdapter<MyItem> _adapter;
  late ItemAnimatorController _controller;

  @override
  void initState() {
    super.initState();
    _adapter = ListAdapter<MyItem>(
      items: initialItems,
      idExtractor: (item) => item.id,
    );
    _controller = ItemAnimatorController(
      layoutManagerHolder: _layoutManagerHolder,
      curveConfig: const CurveConfig(curve: Curves.easeInOut, durationMs: 400),
    );
    _adapter.addListener(() => setState(() {}));
  }

  void _addItem(MyItem item) {
    _controller.performLayoutAnimations(adapter: _adapter, addIndexes: [0]);
    _adapter.addItem(item, index: 0);
  }

  void _reorder(List<MyItem> newItems) {
    final diff = _adapter.diffItems(newItems);
    _controller.performLayoutAnimations(
      adapter: _adapter,
      addIndexes: diff.addIndexes,
      removeIndexes: diff.removeIndexes,
      moveIndexes: diff.moveIndexes,
    );
    _adapter.applyDiff(newItems);
  }

  @override
  bool onDragEnd(String itemId, DragResult result) {
    if (result is Swipe) {
      final index = _adapter.findChildIndex(itemId);
      if (index != null) {
        _controller.performLayoutAnimations(adapter: _adapter, removeIndexes: [index]);
        _adapter.removeById(itemId);
      }
      return true;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutableListWidget(
      itemSize: const Size(100, 100),
      scrollDirection: Axis.horizontal,
      layoutAlgorithm: GridLayoutAlgorithm(scrollDirection: Axis.horizontal, spanCount: 1),
      layoutManagerHolder: _layoutManagerHolder,
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final itemId = _adapter.getItemId(index);
          return KeyedSubtree(
            key: ValueKey(itemId),
            child: ItemDraggable(
              itemId: itemId,
              paramsNotifier: _controller.listenAnimatorParams(itemId, index),
              scrollDirection: Axis.horizontal,
              listener: this,
              child: ItemAnimator(
                itemId: itemId,
                paramsNotifier: _controller.listenAnimatorParams(itemId, index),
                layoutParamsListenable: _layoutManagerHolder.target!
                    .listenLayoutParamsForPosition(index),
                onDispose: _controller.onItemUnmounted,
                child: MyItemWidget(_adapter.getItem(index)),
              ),
            ),
          );
        },
        childCount: _adapter.itemCount,
        findChildIndexCallback: (key) =>
            _adapter.findChildIndex((key as ValueKey<String>).value),
      ),
    );
  }
}
```
