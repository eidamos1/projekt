import 'package:flutter/material.dart';
import '../models/achievement.dart';
import 'app_colors.dart';

abstract final class Achievements {
  static final Achievement _prvniKrok = Achievement(
    id: 'prvni_krok',
    title: 'Prvni krok',
    teaser: 'Kazdy nekdy zacina.',
    description: 'Potvrdil jsi svuj prvni task.',
    type: AchType.situational,
    icon: Icons.flag_rounded,
    color: AppColors.neonPink,
    isTitleEligible: false,
    evaluate: (ctx) => ctx.totalCompletedTasks >= 1,
  );

  static final List<Achievement> all = [
    _prvniKrok,
  ];

  static Achievement? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
