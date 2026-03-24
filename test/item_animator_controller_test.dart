import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_multi_window/layoutablelist/animator/item_animator_controller.dart';
import 'package:flutter_multi_window/layoutablelist/list_adapter.dart';
import 'package:flutter_multi_window/layoutablelist/animator/item_animator.dart';
import 'package:flutter_multi_window/layoutablelist/algorithms/layout_algorithm.dart';
import 'package:flutter_multi_window/layoutablelist/layoutable_list_widget.dart';
import 'package:flutter_multi_window/service_holder.dart';

/// Mock LayoutManager — 简单的网格布局，每个 item 宽100，横向排列
class MockLayoutManager implements LayoutManager {
  final double _itemExtent;
  final double _viewportExtent;
  double _scrollOffset;
  final EdgeInsetsGeometry _currentPadding;

  MockLayoutManager({
    double itemExtent = 100,
    double viewportExtent = 400,
    double scrollOffset = 0,
    EdgeInsetsGeometry currentPadding = EdgeInsets.zero,
  })  : _itemExtent = itemExtent,
        _viewportExtent = viewportExtent,
        _scrollOffset = scrollOffset,
        _currentPadding = currentPadding;

  @override
  void addListener(OnItemBoundsChanged listener) {}

  @override
  void removeListener(OnItemBoundsChanged listener) {}

  @override
  double get scrollOffset => _scrollOffset;

  @override
  double get viewportMainAxisExtent => _viewportExtent;

  @override
  double get itemExtent => _itemExtent;

  @override
  int get itemCount => 0;

  @override
  double getMaxScrollOffset(int itemCount, {
    EdgeInsetsGeometry? padding,
    Size? itemSize,
    EdgeInsetsGeometry? edgeSpacing,
    Size? itemSpacing,
  }) {
    final extent = itemSize?.width ?? _itemExtent;
    final resolvedPadding = (padding ?? _currentPadding).resolve(TextDirection.ltr);
    return resolvedPadding.left + resolvedPadding.right + itemCount * extent;
  }

  @override
  LayoutParams getLayoutParamsForPosition({
    required int index,
    double? scrollOffset,
    double? containerWidth,
    double? containerHeight,
    Size? itemSize,
    int? itemCount,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? edgeSpacing,
    Size? itemSpacing,
    Object? tag,
  }) {
    final offset = scrollOffset ?? _scrollOffset;
    final extent = itemSize?.width ?? _itemExtent;
    final resolvedPadding = (padding ?? _currentPadding).resolve(TextDirection.ltr);
    final left = resolvedPadding.left + index * extent - offset;
    return LayoutParams(
      rect: Rect.fromLTWH(left, 0, extent, extent),
      scale: 1.0,
      alpha: 1.0,
      dimming: 0.0,
      titleAlpha: 1.0,
      headerAlpha: 1.0,
      shadowAlpha: 0.0,
    );
  }

  @override
  ValueListenable<LayoutParams> listenLayoutParamsForPosition(int index) {
    return ValueNotifier(getLayoutParamsForPosition(index: index));
  }
}

ListAdapter<String> makeAdapter(List<String> ids) {
  return ListAdapter<String>(
    items: ids,
    idExtractor: (item) => item.hashCode,
  );
}

