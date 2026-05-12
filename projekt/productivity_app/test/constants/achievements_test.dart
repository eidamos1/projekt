import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/constants/achievements.dart';
import 'package:productivity_app/models/eval_context.dart';
import 'package:productivity_app/models/task.dart';

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

  group('pulnocni_zachrana', () {
    final ach = Achievements.byId('pulnocni_zachrana');

    test('unlocks at hour 23', () {
      final ctx = buildContext(
        recentTasks: [buildTask(completedAt: '2026-05-12 23:45')],
      );
      expect(ach!.evaluate(ctx), isTrue);
    });

    test('does NOT unlock at hour 22', () {
      final ctx = buildContext(
        recentTasks: [buildTask(completedAt: '2026-05-12 22:59')],
      );
      expect(ach!.evaluate(ctx), isFalse);
    });

    test('skips legacy date-only completedAt', () {
      final ctx = buildContext(
        recentTasks: [buildTask(completedAt: '2026-05-12')],
      );
      expect(ach!.evaluate(ctx), isFalse);
    });
  });

  group('rano_je_moudrejsi', () {
    final ach = Achievements.byId('rano_je_moudrejsi');

    test('unlocks before 7:00', () {
      final ctx = buildContext(
        recentTasks: [buildTask(completedAt: '2026-05-12 06:30')],
      );
      expect(ach!.evaluate(ctx), isTrue);
    });

    test('does NOT unlock at 7:00', () {
      final ctx = buildContext(
        recentTasks: [buildTask(completedAt: '2026-05-12 07:00')],
      );
      expect(ach!.evaluate(ctx), isFalse);
    });

    test('skips legacy date-only completedAt', () {
      final ctx = buildContext(
        recentTasks: [buildTask(completedAt: '2026-05-12')],
      );
      expect(ach!.evaluate(ctx), isFalse);
    });
  });

  group('bourak', () {
    final ach = Achievements.byId('bourak');

    test('unlocks with 3 tasks on same date', () {
      final ctx = buildContext(
        recentTasks: [
          buildTask(id: 'a', date: '2026-05-12'),
          buildTask(id: 'b', date: '2026-05-12'),
          buildTask(id: 'c', date: '2026-05-12'),
        ],
      );
      expect(ach!.evaluate(ctx), isTrue);
    });

    test('does NOT unlock with 2 same-day + scattered other days', () {
      final ctx = buildContext(
        recentTasks: [
          buildTask(id: 'a', date: '2026-05-12'),
          buildTask(id: 'b', date: '2026-05-12'),
          buildTask(id: 'c', date: '2026-05-11'),
          buildTask(id: 'd', date: '2026-05-10'),
          buildTask(id: 'e', date: '2026-05-09'),
          buildTask(id: 'f', date: '2026-05-08'),
        ],
      );
      expect(ach!.evaluate(ctx), isFalse);
    });
  });

  group('hat_trick', () {
    final ach = Achievements.byId('hat_trick');

    test('unlocks with daily+weekly+monthly on same date', () {
      final ctx = buildContext(
        recentTasks: [
          buildTask(id: 'd', date: '2026-05-12', type: TaskType.daily),
          buildTask(id: 'w', date: '2026-05-12', type: TaskType.weekly),
          buildTask(id: 'm', date: '2026-05-12', type: TaskType.monthly),
        ],
      );
      expect(ach!.evaluate(ctx), isTrue);
    });

    test('does NOT unlock with only daily+weekly on same date', () {
      final ctx = buildContext(
        recentTasks: [
          buildTask(id: 'd', date: '2026-05-12', type: TaskType.daily),
          buildTask(id: 'w', date: '2026-05-12', type: TaskType.weekly),
          buildTask(id: 'm', date: '2026-05-11', type: TaskType.monthly),
        ],
      );
      expect(ach!.evaluate(ctx), isFalse);
    });
  });

  group('nedelni_klid', () {
    final ach = Achievements.byId('nedelni_klid');

    test('unlocks for 4 consecutive Sundays with habit task', () {
      final sun1 = '2026-05-10';
      final sun2 = '2026-05-03';
      final sun3 = '2026-04-26';
      final sun4 = '2026-04-19';
      final ctx = buildContext(
        recentTasks: [
          buildTask(date: sun1, habitId: 'h1'),
          buildTask(date: sun2, habitId: 'h1'),
          buildTask(date: sun3, habitId: 'h1'),
          buildTask(date: sun4, habitId: 'h1'),
        ],
      );
      expect(ach!.evaluate(ctx), isTrue);
    });

    test('does NOT unlock with only 3 Sundays', () {
      final ctx = buildContext(
        recentTasks: [
          buildTask(date: '2026-05-10', habitId: 'h1'),
          buildTask(date: '2026-05-03', habitId: 'h1'),
          buildTask(date: '2026-04-26', habitId: 'h1'),
        ],
      );
      expect(ach!.evaluate(ctx), isFalse);
    });
  });

  group('univerzal', () {
    final ach = Achievements.byId('univerzal');

    test('unlocks with 3 distinct categories on same date', () {
      final ctx = buildContext(
        recentTasks: [
          buildTask(id: 'a', date: '2026-05-12', categories: ['work']),
          buildTask(id: 'b', date: '2026-05-12', categories: ['sport']),
          buildTask(id: 'c', date: '2026-05-12', categories: ['study']),
        ],
      );
      expect(ach!.evaluate(ctx), isTrue);
    });

    test('does NOT unlock with only 2 distinct categories same date', () {
      final ctx = buildContext(
        recentTasks: [
          buildTask(id: 'a', date: '2026-05-12', categories: ['work']),
          buildTask(id: 'b', date: '2026-05-12', categories: ['sport']),
          buildTask(id: 'c', date: '2026-05-11', categories: ['study']),
        ],
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
