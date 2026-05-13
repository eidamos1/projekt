import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/models/habit.dart';
import 'package:productivity_app/models/task.dart';

List<DateTime> expandDates(Habit h, DateTime start, int days) {
  return List.generate(
          days,
          (i) => DateTime(start.year, start.month, start.day)
              .add(Duration(days: i)))
      .where(h.expectedOn)
      .toList();
}

void main() {
  final everyday = Habit(
    id: 'h',
    title: 't',
    type: TaskType.daily,
    recurrence: RecurrenceType.everyday,
    startDate: '2026-04-16',
    active: true,
  );

  test('everyday expands to all 30 days', () {
    final r = expandDates(everyday, DateTime(2026, 4, 16), 30);
    expect(r.length, 30);
  });

  test('weekdays expands to ~21-22 days of 30 (no weekends)', () {
    final weekdays = everyday.copyWith(recurrence: RecurrenceType.weekdays);
    final r = expandDates(weekdays, DateTime(2026, 4, 16), 30);
    expect(r.length, inInclusiveRange(20, 23));
    for (final d in r) {
      expect(d.weekday, lessThanOrEqualTo(5));
    }
  });

  test('custom Mon/Wed/Fri gives ~12-14 days in 30', () {
    final mwf = everyday.copyWith(
      recurrence: RecurrenceType.custom,
      customDays: const [1, 3, 5],
    );
    final r = expandDates(mwf, DateTime(2026, 4, 16), 30);
    expect(r.length, inInclusiveRange(12, 14));
    for (final d in r) {
      expect([1, 3, 5].contains(d.weekday), isTrue);
    }
  });
}
