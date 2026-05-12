import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/constants/achievements.dart';
import 'package:productivity_app/models/eval_context.dart';

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
}
