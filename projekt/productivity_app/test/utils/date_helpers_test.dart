import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/utils/date_helpers.dart';

void main() {
  group('parseFlexibleTimestamp', () {
    test('parses date-only string', () {
      final d = parseFlexibleTimestamp('2026-05-12');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.day, 12);
      expect(d.hour, 0);
    });

    test('parses date+time string', () {
      final d = parseFlexibleTimestamp('2026-05-12 23:45');
      expect(d, isNotNull);
      expect(d!.hour, 23);
      expect(d.minute, 45);
    });

    test('returns null for malformed input', () {
      expect(parseFlexibleTimestamp('garbage'), isNull);
      expect(parseFlexibleTimestamp(null), isNull);
    });
  });

  group('hourOf', () {
    test('extracts hour from full timestamp', () {
      expect(hourOf('2026-05-12 23:45'), 23);
    });

    test('returns null for date-only string', () {
      expect(hourOf('2026-05-12'), isNull);
    });

    test('returns null for null', () {
      expect(hourOf(null), isNull);
    });
  });

  group('nowMinuteString', () {
    test('returns 16-character yyyy-MM-dd HH:mm format', () {
      final s = nowMinuteString();
      expect(s.length, 16);
      // Roughly: 4 digits, dash, 2 digits, dash, 2 digits, space, 2 digits, colon, 2 digits
      expect(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$').hasMatch(s), isTrue);
    });
  });

  group('relativeTimeCs', () {
    final now = DateTime(2026, 5, 27, 14, 30);

    test('< 1 minute ago → "Právě teď"', () {
      expect(relativeTimeCs('2026-05-27 14:30', now: now), 'Právě teď');
    });

    test('minutes ago', () {
      expect(relativeTimeCs('2026-05-27 14:25', now: now), 'Před 5 min.');
      expect(relativeTimeCs('2026-05-27 13:45', now: now), 'Před 45 min.');
    });

    test('hours ago (same day)', () {
      expect(relativeTimeCs('2026-05-27 10:30', now: now), 'Před 4 hod.');
    });

    test('yesterday', () {
      expect(relativeTimeCs('2026-05-26 14:30', now: now), 'Včera');
    });

    test('days ago (2-6 days)', () {
      expect(relativeTimeCs('2026-05-25 12:00', now: now), 'Před 2 dny');
      expect(relativeTimeCs('2026-05-22 12:00', now: now), 'Před 5 dny');
    });

    test('a week+ ago', () {
      expect(relativeTimeCs('2026-05-20 14:30', now: now), 'Před týdnem');
      expect(relativeTimeCs('2026-05-13 14:30', now: now), 'Před 2 týdny');
    });

    test('older than 30 days → date', () {
      expect(relativeTimeCs('2026-04-01 12:00', now: now), '2026-04-01');
    });

    test('future timestamp → date (clock skew safety)', () {
      expect(relativeTimeCs('2026-06-01 12:00', now: now), '2026-06-01');
    });

    test('malformed input → returns raw', () {
      expect(relativeTimeCs('not a date', now: now), 'not a date');
    });
  });
}
