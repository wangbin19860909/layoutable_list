import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_multi_window/recents/animator/list_adapter.dart';

void main() {
  group('ListAdapter', () {
    late ListAdapter<String> adapter;

    setUp(() {
      adapter = ListAdapter<String>(
        items: ['a', 'b', 'c'],
        idExtractor: (item) => item.hashCode,
      );
    });

    tearDown(() => adapter.dispose());

    test('itemCount reflects initial items', () {
      expect(adapter.itemCount, 3);
    });

    test('getItem returns correct item', () {
      expect(adapter.getItem(0), 'a');
      expect(adapter.getItem(2), 'c');
    });

    test('getItem throws on out of range', () {
      expect(() => adapter.getItem(-1), throwsRangeError);
      expect(() => adapter.getItem(3), throwsRangeError);
    });

    test('getItemId returns string id', () {
      expect(adapter.getItemId(0), 'a'.hashCode.toString());
    });

    test('findChildIndex returns correct index', () {
      expect(adapter.findChildIndex('a'.hashCode.toString()), 0);
      expect(adapter.findChildIndex('c'.hashCode.toString()), 2);
    });

    test('findChildIndex returns null for unknown id', () {
      expect(adapter.findChildIndex('unknown'), isNull);
    });

    test('addItem inserts at given index and updates count', () {
      adapter.addItem('x', index: 1);
      expect(adapter.itemCount, 4);
      expect(adapter.getItem(1), 'x');
      expect(adapter.getItem(2), 'b');
    });

    test('addItem at index 0 prepends', () {
      adapter.addItem('x', index: 0);
      expect(adapter.getItem(0), 'x');
      expect(adapter.getItem(1), 'a');
    });

    test('addItem beyond length clamps to end', () {
      adapter.addItem('x', index: 100);
      expect(adapter.getItem(3), 'x');
    });

    test('addItem updates index map', () {
      adapter.addItem('x', index: 0);
      expect(adapter.findChildIndex('x'.hashCode.toString()), 0);
      expect(adapter.findChildIndex('a'.hashCode.toString()), 1);
    });

    test('removeAt removes correct item', () {
      adapter.removeAt(1);
      expect(adapter.itemCount, 2);
      expect(adapter.getItem(0), 'a');
      expect(adapter.getItem(1), 'c');
    });

    test('removeAt updates index map', () {
      final bId = 'b'.hashCode.toString();
      final cId = 'c'.hashCode.toString();
      adapter.removeAt(1);
      expect(adapter.findChildIndex(bId), isNull);
      expect(adapter.findChildIndex(cId), 1);
    });

    test('removeAt throws on out of range', () {
      expect(() => adapter.removeAt(-1), throwsRangeError);
      expect(() => adapter.removeAt(3), throwsRangeError);
    });

    test('removeById removes by string id', () {
      final bId = 'b'.hashCode.toString();
      final result = adapter.removeById(bId);
      expect(result, isTrue);
      expect(adapter.itemCount, 2);
      expect(adapter.findChildIndex(bId), isNull);
    });

    test('removeById returns false for unknown id', () {
      expect(adapter.removeById('unknown'), isFalse);
      expect(adapter.itemCount, 3);
    });

    test('notifyListeners called on addItem', () {
      int callCount = 0;
      adapter.addListener(() => callCount++);
      adapter.addItem('x');
      expect(callCount, 1);
    });

    test('notifyListeners called on removeAt', () {
      int callCount = 0;
      adapter.addListener(() => callCount++);
      adapter.removeAt(0);
      expect(callCount, 1);
    });
  });
}
