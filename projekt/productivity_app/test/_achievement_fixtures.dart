import 'package:productivity_app/models/eval_context.dart';
import 'package:productivity_app/models/task.dart';
import 'package:productivity_app/models/habit.dart';

/// Shared builders for achievement predicate tests. Keep params optional with
/// sensible defaults so each test only specifies what its predicate cares about.

Task buildTask({
  String id = 't',
  String title = 'Task',
  TaskType type = TaskType.daily,
  String date = '2026-05-12',
  String? completedAt,
  bool completed = true,
  bool wasRejected = false,
  String? habitId,
  List<String> categories = const [],
}) {
  return Task(
    id: id,
    title: title,
    type: type,
    date: date,
    xp: 10,
    coins: 5,
    code: '111111',
    completed: completed,
    wasRejected: wasRejected,
    habitId: habitId,
    categories: categories,
    completedAt: completedAt,
  );
}

Habit buildHabit({
  String id = 'h',
  String title = 'Habit',
  TaskType type = TaskType.daily,
  RecurrenceType recurrence = RecurrenceType.everyday,
  List<int> customDays = const [],
  String startDate = '2026-01-01',
  bool active = true,
  int streak = 0,
  int longestStreak = 0,
  String? lastCompletedDate,
  List<String> categories = const [],
}) =>
    Habit(
      id: id,
      title: title,
      type: type,
      recurrence: recurrence,
      customDays: customDays,
      startDate: startDate,
      active: active,
      streak: streak,
      longestStreak: longestStreak,
      lastCompletedDate: lastCompletedDate,
      categories: categories,
    );

EvalContext buildContext({
  List<Task> recentTasks = const [],
  List<Habit> habits = const [],
  Set<String> alreadyUnlocked = const {},
  int totalCompletedTasks = 0,
  int expiredUncompletedCount = 0,
  int userXp = 0,
  int userLevel = 1,
  int userStreak = 0,
}) =>
    EvalContext(
      user: UserSnapshot(
        xp: userXp,
        level: userLevel,
        streak: userStreak,
        coins: 0,
      ),
      recentTasks: recentTasks,
      habits: habits,
      alreadyUnlocked: alreadyUnlocked,
      totalCompletedTasks: totalCompletedTasks,
      expiredUncompletedCount: expiredUncompletedCount,
    );
