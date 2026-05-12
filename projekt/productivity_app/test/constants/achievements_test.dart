import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/constants/achievements.dart';
import 'package:productivity_app/models/eval_context.dart';

import '../_achievement_fixtures.dart';

void main() {
  group('Achievements registry', () {
    test('byId returns matching achievement', () {
      final a = Achievements.byId('prvni_krok');
      expect(a, isNotNull);
      expect(a!.title, 'Prvni krok');
    });

    test('byId returns null for unknown id', () {
      expect(Achievements.byId('nonexistent'), isNull);
    });

    test('all ids are unique', () {
      final ids = Achievements.all.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('prvni_krok smoke predicate', () {
    final ach = Achievements.byId('prvni_krok')!;

    test('unlocks when totalCompletedTasks >= 1', () {
      final ctx = EvalContext(
        user: const UserSnapshot(xp: 0, level: 1, streak: 0, coins: 0),
        recentTasks: const [],
        habits: const [],
        alreadyUnlocked: const {},
        totalCompletedTasks: 1,
      );
      expect(ach.evaluate(ctx), isTrue);
    });

    test('does not unlock at 0 tasks', () {
      expect(ach.evaluate(EvalContext.empty()), isFalse);
    });
  });

  group('comeback_kid', () {
    final ach = Achievements.byId('comeback_kid');

    test('unlocks when a completed task has wasRejected=true', () {
      final ctx = buildContext(
        recentTasks: [buildTask(wasRejected: true, completed: true)],
      );
      expect(ach!.evaluate(ctx), isTrue);
    });

    test('does NOT unlock with completed but never rejected task', () {
      final ctx = buildContext(
        recentTasks: [buildTask(wasRejected: false, completed: true)],
      );
      expect(ach!.evaluate(ctx), isFalse);
    });
  });

  group('patecni_hrdina', () {
    final ach = Achievements.byId('patecni_hrdina');

    test('unlocks for 4 consecutive Fridays with habit task', () {
      // 2026-05-08, 2026-05-01, 2026-04-24, 2026-04-17 are consecutive Fridays.
      final friday1 = '2026-05-08';
      final friday2 = '2026-05-01';
      final friday3 = '2026-04-24';
      final friday4 = '2026-04-17';
      final ctx = buildContext(
        recentTasks: [
          buildTask(date: friday1, completedAt: '$friday1 18:00', habitId: 'h1'),
          buildTask(date: friday2, completedAt: '$friday2 18:00', habitId: 'h1'),
          buildTask(date: friday3, completedAt: '$friday3 18:00', habitId: 'h1'),
          buildTask(date: friday4, completedAt: '$friday4 18:00', habitId: 'h1'),
        ],
      );
      expect(ach!.evaluate(ctx), isTrue);
    });

    test('does NOT unlock with only 3 Fridays', () {
      final ctx = buildContext(
        recentTasks: [
          buildTask(date: '2026-05-08', habitId: 'h1'),
          buildTask(date: '2026-05-01', habitId: 'h1'),
          buildTask(date: '2026-04-24', habitId: 'h1'),
        ],
      );
      expect(ach!.evaluate(ctx), isFalse);
    });
  });
}
