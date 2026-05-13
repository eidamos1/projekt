import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/neo_theme.dart';
import '../../constants/task_categories.dart';
import '../../models/task.dart';
import '../../utils/context_extensions.dart';
import '../neo_bottom_sheet.dart';

void showDayDetailSheet(BuildContext context, DateTime date, List<Task> dayTasks) {
  showNeoBottomSheet<void>(
    context: context,
    children: [
      DayDetailSheet(date: date, tasks: dayTasks),
    ],
  );
}

class DayDetailSheet extends StatelessWidget {
  final DateTime date;
  final List<Task> tasks;

  const DayDetailSheet({super.key, required this.date, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final totalXp = tasks.fold<int>(0, (sum, t) => sum + t.xp);
    final dateLabel = DateFormat('EEEE, d. MMMM yyyy', 'cs').format(date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NeoTheme.spaceLg, NeoTheme.spaceMd,
        NeoTheme.spaceLg, NeoTheme.spaceLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dateLabel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${tasks.length} ukolu \u00b7 $totalXp XP',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondary : Colors.black54,
            ),
          ),
          const SizedBox(height: NeoTheme.spaceMd),
          ...tasks.map((t) => _DayTaskRow(task: t, isDark: isDark)),
        ],
      ),
    );
  }
}

class _DayTaskRow extends StatelessWidget {
  final Task task;
  final bool isDark;

  const _DayTaskRow({required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (task.habitId != null) ...[
            const Icon(Icons.autorenew_rounded, size: 14, color: AppColors.neonCyan),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (task.categories.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 4,
                    children: task.categories
                        .map((k) => Categories.byKey(k))
                        .whereType<TaskCategory>()
                        .map((cat) => Text(
                              cat.label,
                              style: TextStyle(fontSize: 10, color: cat.color),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${task.xp} XP',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.neonCyan,
            ),
          ),
        ],
      ),
    );
  }
}
