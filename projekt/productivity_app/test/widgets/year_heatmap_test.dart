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

  group('YearHeatmap.cellsFromMondayThroughWeekOf', () {
    test('returns a multiple-of-7 cell count', () {
      final cells = YearHeatmap.cellsFromMondayThroughWeekOf(
        DateTime(2026, 4, 27), // Monday
        DateTime(2026, 5, 13), // Wednesday
      );
      expect(cells.length % 7, 0);
    });

    test('cells include today', () {
      final today = DateTime(2026, 5, 13);
      final cells = YearHeatmap.cellsFromMondayThroughWeekOf(
        DateTime(2026, 4, 27),
        today,
      );
      expect(
        cells.any((c) =>
            c.year == today.year &&
            c.month == today.month &&
            c.day == today.day),
        isTrue,
      );
    });

    test('cells[0] is the provided start Monday', () {
      final start = DateTime(2026, 4, 27); // Monday
      final cells = YearHeatmap.cellsFromMondayThroughWeekOf(
        start,
        DateTime(2026, 5, 13),
      );
      expect(cells.first, start);
      expect(cells.first.weekday, DateTime.monday);
    });

    test('cells.last is a Sunday (end of today\'s week)', () {
      for (final today in [
        DateTime(2026, 5, 13),
        DateTime(2026, 6, 7), // Sun
        DateTime(2026, 6, 1), // Mon
      ]) {
        final start = DateTime(2026, 4, 27);
        final cells = YearHeatmap.cellsFromMondayThroughWeekOf(start, today);
        expect(cells.last.weekday, DateTime.sunday,
            reason: 'cells.last should be Sunday for today=$today');
      }
    });

    test('spans exact days from start Monday to last Sunday of today\'s week',
        () {
      final start = DateTime(2026, 4, 27);
      final today = DateTime(2026, 5, 13); // Wed
      final cells = YearHeatmap.cellsFromMondayThroughWeekOf(start, today);
      // Wed 2026-05-13 → following Sunday = 2026-05-17. Span = 21 days.
      expect(cells.first, DateTime(2026, 4, 27));
      expect(cells.last, DateTime(2026, 5, 17));
      expect(cells.length, 21);
    });
  });
}
