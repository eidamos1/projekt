import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/utils/week_helpers.dart';

void main() {
  group('mondayOf', () {
    test('returns same date when given a Monday', () {
      // 2026-06-01 is a Monday
      final m = mondayOf(DateTime(2026, 6, 1));
      expect(m.year, 2026);
      expect(m.month, 6);
      expect(m.day, 1);
      expect(m.weekday, DateTime.monday);
    });

    test('returns previous Monday when given a Wednesday', () {
      // 2026-06-03 is a Wednesday -> Monday is 2026-06-01
      final m = mondayOf(DateTime(2026, 6, 3));
      expect(m.year, 2026);
      expect(m.month, 6);
      expect(m.day, 1);
      expect(m.weekday, DateTime.monday);
    });

    test('returns previous Monday when given a Sunday', () {
      // 2026-06-07 is a Sunday -> Monday is 2026-06-01
      final m = mondayOf(DateTime(2026, 6, 7));
      expect(m.year, 2026);
      expect(m.month, 6);
      expect(m.day, 1);
      expect(m.weekday, DateTime.monday);
    });

    test('crosses month boundary backward (2026-06-01 stays 2026-06-01)', () {
      final m = mondayOf(DateTime(2026, 6, 1));
      expect(m.year, 2026);
      expect(m.month, 6);
      expect(m.day, 1);
    });

    test('crosses month boundary backward (2026-05-31 Sunday -> 2026-05-25 Monday)', () {
      // 2026-05-31 is a Sunday -> Monday is 2026-05-25
      final m = mondayOf(DateTime(2026, 5, 31));
      expect(m.year, 2026);
      expect(m.month, 5);
      expect(m.day, 25);
      expect(m.weekday, DateTime.monday);
    });

    test('strips time-of-day to midnight', () {
      final m = mondayOf(DateTime(2026, 6, 3, 23, 59, 30, 500, 100));
      expect(m.hour, 0);
      expect(m.minute, 0);
      expect(m.second, 0);
      expect(m.millisecond, 0);
      expect(m.microsecond, 0);
    });

    test('handles year boundary', () {
      // 2026-01-01 is a Thursday -> Monday is 2025-12-29
      final m = mondayOf(DateTime(2026, 1, 1));
      expect(m.year, 2025);
      expect(m.month, 12);
      expect(m.day, 29);
      expect(m.weekday, DateTime.monday);
    });
  });

  group('mondayStringOf', () {
    test('returns yyyy-MM-dd format', () {
      final s = mondayStringOf(DateTime(2026, 6, 3));
      expect(s, '2026-06-01');
    });

    test('zero-pads single-digit months and days', () {
      // 2026-01-01 Thursday -> Monday 2025-12-29
      expect(mondayStringOf(DateTime(2026, 1, 1)), '2025-12-29');
      // 2026-03-02 Monday
      expect(mondayStringOf(DateTime(2026, 3, 2)), '2026-03-02');
    });
  });
}
