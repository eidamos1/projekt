import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../models/task.dart';
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

  static final Achievement _comebackKid = Achievement(
    id: 'comeback_kid',
    title: 'Comeback',
    teaser: 'Nevzdal jsi to po prvni rane.',
    description: 'Potvrdil jsi task, ktery byl drive zamitnut.',
    type: AchType.situational,
    icon: Icons.refresh_rounded,
    color: AppColors.neonGreen,
    evaluate: (ctx) =>
        ctx.recentTasks.any((t) => t.completed && t.wasRejected),
  );

  static final Achievement _pulnocniZachrana = Achievement(
    id: 'pulnocni_zachrana',
    title: 'Pulnocni zachrana',
    teaser: 'Nekdo to nevzda ani v posledni minute.',
    description: 'Splnil jsi task po 23:00.',
    type: AchType.situational,
    icon: Icons.access_time_rounded,
    color: AppColors.neonPink,
    evaluate: (ctx) => ctx.recentTasks.any((t) {
      final h = hourOf(t.completedAt);
      return h != null && h >= 23;
    }),
  );

  static final Achievement _ranoJeMoudrejsi = Achievement(
    id: 'rano_je_moudrejsi',
    title: 'Rano je moudrejsi',
    teaser: 'Vstavas s prvnimi taxiky.',
    description: 'Splnil jsi task pred 7:00.',
    type: AchType.situational,
    icon: Icons.wb_sunny_rounded,
    color: AppColors.neonOrange,
    evaluate: (ctx) => ctx.recentTasks.any((t) {
      final h = hourOf(t.completedAt);
      return h != null && h < 7;
    }),
  );

  static final Achievement _bourak = Achievement(
    id: 'bourak',
    title: 'Bourak',
    teaser: 'Manana? Tak ne dnes.',
    description: 'Splnil jsi 3+ tasku za jeden den.',
    type: AchType.situational,
    icon: Icons.bolt_rounded,
    color: AppColors.neonCyan,
    evaluate: (ctx) {
      final counts = <String, int>{};
      for (final t in ctx.recentTasks) {
        if (!t.completed) continue;
        counts.update(t.date, (v) => v + 1, ifAbsent: () => 1);
      }
      return counts.values.any((c) => c >= 3);
    },
  );

  static final Achievement _hatTrick = Achievement(
    id: 'hat_trick',
    title: 'Hat-trick',
    teaser: 'Trojita kombinace.',
    description: 'Splnil jsi daily, weekly i monthly task v jeden den.',
    type: AchType.situational,
    icon: Icons.emoji_events_rounded,
    color: AppColors.neonYellow,
    evaluate: (ctx) {
      final byDate = <String, Set<TaskType>>{};
      for (final t in ctx.recentTasks) {
        if (!t.completed) continue;
        byDate.putIfAbsent(t.date, () => {}).add(t.type);
      }
      return byDate.values.any((types) =>
          types.contains(TaskType.daily) &&
          types.contains(TaskType.weekly) &&
          types.contains(TaskType.monthly));
    },
  );

  static final List<Achievement> all = [
    _prvniKrok,
    _patecniHrdina,
    _comebackKid,
    _pulnocniZachrana,
    _ranoJeMoudrejsi,
    _bourak,
    _hatTrick,
  ];

  static Achievement? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
