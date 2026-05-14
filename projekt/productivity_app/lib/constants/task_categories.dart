import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Predefined category for tasks. Stored in Firestore by [key]; UI looks up
/// the rest via [Categories.byKey]. Keys are stable identifiers — never rename
/// without a migration. Labels are display strings (proper Czech with diacritics).
class TaskCategory {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const TaskCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

abstract final class Categories {
  static const work = TaskCategory(
    key: 'work',
    label: 'Práce',
    icon: Icons.work_rounded,
    color: AppColors.neonOrange,
  );
  static const personal = TaskCategory(
    key: 'personal',
    label: 'Osobní',
    icon: Icons.person_rounded,
    color: AppColors.neonGreen,
  );
  static const sport = TaskCategory(
    key: 'sport',
    label: 'Sport',
    icon: Icons.fitness_center_rounded,
    color: AppColors.neonCyan,
  );
  static const study = TaskCategory(
    key: 'study',
    label: 'Studium',
    icon: Icons.school_rounded,
    color: AppColors.taskMonthly,
  );
  static const home = TaskCategory(
    key: 'home',
    label: 'Domácnost',
    icon: Icons.home_rounded,
    color: AppColors.neonYellow,
  );
  static const health = TaskCategory(
    key: 'health',
    label: 'Zdraví',
    icon: Icons.favorite_rounded,
    color: AppColors.neonPink,
  );
  static const creative = TaskCategory(
    key: 'creative',
    label: 'Kreativita',
    icon: Icons.palette_rounded,
    color: AppColors.taskWeekly,
  );
  static const other = TaskCategory(
    key: 'other',
    label: 'Jiné',
    icon: Icons.label_outline_rounded,
    color: Color(0xFF8888AA),
  );

  static const all = <TaskCategory>[
    work,
    personal,
    sport,
    study,
    home,
    health,
    creative,
    other,
  ];

  static TaskCategory? byKey(String key) {
    for (final c in all) {
      if (c.key == key) return c;
    }
    return null;
  }
}
