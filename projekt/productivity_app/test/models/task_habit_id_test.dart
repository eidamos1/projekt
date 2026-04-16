import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/models/task.dart';

void main() {
  test('Task.fromMap reads habitId when present', () {
    final t = Task.fromMap('t1', {
      'title': 'A',
      'type': 'daily',
      'date': '2026-04-16',
      'xp': 10,
      'coins': 5,
      'code': '111111',
      'habitId': 'h-xyz',
    });
    expect(t.habitId, 'h-xyz');
  });

  test('Task.fromMap defaults habitId to null when absent', () {
    final t = Task.fromMap('t1', {
      'title': 'A',
      'type': 'daily',
      'date': '2026-04-16',
      'xp': 10,
      'coins': 5,
      'code': '111111',
    });
    expect(t.habitId, isNull);
  });

  test('Task.toMap includes habitId', () {
    final t = Task(
      id: 't1', title: 'A', type: TaskType.daily, date: '2026-04-16',
      xp: 10, coins: 5, code: '111111', habitId: 'h-xyz',
    );
    expect(t.toMap()['habitId'], 'h-xyz');
  });
}
