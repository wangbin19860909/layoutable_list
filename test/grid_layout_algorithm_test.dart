import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_multi_window/recents/algorithms/grid_layout_algorithm.dart';
import 'package:flutter_multi_window/recents/algorithms/layout_algorithm.dart';

// 辅助方法，减少重复参数
LayoutParams getParams(
  GridLayoutAlgorithm algo, {
  required int index,
  double scrollOffset = 0,
  double mainAxisExtent = 400,
  double crossAxisExtent = 600,
  double itemWidth = 100,
  double itemHeight = 100,
  int itemCount = 9,
}) {
  return algo.getLayoutParamsForPosition(
    index: index,
    scrollOffset: scrollOffset,
    mainAxisExtent: mainAxisExtent,
    crossAxisExtent: crossAxisExtent,
    itemWidth: itemWidth,
    itemHeight: itemHeight,
    itemExtent: algo.scrollDirection == Axis.vertical ? itemHeight : itemWidth,
    itemCount: itemCount,
    padding: EdgeInsets.zero,
    reverse: false,
    textDirection: TextDirection.ltr,
  );
}

void main() {
  group('GridLayoutAlgorithm - vertical', () {
    late GridLayoutAlgorithm algo;

    setUp(() {
      algo = GridLayoutAlgorithm(
        spanCount: 3,
        scrollDirection: Axis.vertical,
        mainAxisSpacing: 0,
        crossAxisSpacing: 0,
        mainAxisPadding: 0,
        crossAxisPadding: 0,
      );
    });

    test('first item is at top-left', () {
      final p = getParams(algo, index: 0);
      expect(p.rect.left, 0);
      expect(p.rect.top, 0);
    });

    test('second item is in second column', () {
      // mainAxisExtent=300 (container width for vertical scroll), 3 cols → each 100px
      final p = getParams(algo, index: 1, mainAxisExtent: 300, crossAxisExtent: 300);
      expect(p.rect.left, closeTo(100, 0.1));
      expect(p.rect.top, 0);
    });

    test('fourth item starts second row', () {
      final p = getParams(algo, index: 3, mainAxisExtent: 300, crossAxisExtent: 300);
      expect(p.rect.left, 0);
      expect(p.rect.top, closeTo(100, 0.1));
    });

    test('scrollOffset shifts items up', () {
      final p = getParams(algo, index: 0, scrollOffset: 50);
      expect(p.rect.top, closeTo(-50, 0.1));
    });

    test('computeMaxScrollOffset with 9 items, 3 rows', () {
      final max = algo.computeMaxScrollOffset(
        itemExtent: 100,
        itemCount: 9,
        viewportExtent: 300,
      );
      // 3 rows * 100 = 300
      expect(max, closeTo(300, 0.1));
    });

    test('computeMaxScrollOffset with 0 items', () {
      expect(
        algo.computeMaxScrollOffset(itemExtent: 100, itemCount: 0, viewportExtent: 300),
        0,
      );
    });

    test('getMinVisibleIndex at scrollOffset 0', () {
      final min = algo.getMinVisibleIndex(
        scrollOffset: 0,
        itemExtent: 100,
        itemCount: 9,
        mainAxisExtent: 300,
        crossAxisExtent: 300,
        itemWidth: 100,
        itemHeight: 100,
        padding: EdgeInsets.zero,
        reverse: false,
        cacheExtent: 0,
        textDirection: TextDirection.ltr,
      );
      expect(min, 0);
    });

    test('getMaxVisibleIndex shows all items in viewport', () {
      final max = algo.getMaxVisibleIndex(
        scrollOffset: 0,
        itemExtent: 100,
        itemCount: 9,
        mainAxisExtent: 300,
        crossAxisExtent: 300,
        itemWidth: 100,
        itemHeight: 100,
        padding: EdgeInsets.zero,
        reverse: false,
        cacheExtent: 0,
        textDirection: TextDirection.ltr,
      );
      expect(max, 8);
    });
  });

  group('GridLayoutAlgorithm - horizontal', () {
    late GridLayoutAlgorithm algo;

    setUp(() {
      algo = GridLayoutAlgorithm(
        spanCount: 2,
        scrollDirection: Axis.horizontal,
        mainAxisSpacing: 0,
        crossAxisSpacing: 0,
        mainAxisPadding: 0,
        crossAxisPadding: 0,
      );
    });

    test('first item is at top-left', () {
      final p = getParams(algo, index: 0, crossAxisExtent: 200);
      expect(p.rect.left, 0);
      expect(p.rect.top, 0);
    });

    test('second item is in second row', () {
      final p = getParams(algo, index: 1, crossAxisExtent: 200);
      expect(p.rect.left, 0);
      expect(p.rect.top, closeTo(100, 0.1));
    });

    test('third item starts second column', () {
      final p = getParams(algo, index: 2, crossAxisExtent: 200);
      expect(p.rect.left, closeTo(100, 0.1));
      expect(p.rect.top, 0);
    });

    test('scrollOffset shifts items left', () {
      final p = getParams(algo, index: 0, scrollOffset: 50, crossAxisExtent: 200);
      expect(p.rect.left, closeTo(-50, 0.1));
    });

    test('mainAxisSpacing is applied between columns', () {
      final spacedAlgo = GridLayoutAlgorithm(
        spanCount: 2,
        scrollDirection: Axis.horizontal,
        mainAxisSpacing: 10,
        crossAxisSpacing: 0,
        mainAxisPadding: 0,
        crossAxisPadding: 0,
      );
      final p0 = getParams(spacedAlgo, index: 0, crossAxisExtent: 200);
      final p2 = getParams(spacedAlgo, index: 2, crossAxisExtent: 200);
      expect(p2.rect.left - p0.rect.left, closeTo(110, 0.1));
    });
  });

  group('GridLayoutAlgorithm - mainAxisPadding', () {
    test('mainAxisPadding offsets first item', () {
      final algo = GridLayoutAlgorithm(
        spanCount: 1,
        scrollDirection: Axis.horizontal,
        mainAxisPadding: 20,
      );
      final p = getParams(algo, index: 0, crossAxisExtent: 100);
      expect(p.rect.left, closeTo(20, 0.1));
    });
  });
}
