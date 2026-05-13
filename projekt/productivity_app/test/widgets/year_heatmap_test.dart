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

    test('cells include today', () {
      final today = DateTime(2026, 5, 13);
      final cells = YearHeatmap.cellsFor(today);
      expect(
        cells.any((c) =>
            c.year == today.year &&
            c.month == today.month &&
            c.day == today.day),
        isTrue,
      );
    });

    test('cells[0] is always a Monday', () {
      for (final d in [
        DateTime(2026, 5, 13),  // Wed
        DateTime(2026, 1, 1),   // Thu
        DateTime(2025, 12, 31), // Wed
        DateTime(2026, 6, 1),   // Mon
        DateTime(2026, 6, 7),   // Sun
      ]) {
        final cells = YearHeatmap.cellsFor(d);
        expect(cells.first.weekday, DateTime.monday,
            reason: 'cells[0] should be Monday for today=$d');
      }
    });

    test('cells.last is a Sunday (end of today\'s week)', () {
      for (final d in [
        DateTime(2026, 5, 13),
        DateTime(2026, 6, 7),  // Sun — already end
        DateTime(2026, 6, 1),  // Mon
      ]) {
        final cells = YearHeatmap.cellsFor(d);
        expect(cells.last.weekday, DateTime.sunday,
            reason: 'cells.last should be Sunday for today=$d');
      }
    });

    test('first cell is approximately 53 weeks before end-of-week', () {
      final today = DateTime(2026, 5, 13);
      final cells = YearHeatmap.cellsFor(today);
      final diff = cells.last.difference(cells.first).inDays;
      expect(diff, 53 * 7 - 1);  // exactly 370 days span
    });
  });
}
