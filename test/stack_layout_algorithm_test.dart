import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_multi_window/layoutablelist/algorithms/stack_layout_algorithm.dart';
import 'package:flutter_multi_window/layoutablelist/algorithms/layout_algorithm.dart';

LayoutParams getParams(
  StackLayoutAlgorithm algo, {
  required int index,
  double scrollOffset = 0,
  double mainAxisExtent = 400,
  double crossAxisExtent = 600,
  Size itemSize = const Size(300, 500),
  int itemCount = 5,
}) {
  return algo.getLayoutParamsForPosition(
    index: index,
    scrollOffset: scrollOffset,
    mainAxisExtent: mainAxisExtent,
    crossAxisExtent: crossAxisExtent,
    itemSize: itemSize,
    itemCount: itemCount,
    padding: EdgeInsets.zero,
    reverseLayout: false,
    textDirection: TextDirection.ltr,
    scrollDirection: Axis.horizontal,
    edgeSpacing: EdgeInsets.zero,
    itemSpacing: Size.zero,
  );
}

void main() {
  late StackLayoutAlgorithm algo;

  setUp(() => algo = StackLayoutAlgorithm());

  group('computeMaxScrollOffset', () {
    test('returns 0 for empty list', () {
      expect(
        algo.computeMaxScrollOffset(itemExtent: 300, itemCount: 0, viewportExtent: 400,
            edgeSpacing: EdgeInsets.zero, itemSpacing: Size.zero),
        0,
      );
    });

    test('last item can scroll to viewport start', () {
      // (itemCount - 1) * itemExtent + viewportExtent
      final max = algo.computeMaxScrollOffset(
        itemExtent: 300,
        itemCount: 5,
        viewportExtent: 400,
        edgeSpacing: EdgeInsets.zero,
        itemSpacing: Size.zero,
      );
      expect(max, closeTo(4 * 300 + 400, 0.1));
    });
  });

  group('getLayoutParamsForPosition', () {
    test('scale is within valid range', () {
      for (int i = 0; i < 5; i++) {
        final p = getParams(algo, index: i);
        expect(p.scale, greaterThan(0));
        expect(p.scale, lessThanOrEqualTo(1.0));
      }
    });

    test('alpha is within 0..1', () {
      for (int i = 0; i < 5; i++) {
        final p = getParams(algo, index: i);
        expect(p.alpha, inInclusiveRange(0.0, 1.0));
      }
    });

    test('rect width and height are non-negative', () {
      for (int i = 0; i < 5; i++) {
        final p = getParams(algo, index: i);
        expect(p.rect.width, greaterThanOrEqualTo(0));
        expect(p.rect.height, greaterThanOrEqualTo(0));
      }
    });

    test('front item has higher scale than item behind it', () {
      // in stack layout, index 0 is the front card (highest scale)
      final front = getParams(algo, index: 0, scrollOffset: 0);
      final behind = getParams(algo, index: 4, scrollOffset: 0);
      expect(front.scale, greaterThan(behind.scale));
    });

    test('items far behind have low alpha', () {
      // at scrollOffset=0, item 4 is deep in the stack and should have low alpha
      final p = getParams(algo, index: 4, scrollOffset: 0);
      expect(p.alpha, lessThan(0.5));
    });

    test('dimming is within 0..0.5', () {
      for (int i = 0; i < 5; i++) {
        final p = getParams(algo, index: i);
        expect(p.dimming, inInclusiveRange(0.0, 0.5));
      }
    });
  });

  group('getMinVisibleIndex', () {
    test('returns 0 for empty list', () {
      expect(
        algo.getMinVisibleIndex(
          scrollOffset: 0, itemCount: 0,
          mainAxisExtent: 400, crossAxisExtent: 600,
          itemSize: const Size(300, 500),
          padding: EdgeInsets.zero, reverseLayout: false,
          cacheExtent: 0, textDirection: TextDirection.ltr,
          scrollDirection: Axis.horizontal,
          edgeSpacing: EdgeInsets.zero, itemSpacing: Size.zero,
        ),
        0,
      );
    });

    test('min index is >= 0', () {
      final min = algo.getMinVisibleIndex(
        scrollOffset: 300, itemCount: 5,
        mainAxisExtent: 400, crossAxisExtent: 600,
        itemSize: const Size(300, 500),
        padding: EdgeInsets.zero, reverseLayout: false,
        cacheExtent: 0, textDirection: TextDirection.ltr,
        scrollDirection: Axis.horizontal,
        edgeSpacing: EdgeInsets.zero, itemSpacing: Size.zero,
      );
      expect(min, greaterThanOrEqualTo(0));
    });
  });

  group('getMaxVisibleIndex', () {
    test('returns 0 for empty list', () {
      expect(
        algo.getMaxVisibleIndex(
          scrollOffset: 0, itemCount: 0,
          mainAxisExtent: 400, crossAxisExtent: 600,
          itemSize: const Size(300, 500),
          padding: EdgeInsets.zero, reverseLayout: false,
          cacheExtent: 0, textDirection: TextDirection.ltr,
          scrollDirection: Axis.horizontal,
          edgeSpacing: EdgeInsets.zero, itemSpacing: Size.zero,
        ),
        0,
      );
    });

    test('max index is <= itemCount - 1', () {
      final max = algo.getMaxVisibleIndex(
        scrollOffset: 0, itemCount: 5,
        mainAxisExtent: 400, crossAxisExtent: 600,
        itemSize: const Size(300, 500),
        padding: EdgeInsets.zero, reverseLayout: false,
        cacheExtent: 0, textDirection: TextDirection.ltr,
        scrollDirection: Axis.horizontal,
        edgeSpacing: EdgeInsets.zero, itemSpacing: Size.zero,
      );
      expect(max, lessThanOrEqualTo(4));
    });
  });
}
