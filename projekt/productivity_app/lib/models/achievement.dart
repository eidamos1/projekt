import 'package:flutter/material.dart';
import 'eval_context.dart';

enum AchType { situational, antiAchievement, loreTitle, milestone }

class Achievement {
  final String id;
  final String title;
  final String teaser;
  final String description;
  final AchType type;
  final IconData icon;
  final Color color;
  final bool isTitleEligible;
  final int xpReward;
  final int coinReward;
  final bool Function(EvalContext) evaluate;

  const Achievement({
    required this.id,
    required this.title,
    required this.teaser,
    required this.description,
    required this.type,
    required this.icon,
    required this.color,
    this.isTitleEligible = true,
    this.xpReward = 0,
    this.coinReward = 0,
    required this.evaluate,
  });
}
