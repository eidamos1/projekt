import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/services/achievement_service.dart';

import '../_achievement_fixtures.dart';

void main() {
  group('AchievementService.evaluatePredicates', () {
    final svc = AchievementService();

    test('returns comeback_kid when a completed wasRejected task is present', () {
      final ctx = buildContext(
        recentTasks: [buildTask(wasRejected: true, completed: true)],
      );
      final result = svc.evaluatePredicates(ctx);
      expect(result.map((a) => a.id), contains('comeback_kid'));
    });

    test('skips already unlocked comeback_kid', () {
      final ctx = buildContext(
        recentTasks: [buildTask(wasRejected: true, completed: true)],
        alreadyUnlocked: const {'comeback_kid'},
      );
      final result = svc.evaluatePredicates(ctx);
      expect(result.where((a) => a.id == 'comeback_kid'), isEmpty);
    });
  });
}
