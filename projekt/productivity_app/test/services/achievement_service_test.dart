import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/services/achievement_service.dart';

import '../_achievement_fixtures.dart';

void main() {
  group('AchievementService.evaluatePredicates', () {
    final svc = AchievementService();

    test('returns prvni_krok when totalCompletedTasks >= 1 and not already unlocked', () {
      final ctx = buildContext(totalCompletedTasks: 1);
      final result = svc.evaluatePredicates(ctx);
      expect(result.map((a) => a.id), contains('prvni_krok'));
    });

    test('skips already unlocked', () {
      final ctx = buildContext(
        totalCompletedTasks: 1,
        alreadyUnlocked: const {'prvni_krok'},
      );
      final result = svc.evaluatePredicates(ctx);
      // comeback_kid etc won't trigger from an empty recentTasks list,
      // so the only candidate (prvni_krok) is filtered out.
      expect(result.where((a) => a.id == 'prvni_krok'), isEmpty);
    });
  });
}
