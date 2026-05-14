// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/task.dart';
import '../services/habit_service.dart';
import '../constants/task_categories.dart';
import '../widgets/empty_state.dart';
import '../widgets/neo_bottom_nav.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/neo_bottom_sheet.dart';
import '../widgets/neo_skeleton.dart';
import '../widgets/dialogs/task_form_dialog.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../utils/context_extensions.dart';

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});
  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  final _habitService = HabitService();

  String _recurrenceLabel(Habit h) {
    switch (h.recurrence) {
      case RecurrenceType.everyday:
        return Strings.recurrenceEveryday;
      case RecurrenceType.weekdays:
        return Strings.recurrenceWeekdays;
      case RecurrenceType.custom:
        return h.customDays.map((d) => Strings.weekdayShort[d]).join(' · ');
    }
  }

  String _typeLabel(TaskType t) {
    switch (t) {
      case TaskType.daily:
        return Strings.typeDaily;
      case TaskType.weekly:
        return Strings.typeWeekly;
      case TaskType.monthly:
        return Strings.typeMonthly;
    }
  }

  void _showActions(Habit h) {
    showNeoBottomSheet<void>(
      context: context,
      children: [
        ListTile(
          leading: const Icon(Icons.edit_rounded),
          title: const Text(Strings.editHabit),
          onTap: () {
            Navigator.pop(context);
            _edit(h);
          },
        ),
        ListTile(
          leading: Icon(
              h.active ? Icons.pause_rounded : Icons.play_arrow_rounded),
          title: Text(h.active ? Strings.pauseHabit : Strings.resumeHabit),
          onTap: () async {
            Navigator.pop(context);
            if (h.active) {
              await _habitService.pauseHabit(h.id);
            } else {
              await _habitService.resumeHabit(h.id);
            }
          },
        ),
        ListTile(
          leading:
              const Icon(Icons.delete_rounded, color: AppColors.neonPink),
          title: const Text(Strings.deleteHabit,
              style: TextStyle(color: AppColors.neonPink)),
          onTap: () {
            Navigator.pop(context);
            _confirmDelete(h);
          },
        ),
      ],
    );
  }

  void _edit(Habit h) {
    showDialog(
      context: context,
      builder: (context) => TaskFormDialog(
        existingHabit: h,
        onSubmit: (title, type, cfg, categories) async {
          await _habitService.updateHabitAndRegenerate(
            habitId: h.id,
            title: title,
            type: type,
            recurrence: cfg?.recurrence,
            customDays: cfg?.customDays,
            categories: categories,
          );
        },
      ),
    );
  }

  void _confirmDelete(Habit h) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('${Strings.deleteHabit}?'),
        content: const Text(Strings.deleteHabitConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(Strings.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonPink,
                foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _habitService.deleteHabit(h.id);
            },
            child: const Text(Strings.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.habitsMine)),
      body: ResponsiveLayout(
        child: StreamBuilder<List<Habit>>(
        stream: _habitService.habitsStream(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const NeoSkeletonList(count: 3, itemHeight: 96);
          }
          final habits = snap.data!;
          if (habits.isEmpty) {
            return const EmptyState(
              icon: Icons.autorenew_rounded,
              title: Strings.noHabitsTitle,
              subtitle: Strings.noHabitsSubtitle,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: habits.length,
            itemBuilder: (_, i) {
              final h = habits[i];
              final typeColor = AppColors.colorForTaskType(h.type);
              return GestureDetector(
                onLongPress: () => _showActions(h),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: NeoTheme.cardDecoration(isDark: isDark),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: NeoTheme.accentBarHeight,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(NeoTheme.radiusCard - 2)),
                          color: h.active ? typeColor : Colors.grey,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text(h.title,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700))),
                              Icon(Icons.autorenew_rounded,
                                  size: 16, color: typeColor),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                                '${_recurrenceLabel(h)} · ${_typeLabel(h.type)}',
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.local_fire_department,
                                  color: AppColors.neonPink, size: 14),
                              const SizedBox(width: 2),
                              Text('${h.streak}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(width: 10),
                              Text(
                                  '${Strings.habitRecord}: ${h.longestStreak}',
                                  style: const TextStyle(fontSize: 12)),
                            ]),
                            if (h.categories.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: h.categories
                                    .map((key) => Categories.byKey(key))
                                    .whereType<TaskCategory>()
                                    .map((cat) => Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    NeoTheme.radiusSmall),
                                            border: Border.all(
                                              color: cat.color,
                                              width: NeoTheme.borderWidthThin,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(cat.icon,
                                                  size: 11, color: cat.color),
                                              const SizedBox(width: 3),
                                              Text(
                                                cat.label,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: cat.color,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        ),
      ),
      bottomNavigationBar: const NeoBottomNav(currentIndex: 1),
    );
  }
}
