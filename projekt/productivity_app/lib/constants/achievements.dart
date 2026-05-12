import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../models/task.dart';
import '../utils/date_helpers.dart';
import 'app_colors.dart';

abstract final class Achievements {
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

  static final Achievement _nedelniKlid = Achievement(
    id: 'nedelni_klid',
    title: 'Nedelni klid',
    teaser: 'Den odpocinku je taky den.',
    description: 'Splnil jsi habit ve 4 nedelich po sobe.',
    type: AchType.situational,
    icon: Icons.self_improvement_rounded,
    color: AppColors.neonCyan,
    evaluate: (ctx) {
      final sundays = <String>{};
      for (final t in ctx.recentTasks) {
        if (t.habitId == null || !t.completed) continue;
        final d = parseDate(t.date);
        if (d.weekday == DateTime.sunday) sundays.add(t.date);
      }
      if (sundays.length < 4) return false;
      final sortedDesc = sundays.toList()..sort((a, b) => b.compareTo(a));
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

  static final Achievement _univerzal = Achievement(
    id: 'univerzal',
    title: 'Univerzal',
    teaser: 'Jeden mozek, sto sluzeb.',
    description: 'Splnil jsi tasky ze 3 ruznych kategorii v jeden den.',
    type: AchType.situational,
    icon: Icons.dynamic_feed_rounded,
    color: AppColors.neonPink,
    evaluate: (ctx) {
      final byDate = <String, Set<String>>{};
      for (final t in ctx.recentTasks) {
        if (!t.completed) continue;
        byDate.putIfAbsent(t.date, () => {}).addAll(t.categories);
      }
      return byDate.values.any((cats) => cats.length >= 3);
    },
  );

  static final Achievement _prokrastinator = Achievement(
    id: 'prokrastinator',
    title: 'Prokrastinator',
    teaser: 'Cas leti nejak rychle, ze?',
    description: 'Splnil jsi 5 tasku v posledni hodine pred pulnoci.',
    type: AchType.antiAchievement,
    icon: Icons.hourglass_bottom_rounded,
    color: AppColors.neonOrange,
    evaluate: (ctx) {
      final lateDays = <String>{};
      for (final t in ctx.recentTasks) {
        final h = hourOf(t.completedAt);
        if (h == null || h < 23) continue;
        lateDays.add(t.date);
      }
      return lateDays.length >= 5;
    },
  );

  static final Achievement _zlomenySlib = Achievement(
    id: 'zlomeny_slib',
    title: 'Zlomeny slib',
    teaser: 'Tak blizko.',
    description: 'Rozbil jsi habit streak 7+ dni.',
    type: AchType.antiAchievement,
    icon: Icons.heart_broken_rounded,
    color: AppColors.neonPink,
    evaluate: (ctx) => ctx.habits.any(
      (h) => h.longestStreak >= 7 && h.longestStreak > h.streak,
    ),
  );

  static final Achievement _krasovePanstvi = Achievement(
    id: 'krasove_panstvi',
    title: 'Krasove panstvi',
    teaser: 'Vsechno chce trening.',
    description: 'Mas 3 zamitnuti za jeden tyden.',
    type: AchType.antiAchievement,
    icon: Icons.do_not_disturb_rounded,
    color: AppColors.neonOrange,
    evaluate: (ctx) {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      int count = 0;
      for (final t in ctx.recentTasks) {
        if (!t.wasRejected) continue;
        final d = parseDate(t.date);
        if (d.isAfter(sevenDaysAgo)) count++;
      }
      return count >= 3;
    },
  );

  static final Achievement _fantom = Achievement(
    id: 'fantom',
    title: 'Fantom kalendare',
    teaser: 'Planovat je snadnejsi nez plnit.',
    description: '5+ tvych tasku vyprshelo bez splneni.',
    type: AchType.antiAchievement,
    icon: Icons.event_busy_rounded,
    color: AppColors.neonPink,
    evaluate: (ctx) => ctx.expiredUncompletedCount >= 5,
  );

  static final Achievement _nocniSova = Achievement(
    id: 'nocni_sova',
    title: 'Nocni sova',
    teaser: 'Den ma 24 hodin, pouziva se jen ta druha polovina.',
    description: 'Splnil jsi 10 tasku po 22:00.',
    type: AchType.loreTitle,
    icon: Icons.nightlight_round,
    color: AppColors.neonCyan,
    evaluate: (ctx) {
      int count = 0;
      for (final t in ctx.recentTasks) {
        final h = hourOf(t.completedAt);
        if (h != null && h >= 22) count++;
      }
      return count >= 10;
    },
  );

  static final Achievement _spartanek = Achievement(
    id: 'spartanek',
    title: 'Spartanek',
    teaser: 'Telo je chram.',
    description: '14denni streak na sport-kategorii habitu.',
    type: AchType.loreTitle,
    icon: Icons.fitness_center_rounded,
    color: AppColors.neonCyan,
    evaluate: (ctx) => ctx.habits.any(
      (h) => h.categories.contains('sport') && h.streak >= 14,
    ),
  );

  static final Achievement _stovkar = Achievement(
    id: 'stovkar',
    title: 'Stovkar',
    teaser: 'Trochu klasika.',
    description: 'Splnil jsi 100 tasku.',
    type: AchType.milestone,
    icon: Icons.military_tech_rounded,
    color: AppColors.neonYellow,
    isTitleEligible: false,
    xpReward: 500,
    coinReward: 200,
    evaluate: (ctx) => ctx.totalCompletedTasks >= 100,
  );

  static final List<Achievement> all = [
    _patecniHrdina, _comebackKid, _pulnocniZachrana, _ranoJeMoudrejsi,
    _bourak, _hatTrick, _nedelniKlid, _univerzal,
    _prokrastinator, _zlomenySlib, _krasovePanstvi, _fantom,
    _nocniSova, _spartanek,
    _stovkar,
  ];

  static Achievement? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
