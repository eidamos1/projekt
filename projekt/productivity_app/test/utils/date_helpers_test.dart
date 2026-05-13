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
}
