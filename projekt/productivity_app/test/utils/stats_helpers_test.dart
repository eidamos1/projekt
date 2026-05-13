import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/models/task.dart';
import 'package:productivity_app/utils/stats_helpers.dart';

Task _t(String date, {bool completed = true}) => Task(
      id: 'x', title: 'x', type: TaskType.daily,
      date: date, xp: 10, coins: 5, code: '111111',
      completed: completed,
    );

void main() {
  group('tasksPerDay', () {
    test('counts only completed tasks', () {
      final result = tasksPerDay([
        _t('2026-05-12'),
        _t('2026-05-12'),
        _t('2026-05-12', completed: false),
        _t('2026-05-13'),
      ]);
      expect(result['2026-05-12'], 2);
      expect(result['2026-05-13'], 1);
    });

    test('returns empty map for empty input', () {
      expect(tasksPerDay([]), <String, int>{});
    });

    test('returns empty map when all uncompleted', () {
      final result = tasksPerDay([_t('2026-05-12', completed: false)]);
      expect(result, <String, int>{});
    });
  });
}
