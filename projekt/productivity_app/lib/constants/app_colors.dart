import 'package:flutter/material.dart';
import '../models/task.dart';

abstract final class AppColors {
  // Scaffold / Background
  static const scaffoldDark = Color(0xFF0A0A0F);
  static const scaffoldLight = Color(0xFFF0F0F0);

  // Cards
  static const cardDark = Color(0xFF1A1A24);
  static const cardLight = Colors.white;

  // Borders
  static const borderSubtle = Color(0xFF2A2A35);
  static const borderBold = Color(0xFFE0E0E0);

  // Neon accents
  static const neonGreen = Color(0xFF39FF14);
  static const neonPink = Color(0xFFFF2D7B);
  static const neonYellow = Color(0xFFFFE500);
  static const neonCyan = Color(0xFF00F0FF);
  static const neonOrange = Color(0xFFFF6D00);

  // Primary (default)
  static const primary = neonGreen;

  // Text
  static const textPrimary = Color(0xFFF0F0F0);
  static const textSecondary = Color(0xFF8888AA);

  // Task types (brighter neon versions)
  static const taskDaily = Color(0xFF4D8EFF);
  static const taskWeekly = Color(0xFFFFAA00);
  static const taskMonthly = Color(0xFFBB66FF);

  // Status
  static const completed = neonGreen;
  static const completedBg = neonGreen;
  static const rejected = neonPink;
  static const rejectedBg = neonPink;
  static const pending = neonYellow;
  static const notifBadge = neonPink;

  // XP
  static const xpLight = neonCyan;
  static const xpDark = neonCyan;

  // Coins
  static const coinIcon = neonYellow;
  static const coinTextLight = Color(0xFFE6CE00);
  static const coinTextDark = neonYellow;

  // Streak
  static const streakStart = neonOrange;
  static const streakEnd = neonPink;

  // Calendar
  static const weekendLight = Color(0xFFE53935);
  static const weekendDark = Color(0xFFFF8A80);

  static Color colorForTaskType(TaskType type) {
    switch (type) {
      case TaskType.daily:
        return taskDaily;
      case TaskType.weekly:
        return taskWeekly;
      case TaskType.monthly:
        return taskMonthly;
    }
  }

  static const List<({String name, Color color})> themeOptions = [
    (name: 'Neon zelena', color: neonGreen),
    (name: 'Neon ruzova', color: neonPink),
    (name: 'Neon zluta', color: neonYellow),
    (name: 'Neon cyan', color: neonCyan),
    (name: 'Neon oranzova', color: neonOrange),
    (name: 'Modra', color: Color(0xFF4D8EFF)),
    (name: 'Fialova', color: Color(0xFFBB66FF)),
  ];
}
