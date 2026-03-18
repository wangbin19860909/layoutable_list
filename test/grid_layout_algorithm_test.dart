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
  Size itemSize = const Size(100, 100),
  int itemCount = 9,
  EdgeInsetsGeometry edgeSpacing = EdgeInsets.zero,
  Size itemSpacing = Size.zero,
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
    scrollDirection: algo.scrollDirection,
    edgeSpacing: edgeSpacing,
    itemSpacing: itemSpacing,
  );
}

void main() {
  group('GridLayoutAlgorithm - vertical', () {
    late GridLayoutAlgorithm algo;

    setUp(() {
      algo = GridLayoutAlgorithm(
        spanCount: 3,
        scrollDirection: Axis.vertical,
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
        edgeSpacing: EdgeInsets.zero,
        itemSpacing: Size.zero,
      );
      // 3 rows * 100 = 300
      expect(max, closeTo(300, 0.1));
    });

    test('computeMaxScrollOffset with 0 items', () {
      expect(
        algo.computeMaxScrollOffset(itemExtent: 100, itemCount: 0, viewportExtent: 300,
            edgeSpacing: EdgeInsets.zero, itemSpacing: Size.zero),
        0,
      );
    });

    test('getMinVisibleIndex at scrollOffset 0', () {
      final min = algo.getMinVisibleIndex(
        scrollOffset: 0,
        itemCount: 9,
        mainAxisExtent: 300,
        crossAxisExtent: 300,
        itemSize: const Size(100, 100),
        padding: EdgeInsets.zero,
        reverseLayout: false,
        cacheExtent: 0,
        textDirection: TextDirection.ltr,
        scrollDirection: Axis.vertical,
        edgeSpacing: EdgeInsets.zero,
        itemSpacing: Size.zero,
      );
      expect(min, 0);
    });

    test('getMaxVisibleIndex shows all items in viewport', () {
      final max = algo.getMaxVisibleIndex(
        scrollOffset: 0,
        itemCount: 9,
        mainAxisExtent: 300,
        crossAxisExtent: 300,
        itemSize: const Size(100, 100),
        padding: EdgeInsets.zero,
        reverseLayout: false,
        cacheExtent: 0,
        textDirection: TextDirection.ltr,
        scrollDirection: Axis.vertical,
        edgeSpacing: EdgeInsets.zero,
        itemSpacing: Size.zero,
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
      );
      final p0 = getParams(spacedAlgo, index: 0, crossAxisExtent: 200,
          itemSpacing: const Size(10, 0));
      final p2 = getParams(spacedAlgo, index: 2, crossAxisExtent: 200,
          itemSpacing: const Size(10, 0));
      expect(p2.rect.left - p0.rect.left, closeTo(110, 0.1));
    });
  });

  group('GridLayoutAlgorithm - mainAxisPadding', () {
    test('mainAxisPadding offsets first item', () {
      final algo = GridLayoutAlgorithm(
        spanCount: 1,
        scrollDirection: Axis.horizontal,
      );
      final p = getParams(algo, index: 0, crossAxisExtent: 100,
          edgeSpacing: const EdgeInsets.only(left: 20));
      expect(p.rect.left, closeTo(20, 0.1));
    });
  });

  group('GridLayoutAlgorithm - edgeSpacing', () {
    // ── mainAxisEdgeEnd 影响 computeMaxScrollOffset ──────────────────────

    test('vertical: edgeEnd is included in computeMaxScrollOffset', () {
      // edgeStart=10, edgeEnd=20, 3 rows * 100 = 300 → 10 + 300 + 20 = 330
      final algo = GridLayoutAlgorithm(spanCount: 3, scrollDirection: Axis.vertical);
      final max = algo.computeMaxScrollOffset(
        itemExtent: 100,
        itemCount: 9,
        viewportExtent: 300,
        edgeSpacing: const EdgeInsets.only(top: 10, bottom: 20),
        itemSpacing: Size.zero,
      );
      expect(max, closeTo(330, 0.1));
    });

    test('horizontal: edgeEnd is included in computeMaxScrollOffset', () {
      // edgeStart=10, edgeEnd=20, 3 cols * 100 = 300 → 10 + 300 + 20 = 330
      final algo = GridLayoutAlgorithm(spanCount: 2, scrollDirection: Axis.horizontal);
      final max = algo.computeMaxScrollOffset(
        itemExtent: 100,
        itemCount: 6,
        viewportExtent: 400,
        edgeSpacing: const EdgeInsets.only(left: 10, right: 20),
        itemSpacing: Size.zero,
      );
      expect(max, closeTo(330, 0.1));
    });

    // ── 滚到底时最后一个 item 距边缘 = edgeEnd ───────────────────────────

    test('vertical: last item bottom edge equals edgeEnd when scrolled to end', () {
      // viewportExtent=300, maxScroll=330, effectiveMax=30, scrollOffset=30
      // last row top = edgeStart + 2*100 - 30 = 10 + 200 - 30 = 180
      // last row bottom = 180 + 100 = 280, distance to viewport bottom = 300 - 280 = 20 = edgeEnd
      final algo = GridLayoutAlgorithm(spanCount: 3, scrollDirection: Axis.vertical);
      const edge = EdgeInsets.only(top: 10, bottom: 20);
      final maxScroll = algo.computeMaxScrollOffset(
        itemExtent: 100, itemCount: 9, viewportExtent: 300,
        edgeSpacing: edge, itemSpacing: Size.zero,
      );
      final scrollOffset = maxScroll - 300; // scroll to end
      final p = getParams(algo, index: 6, // first item of last row
        scrollOffset: scrollOffset,
        mainAxisExtent: 300,
        edgeSpacing: edge,
      );
      final bottomEdge = p.rect.bottom;
      expect(300 - bottomEdge, closeTo(20, 0.1)); // edgeEnd = 20
    });

    test('horizontal: last item right edge equals edgeEnd when scrolled to end', () {
      final algo = GridLayoutAlgorithm(spanCount: 2, scrollDirection: Axis.horizontal);
      const edge = EdgeInsets.only(left: 10, right: 20);
      // viewportExtent=200 so content(330) > viewport, can actually scroll
      final maxScroll = algo.computeMaxScrollOffset(
        itemExtent: 100, itemCount: 6, viewportExtent: 200,
        edgeSpacing: edge, itemSpacing: Size.zero,
      );
      final scrollOffset = maxScroll - 200; // effectiveMax = 330 - 200 = 130
      final p = getParams(algo, index: 4, // first item of last column
        scrollOffset: scrollOffset,
        mainAxisExtent: 200,
        crossAxisExtent: 200,
        edgeSpacing: edge,
      );
      expect(200 - p.rect.right, closeTo(20, 0.1)); // edgeEnd = 20
    });

    // ── crossAxisEdgeStart/End 影响交叉轴可用空间和 item 位置 ────────────

    test('horizontal: crossAxisEdgeStart offsets first row top', () {
      // edgeSpacing top=10 → crossEdgeStart=10 for horizontal scroll
      final algo = GridLayoutAlgorithm(spanCount: 2, scrollDirection: Axis.horizontal);
      final p = getParams(algo, index: 0,
        crossAxisExtent: 220,
        edgeSpacing: const EdgeInsets.only(top: 10, bottom: 10),
      );
      expect(p.rect.top, closeTo(10, 0.1));
    });

    test('horizontal: crossAxisEdgeEnd reduces available height', () {
      // containerHeight=220, crossEdgeStart=10, crossEdgeEnd=10 → available=200 → cellHeight=100
      final algo = GridLayoutAlgorithm(spanCount: 2, scrollDirection: Axis.horizontal);
      final p0 = getParams(algo, index: 0,
        crossAxisExtent: 220,
        edgeSpacing: const EdgeInsets.only(top: 10, bottom: 10),
      );
      final p1 = getParams(algo, index: 1,
        crossAxisExtent: 220,
        edgeSpacing: const EdgeInsets.only(top: 10, bottom: 10),
      );
      expect(p0.rect.height, closeTo(100, 0.1));
      expect(p1.rect.top, closeTo(110, 0.1)); // 10 + 100
    });

    test('vertical: crossAxisEdgeStart offsets first column left', () {
      // edgeSpacing left=12 → crossEdgeStart=12 for vertical scroll
      final algo = GridLayoutAlgorithm(spanCount: 3, scrollDirection: Axis.vertical);
      final p = getParams(algo, index: 0,
        mainAxisExtent: 312,
        edgeSpacing: const EdgeInsets.only(left: 12, right: 12),
      );
      expect(p.rect.left, closeTo(12, 0.1));
    });

    test('vertical: crossAxisEdgeEnd reduces available width', () {
      // containerWidth=312, crossEdgeStart=12, crossEdgeEnd=12 → available=288 → cellWidth=96
      final algo = GridLayoutAlgorithm(spanCount: 3, scrollDirection: Axis.vertical);
      final p = getParams(algo, index: 0,
        mainAxisExtent: 312,
        edgeSpacing: const EdgeInsets.only(left: 12, right: 12),
      );
      expect(p.rect.width, closeTo(96, 0.1));
    });
  });
}
