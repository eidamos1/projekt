import 'task.dart';
import 'habit.dart';

class UserSnapshot {
  final int xp;
  final int level;
  final int streak;
  final int coins;
  final String? lastActiveDate;

  const UserSnapshot({
    required this.xp,
    required this.level,
    required this.streak,
    required this.coins,
    this.lastActiveDate,
  });
}

class EvalContext {
  final UserSnapshot user;
  final List<Task> recentTasks;
  final List<Habit> habits;
  final Set<String> alreadyUnlocked;
  final int totalCompletedTasks;
  /// Count of tasks with completed=false and date < today. Tracked as an
  /// aggregate because recentTasks is pre-filtered to completed=true.
  final int expiredUncompletedCount;

  const EvalContext({
    required this.user,
    required this.recentTasks,
    required this.habits,
    required this.alreadyUnlocked,
    required this.totalCompletedTasks,
    required this.expiredUncompletedCount,
  });

  factory EvalContext.empty() => const EvalContext(
        user: UserSnapshot(xp: 0, level: 1, streak: 0, coins: 0),
        recentTasks: [],
        habits: [],
        alreadyUnlocked: {},
        totalCompletedTasks: 0,
        expiredUncompletedCount: 0,
      );
}
