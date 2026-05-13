import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/widgets/year_heatmap.dart';

void main() {
  group('YearHeatmap.intensityBucket', () {
    test('returns 0 for count 0', () {
      expect(YearHeatmap.intensityBucket(0), 0);
    });

    test('returns count for 1..3', () {
      expect(YearHeatmap.intensityBucket(1), 1);
      expect(YearHeatmap.intensityBucket(2), 2);
      expect(YearHeatmap.intensityBucket(3), 3);
    });

    test('returns 4 for 4+', () {
      expect(YearHeatmap.intensityBucket(4), 4);
      expect(YearHeatmap.intensityBucket(10), 4);
      expect(YearHeatmap.intensityBucket(100), 4);
    });
  });

  group('YearHeatmap.cellsFor', () {
    test('returns 53 weeks × 7 days = 371 cells', () {
      final cells = YearHeatmap.cellsFor(DateTime(2026, 5, 13));
      expect(cells.length, 53 * 7);
    });

    test('most recent cell is today', () {
      final today = DateTime(2026, 5, 13);
      final cells = YearHeatmap.cellsFor(today);
      expect(cells.last.year, today.year);
      expect(cells.last.month, today.month);
      expect(cells.last.day, today.day);
    });

    test('first cell is approximately 52 weeks ago', () {
      final today = DateTime(2026, 5, 13);
      final cells = YearHeatmap.cellsFor(today);
      final first = cells.first;
      final diff = today.difference(first).inDays;
      expect(diff, greaterThanOrEqualTo(52 * 7));
      expect(diff, lessThan(53 * 7));
    });
  });
}
