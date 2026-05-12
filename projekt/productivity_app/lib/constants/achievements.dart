import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../utils/date_helpers.dart';
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

  static final Achievement _patecniHrdina = Achievement(
    id: 'patecni_hrdina',
    title: 'Patecni hrdina',
    teaser: 'Nekdo zna cenu vikendu.',
    description: 'Splnil jsi habit ctyri patky po sobe.',
    type: AchType.situational,
    icon: Icons.weekend_rounded,
    color: AppColors.neonYellow,
    evaluate: (ctx) {
      final fridays = <String>{};
      for (final t in ctx.recentTasks) {
        if (t.habitId == null || !t.completed) continue;
        final d = parseDate(t.date);
        if (d.weekday == DateTime.friday) fridays.add(t.date);
      }
      if (fridays.length < 4) return false;
      final sortedDesc = fridays.toList()..sort((a, b) => b.compareTo(a));
      DateTime prev = parseDate(sortedDesc[0]);
      for (int i = 1; i < 4; i++) {
        final cur = parseDate(sortedDesc[i]);
        final diff = prev.difference(cur).inDays;
        if (diff != 7) return false;
        prev = cur;
      }
      return true;
    },
  );

  static final List<Achievement> all = [
    _prvniKrok,
    _patecniHrdina,
  ];

  static Achievement? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
