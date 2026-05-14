import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../models/task.dart';
import '../utils/date_helpers.dart';
import 'app_colors.dart';

abstract final class Achievements {
  static final Achievement _patecniHrdina = Achievement(
    id: 'patecni_hrdina',
    title: 'Páteční hrdina',
    teaser: 'Někdo zná cenu víkendu.',
    description: 'Splnil jsi návyk čtyři pátky po sobě.',
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
    teaser: 'Nevzdal jsi to po první ráně.',
    description: 'Potvrdil jsi úkol, který byl dříve zamítnut.',
    type: AchType.situational,
    icon: Icons.refresh_rounded,
    color: AppColors.neonGreen,
    evaluate: (ctx) =>
        ctx.recentTasks.any((t) => t.completed && t.wasRejected),
  );

  static final Achievement _pulnocniZachrana = Achievement(
    id: 'pulnocni_zachrana',
    title: 'Půlnoční záchrana',
    teaser: 'Někdo to nevzdá ani v poslední minutě.',
    description: 'Splnil jsi úkol po 23:00.',
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
    title: 'Ráno je moudřejší',
    teaser: 'Vstáváš s prvními taxíky.',
    description: 'Splnil jsi úkol před 7:00.',
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
    title: 'Bourák',
    teaser: 'Mañana? Tak ne dnes.',
    description: 'Splnil jsi 3+ úkoly za jeden den.',
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
    teaser: 'Trojitá kombinace.',
    description: 'Splnil jsi denní, týdenní i měsíční úkol v jeden den.',
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
    title: 'Nedělní klid',
    teaser: 'Den odpočinku je taky den.',
    description: 'Splnil jsi návyk ve 4 nedělích po sobě.',
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
    title: 'Univerzál',
    teaser: 'Jeden mozek, sto služeb.',
    description: 'Splnil jsi úkoly ze 3 různých kategorií v jeden den.',
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
    title: 'Prokrastinátor',
    teaser: 'Čas letí nějak rychle, že?',
    description: 'Splnil jsi 5 úkolů v poslední hodině před půlnocí.',
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
    title: 'Zlomený slib',
    teaser: 'Tak blízko.',
    description: 'Rozbil jsi sérii návyku, která trvala 7+ dní.',
    type: AchType.antiAchievement,
    icon: Icons.heart_broken_rounded,
    color: AppColors.neonPink,
    evaluate: (ctx) => ctx.habits.any(
      (h) => h.longestStreak >= 7 && h.longestStreak > h.streak,
    ),
  );

  static final Achievement _krasovePanstvi = Achievement(
    id: 'krasove_panstvi',
    title: 'Krasové panství',
    teaser: 'Všechno chce trénink.',
    description: 'Máš 3 zamítnutí za jeden týden.',
    type: AchType.antiAchievement,
    icon: Icons.do_not_disturb_rounded,
    color: AppColors.neonOrange,
    evaluate: (ctx) {
      final cutoff = formatDate(
        parseDate(todayString()).subtract(const Duration(days: 7)),
      );
      int count = 0;
      for (final t in ctx.recentTasks) {
        if (!t.wasRejected) continue;
        if (t.date.compareTo(cutoff) < 0) continue; // strictly within window
        count++;
      }
      return count >= 3;
    },
  );

  static final Achievement _fantom = Achievement(
    id: 'fantom',
    title: 'Fantom kalendáře',
    teaser: 'Plánovat je snadnější než plnit.',
    description: '5+ tvých úkolů vypršelo bez splnění.',
    type: AchType.antiAchievement,
    icon: Icons.event_busy_rounded,
    color: AppColors.neonPink,
    evaluate: (ctx) => ctx.expiredUncompletedCount >= 5,
  );

  static final Achievement _nocniSova = Achievement(
    id: 'nocni_sova',
    title: 'Noční sova',
    teaser: 'Den má 24 hodin, používá se jen ta druhá polovina.',
    description: 'Splnil jsi 10 úkolů po 22:00.',
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
    title: 'Spartánek',
    teaser: 'Tělo je chrám.',
    description: '14denní série na návyku v kategorii Sport.',
    type: AchType.loreTitle,
    icon: Icons.fitness_center_rounded,
    color: AppColors.neonCyan,
    evaluate: (ctx) => ctx.habits.any(
      (h) => h.categories.contains('sport') && h.streak >= 14,
    ),
  );

  static final Achievement _stovkar = Achievement(
    id: 'stovkar',
    title: 'Stovkař',
    teaser: 'Trochu klasika.',
    description: 'Splnil jsi 100 úkolů.',
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
