import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/models/achievement.dart';
import 'package:productivity_app/models/eval_context.dart';

void main() {
  group('Achievement', () {
    test('evaluate returns predicate result', () {
      final a = Achievement(
        id: 'test',
        title: 'Test',
        teaser: 'tease',
        description: 'desc',
        type: AchType.situational,
        icon: Icons.star,
        color: Colors.red,
        evaluate: (_) => true,
      );
      expect(a.evaluate(EvalContext.empty()), isTrue);
    });

    test('defaults: isTitleEligible=true, xp/coins=0', () {
      final a = Achievement(
        id: 'test',
        title: 't',
        teaser: 't',
        description: 'd',
        type: AchType.situational,
        icon: Icons.star,
        color: Colors.red,
        evaluate: (_) => false,
      );
      expect(a.isTitleEligible, isTrue);
      expect(a.xpReward, 0);
      expect(a.coinReward, 0);
    });
  });
}
