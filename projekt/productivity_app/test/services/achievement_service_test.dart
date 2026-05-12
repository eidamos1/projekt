import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/models/eval_context.dart';
import 'package:productivity_app/services/achievement_service.dart';

void main() {
  group('AchievementService.evaluatePredicates', () {
    final svc = AchievementService();

    test('returns prvni_krok when totalCompletedTasks >= 1 and not already unlocked', () {
      final ctx = EvalContext(
        user: const UserSnapshot(xp: 0, level: 1, streak: 0, coins: 0),
        recentTasks: const [],
        habits: const [],
        alreadyUnlocked: const {},
        totalCompletedTasks: 1,
      );
      final result = svc.evaluatePredicates(ctx);
      expect(result.map((a) => a.id), contains('prvni_krok'));
    });

    test('skips already unlocked', () {
      final ctx = EvalContext(
        user: const UserSnapshot(xp: 0, level: 1, streak: 0, coins: 0),
        recentTasks: const [],
        habits: const [],
        alreadyUnlocked: const {'prvni_krok'},
        totalCompletedTasks: 1,
      );
      final result = svc.evaluatePredicates(ctx);
      expect(result, isEmpty);
    });
  });
}