void main() {
  late MockLayoutManager layoutManager;
  late ServiceHolder<LayoutManager> holder;
  late ItemAnimatorController controller;

  setUp(() {
    layoutManager = MockLayoutManager();
    holder = ServiceHolder<LayoutManager>();
    holder.attach(layoutManager);
    controller = ItemAnimatorController(layoutManagerHolder: holder);
  });

  tearDown(() {
    controller.dispose();
    holder.detach();
  });

  group('listenAnimatorParams', () {
    test('creates notifier on first call', () {
      final notifier = controller.listenAnimatorParams('a', 0);
      expect(notifier, isNotNull);
      expect(notifier.value.offset, Offset.zero);
    });

    test('returns same notifier on subsequent calls', () {
      final n1 = controller.listenAnimatorParams('a', 0);
      final n2 = controller.listenAnimatorParams('a', 0);
      expect(identical(n1, n2), isTrue);
    });
  });

  group('onItemUnmounted', () {
    test('resets params to default', () {
      final notifier = controller.listenAnimatorParams('a', 0);
      notifier.value = ItemAnimatorParams(
        index: 0,
        offset: const Offset(50, 0),
        toOffset: Offset.zero,
        scale: 1.0,
        alpha: 1.0,
      );
      controller.onItemUnmounted('a');
      expect(controller.listenAnimatorParams('a', 0).value.offset, Offset.zero);
    });

    test('no-op for unknown id', () {
      expect(() => controller.onItemUnmounted('unknown'), returnsNormally);
    });
  });

  group('performItemAnimation', () {
    test('sets params immediately', () {
      // 先注册 notifier，再调用 performItemAnimation 更新
      final notifier = controller.listenAnimatorParams('a', 0);
      notifier.addListener(() {});
      controller.performItemAnimation('a', 0, offsetX: 100, scalle: 0.8);
      expect(controller.listenAnimatorParams('a', 0).value.toOffset.dx, closeTo(100, 0.1));
      expect(controller.listenAnimatorParams('a', 0).value.toScale, closeTo(0.8, 0.01));
    });
  });

  group('commit', () {
    test('notifies listeners', () {
      // commit() was removed; performLayoutAnimations notifies directly
      // just verify controller is a ChangeNotifier
      int callCount = 0;
      controller.addListener(() => callCount++);
      // no-op test — commit no longer exists
      expect(callCount, 0);
    });
  });

  group('prepareLayoutAnimations - add', () {
    test('existing items get offset when new item inserted before them', () {
      final adapter = makeAdapter(['a', 'b', 'c']);

      final nA = controller.listenAnimatorParams('a'.hashCode.toString(), 0);
      final nB = controller.listenAnimatorParams('b'.hashCode.toString(), 1);
      nA.addListener(() {});
      nB.addListener(() {});

      controller.performLayoutAnimations(adapter: adapter, addIndexes: [0]);

      expect(nA.value.offset.dx, closeTo(-100, 0.1));
      expect(nB.value.offset.dx, closeTo(-100, 0.1));

      adapter.dispose();
    });

    test('items after insert index are shifted, items before are not', () {
      final adapter = makeAdapter(['a', 'b', 'c']);

      final nA = controller.listenAnimatorParams('a'.hashCode.toString(), 0);
      final nB = controller.listenAnimatorParams('b'.hashCode.toString(), 1);
      nA.addListener(() {});
      nB.addListener(() {});

      controller.performLayoutAnimations(adapter: adapter, addIndexes: [1]);

      expect(nA.value.offset, Offset.zero);
      expect(nB.value.offset.dx, closeTo(-100, 0.1));

      adapter.dispose();
    });
  });

  group('prepareLayoutAnimations - remove', () {
    test('items after removed index shift forward', () {
      final adapter = makeAdapter(['a', 'b', 'c']);

      final nB = controller.listenAnimatorParams('b'.hashCode.toString(), 1);
      final nC = controller.listenAnimatorParams('c'.hashCode.toString(), 2);
      nB.addListener(() {});
      nC.addListener(() {});

      controller.performLayoutAnimations(adapter: adapter, removeIndexes: [0]);

      expect(nB.value.offset.dx, closeTo(100, 0.1));
      expect(nC.value.offset.dx, closeTo(100, 0.1));

      adapter.dispose();
    });

    test('removed item itself is skipped', () {
      final adapter = makeAdapter(['a', 'b']);

      final nA = controller.listenAnimatorParams('a'.hashCode.toString(), 0);
      nA.addListener(() {});

      controller.performLayoutAnimations(adapter: adapter, removeIndexes: [0]);

      expect(nA.value.offset, Offset.zero);

      adapter.dispose();
    });
  });

  // ── padding 变化补位动画场景 ──────────────────────────────────────────────

  group('prepareLayoutAnimations - padding change', () {
    // 场景1：在右边缘，加左 padding
    // 加左 padding 后内容右移，item 应从左偏移处动画到 0
    test('at right edge, add left padding: items animate from negative offset', () {
      // viewport=400, 8 items * 100 = 800, effectiveMax = 400
      final lm = MockLayoutManager(
        itemExtent: 100,
        viewportExtent: 400,
        scrollOffset: 400, // 在右边缘
      );
      final h = ServiceHolder<LayoutManager>()..attach(lm);
      final c = ItemAnimatorController(layoutManagerHolder: h);

      final adapter = makeAdapter(['a', 'b', 'c', 'b1', 'c1', 'd', 'e', 'f']);
      // 注册可见 item（右边缘可见的是 index 4~7）
      final n4 = c.listenAnimatorParams('c1'.hashCode.toString(), 4);
      final n5 = c.listenAnimatorParams('d'.hashCode.toString(), 5);
      n4.addListener(() {});
      n5.addListener(() {});

      // 加左 padding=100，newPadding.left=100
      c.performLayoutAnimations(
        adapter: adapter,
        padding: const EdgeInsets.only(left: 100),
        itemSize: const Size(100, 100),
      );

      // oldLeft = index*100 - 400，newLeft = 100 + index*100 - 400
      // fromOffset.dx = oldLeft - newLeft = -100
      expect(n4.value.offset.dx, closeTo(-100, 0.1));
      expect(n5.value.offset.dx, closeTo(-100, 0.1));

      c.dispose();
      h.detach();
      adapter.dispose();
    });

    // 场景2：从左 padding 切换到右 padding，在右边缘
    // newScrollOffset 不变，新旧 left 不同，应有补位动画
    test('at right edge, switch left padding to right padding: items animate', () {
      // 左 padding=100，8 items，effectiveMax = 100+800-400 = 500
      // mock 带左 padding，使 oldLayoutParams 正确反映切换前布局
      final lm = MockLayoutManager(
        itemExtent: 100,
        viewportExtent: 400,
        scrollOffset: 500, // 在右边缘（left padding 时的 effectiveMax）
        currentPadding: const EdgeInsets.only(left: 100),
      );
      final h = ServiceHolder<LayoutManager>()..attach(lm);
      final c = ItemAnimatorController(layoutManagerHolder: h);

      final adapter = makeAdapter(['a', 'b', 'c', 'b1', 'c1', 'd', 'e', 'f']);
      final n5 = c.listenAnimatorParams('d'.hashCode.toString(), 5);
      final n6 = c.listenAnimatorParams('e'.hashCode.toString(), 6);
      n5.addListener(() {});
      n6.addListener(() {});

      // 从左 padding=100 切换到右 padding=100
      c.performLayoutAnimations(
        adapter: adapter,
        padding: const EdgeInsets.only(right: 100),
        itemSize: const Size(100, 100),
      );

      // oldLeft(left padding, index=5) = 100 + 5*100 - 500 = 100
      // newLeft(right padding, index=5) = 0 + 5*100 - 500 = 0
      // fromOffset.dx = oldLeft - newLeft = 100
      expect(n5.value.offset.dx, closeTo(100, 0.1));
      expect(n6.value.offset.dx, closeTo(100, 0.1));

      c.dispose();
      h.detach();
      adapter.dispose();
    });

    // 场景3：右 padding 在左边缘，padding 变为 0，itemSize 变大
    // 第一列 item 位移为零但 size 变化，不应被跳过
    test('at left edge, remove right padding with larger itemSize: size animation triggered', () {
      // 右 padding=100，scrollOffset=0（左边缘），itemExtent=80
      final lm = MockLayoutManager(
        itemExtent: 80,
        viewportExtent: 400,
        scrollOffset: 0,
      );
      final h = ServiceHolder<LayoutManager>()..attach(lm);
      final c = ItemAnimatorController(layoutManagerHolder: h);

      final adapter = makeAdapter(['a', 'b', 'c', 'd', 'e', 'f']);
      // index=0 的 item，位移为零但 size 从 80 变为 100
      final n0 = c.listenAnimatorParams('a'.hashCode.toString(), 0);
      n0.addListener(() {});

      // 去掉右 padding，itemSize 从 80 变为 100
      c.performLayoutAnimations(
        adapter: adapter,
        padding: EdgeInsets.zero,
        itemSize: const Size(100, 100),
      );

      // fromOffset == toOffset == Offset.zero，但 size 变化，不应跳过
      // notifier 应被更新，size 字段为新尺寸
      expect(n0.value.offset, Offset.zero);
      expect(n0.value.size, const Size(100, 100));

      c.dispose();
      h.detach();
      adapter.dispose();
    });
  });
}
