import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/models/habit.dart';
import 'package:productivity_app/models/task.dart';

void main() {
  group('Habit.fromMap / toMap', () {
    test('roundtrips all fields', () {
      final h = Habit(
        id: 'h1',
        title: 'Beh',
        type: TaskType.daily,
        recurrence: RecurrenceType.weekdays,
        customDays: const [],
        startDate: '2026-04-16',
        active: true,
        streak: 5,
        longestStreak: 12,
        lastCompletedDate: '2026-04-15',
      );
      final back = Habit.fromMap('h1', h.toMap());
      expect(back.title, h.title);
      expect(back.type, h.type);
      expect(back.recurrence, h.recurrence);
      expect(back.streak, h.streak);
      expect(back.longestStreak, h.longestStreak);
      expect(back.lastCompletedDate, h.lastCompletedDate);
    });

    test('custom recurrence preserves customDays', () {
      final h = Habit(
        id: 'h1',
        title: 'Joga',
        type: TaskType.weekly,
        recurrence: RecurrenceType.custom,
        customDays: const [1, 3, 5],
        startDate: '2026-04-16',
        active: true,
      );
      final back = Habit.fromMap('h1', h.toMap());
      expect(back.customDays, [1, 3, 5]);
    });
  });

  group('Habit.expectedOn', () {
    final everyday = Habit(
      id: 'h1',
      title: 't',
      type: TaskType.daily,
      recurrence: RecurrenceType.everyday,
      customDays: const [],
      startDate: '2026-04-01',
      active: true,
    );
    final weekdays = everyday.copyWith(recurrence: RecurrenceType.weekdays);
    final custom135 = everyday.copyWith(
      recurrence: RecurrenceType.custom,
      customDays: const [1, 3, 5],
    );

    test('everyday matches all dates >= startDate', () {
      expect(everyday.expectedOn(DateTime(2026, 4, 16)), isTrue);
      expect(everyday.expectedOn(DateTime(2026, 4, 20)), isTrue);
    });

    test('everyday excludes dates < startDate', () {
      expect(everyday.expectedOn(DateTime(2026, 3, 31)), isFalse);
    });

    test('weekdays excludes Saturday and Sunday', () {
      // 2026-04-18 is Saturday, 2026-04-19 is Sunday
      expect(weekdays.expectedOn(DateTime(2026, 4, 17)), isTrue);  // Fri
      expect(weekdays.expectedOn(DateTime(2026, 4, 18)), isFalse); // Sat
      expect(weekdays.expectedOn(DateTime(2026, 4, 19)), isFalse); // Sun
      expect(weekdays.expectedOn(DateTime(2026, 4, 20)), isTrue);  // Mon
    });

    test('custom only matches selected weekdays', () {
      // Mon/Wed/Fri = 1/3/5
      expect(custom135.expectedOn(DateTime(2026, 4, 20)), isTrue);  // Mon
      expect(custom135.expectedOn(DateTime(2026, 4, 21)), isFalse); // Tue
      expect(custom135.expectedOn(DateTime(2026, 4, 22)), isTrue);  // Wed
    });

    test('inactive habit is never expected', () {
      final inactive = everyday.copyWith(active: false);
      expect(inactive.expectedOn(DateTime(2026, 4, 16)), isFalse);
    });
  });

  group('Habit.previousExpectedDay', () {
    test('weekdays on Monday returns prior Friday', () {
      // 2026-04-20 Po, 2026-04-17 Pa
      final weekdays = Habit(
        id: 'h', title: 't', type: TaskType.daily,
        recurrence: RecurrenceType.weekdays,
        startDate: '2026-04-01', active: true,
      );
      final prev = weekdays.previousExpectedDay(DateTime(2026, 4, 20));
      expect(prev, DateTime(2026, 4, 17));
    });

    test('everyday returns yesterday', () {
      final everyday = Habit(
        id: 'h', title: 't', type: TaskType.daily,
        recurrence: RecurrenceType.everyday,
        startDate: '2026-04-01', active: true,
      );
      final prev = everyday.previousExpectedDay(DateTime(2026, 4, 20));
      expect(prev, DateTime(2026, 4, 19));
    });

    test('returns null when no match within 14-day lookback', () {
      // Custom on Sunday only; ask for previous before startDate
      final sundayOnly = Habit(
        id: 'h', title: 't', type: TaskType.daily,
        recurrence: RecurrenceType.custom,
        customDays: const [7],
        startDate: '2026-04-20', active: true,
      );
      // 2026-04-21 je uterek, zpet 14 dni nenarazi na aktivni nedeli (startDate je 04-20 Po)
      // 2026-04-20 je Po, test: pred tim zadna nedele v ramci startDate
      final prev = sundayOnly.previousExpectedDay(DateTime(2026, 4, 21));
      expect(prev, isNull);
    });
  });
}
