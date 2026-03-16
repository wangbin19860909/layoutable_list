import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_multi_window/recents/animator/item_animator_controller.dart';
import 'package:flutter_multi_window/recents/animator/list_adapter.dart';
import 'package:flutter_multi_window/recents/animator/item_animator.dart';
import 'package:flutter_multi_window/recents/algorithms/layout_algorithm.dart';
import 'package:flutter_multi_window/recents/layoutable_list_widget.dart';
import 'package:flutter_multi_window/service_holder.dart';

/// Mock LayoutManager — 简单的网格布局，每个 item 宽100，横向排列
class MockLayoutManager implements LayoutManager {
  final double _itemExtent;
  final double _viewportExtent;
  double _scrollOffset;

  MockLayoutManager({
    double itemExtent = 100,
    double viewportExtent = 400,
    double scrollOffset = 0,
  })  : _itemExtent = itemExtent,
        _viewportExtent = viewportExtent,
        _scrollOffset = scrollOffset;

  @override
  double get scrollOffset => _scrollOffset;

  @override
  double get viewportMainAxisExtent => _viewportExtent;

  @override
  double get itemExtent => _itemExtent;

  @override
  int get itemCount => 0;

  @override
  double getMaxScrollOffset(int itemCount) {
    return itemCount * _itemExtent;
  }

  @override
  LayoutParams getLayoutParamsForPosition({
    required int index,
    double? scrollOffset,
    double? containerWidth,
    double? containerHeight,
    double? itemWidth,
    double? itemHeight,
    int? itemCount,
    EdgeInsetsGeometry? padding,
    bool? reverseLayout,
  }) {
    final offset = scrollOffset ?? _scrollOffset;
    final left = index * _itemExtent - offset;
    return LayoutParams(
      rect: Rect.fromLTWH(left, 0, _itemExtent, _itemExtent),
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
      final notifier = controller.listenAnimatorParams('a');
      expect(notifier, isNotNull);
      expect(notifier.value.offset, Offset.zero);
    });

    test('returns same notifier on subsequent calls', () {
      final n1 = controller.listenAnimatorParams('a');
      final n2 = controller.listenAnimatorParams('a');
      expect(identical(n1, n2), isTrue);
    });
  });

  group('onItemUnmounted', () {
    test('resets params to default', () {
      final notifier = controller.listenAnimatorParams('a');
      notifier.value = ItemAnimatorParams(
        offset: const Offset(50, 0),
        toOffset: Offset.zero,
        scale: 1.0,
        alpha: 1.0,
      );
      controller.onItemUnmounted('a');
      expect(controller.listenAnimatorParams('a').value.offset, Offset.zero);
    });

    test('no-op for unknown id', () {
      expect(() => controller.onItemUnmounted('unknown'), returnsNormally);
    });
  });

  group('performItemAnimation', () {
    test('sets params immediately', () {
      final params = ItemAnimatorParams(
        offset: const Offset(100, 0),
        toOffset: Offset.zero,
        scale: 0.8,
        alpha: 0.5,
      );
      controller.performItemAnimation('a', params);
      expect(controller.listenAnimatorParams('a').value.offset, const Offset(100, 0));
      expect(controller.listenAnimatorParams('a').value.scale, 0.8);
    });
  });

  group('commit', () {
    test('notifies listeners', () {
      int callCount = 0;
      controller.addListener(() => callCount++);
      controller.commit();
      expect(callCount, 1);
    });
  });

  group('prepareLayoutAnimations - add', () {
    test('existing items get offset when new item inserted before them', () {
      // items: ['a', 'b', 'c'] at index 0,1,2 → each at x=0,100,200
      // add at index 0 → 'a' moves from index 0 to index 1
      // old pos of 'a' = 0, new pos = 100 → offset = 0 - 100 = -100
      final adapter = makeAdapter(['a', 'b', 'c']);

      // register notifiers with fake listeners
      final nA = controller.listenAnimatorParams('a'.hashCode.toString());
      final nB = controller.listenAnimatorParams('b'.hashCode.toString());
      nA.addListener(() {});
      nB.addListener(() {});

      controller.performLayoutAnimations(adapter: adapter, addIndexes: [0]);

      expect(nA.value.offset.dx, closeTo(-100, 0.1));
      expect(nB.value.offset.dx, closeTo(-100, 0.1));

      adapter.dispose();
    });

    test('items after insert index are shifted, items before are not', () {
      // items: ['a', 'b', 'c'] → add at index 1
      // 'a' stays at index 0 → no shift
      // 'b' moves 0→1, 'c' moves 1→2 → but new item at 1 pushes them to 2,3
      final adapter = makeAdapter(['a', 'b', 'c']);

      final nA = controller.listenAnimatorParams('a'.hashCode.toString());
      final nB = controller.listenAnimatorParams('b'.hashCode.toString());
      nA.addListener(() {});
      nB.addListener(() {});

      controller.performLayoutAnimations(adapter: adapter, addIndexes: [1]);

      // 'a' stays at index 0 → old=0, new=0 → offset ~0, skipped
      expect(nA.value.offset, Offset.zero);
      // 'b' moves from index 1 to index 2 → old x=100, new x=200 → offset=-100
      expect(nB.value.offset.dx, closeTo(-100, 0.1));

      adapter.dispose();
    });
  });

  group('prepareLayoutAnimations - remove', () {
    test('items after removed index shift forward', () {
      // items: ['a', 'b', 'c'] → remove index 0 ('a')
      // 'b' moves from index 1 to index 0 → old x=100, new x=0 → offset=100
      final adapter = makeAdapter(['a', 'b', 'c']);

      final nB = controller.listenAnimatorParams('b'.hashCode.toString());
      final nC = controller.listenAnimatorParams('c'.hashCode.toString());
      nB.addListener(() {});
      nC.addListener(() {});

      controller.performLayoutAnimations(adapter: adapter, removeIndexes: [0]);

      expect(nB.value.offset.dx, closeTo(100, 0.1));
      expect(nC.value.offset.dx, closeTo(100, 0.1));

      adapter.dispose();
    });

    test('removed item itself is skipped', () {
      final adapter = makeAdapter(['a', 'b']);

      final nA = controller.listenAnimatorParams('a'.hashCode.toString());
      nA.addListener(() {});

      controller.performLayoutAnimations(adapter: adapter, removeIndexes: [0]);

      // 'a' is being removed, should not get animation params
      expect(nA.value.offset, Offset.zero);

      adapter.dispose();
    });
  });
}
