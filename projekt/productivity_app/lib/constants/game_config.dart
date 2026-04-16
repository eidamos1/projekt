import '../models/task.dart';

abstract final class GameConfig {
  // XP rewards
  static const dailyXp = 10;
  static const weeklyXp = 50;
  static const monthlyXp = 200;

  // Coin rewards
  static const dailyCoins = 5;
  static const weeklyCoins = 20;
  static const monthlyCoins = 100;

  // Streak bonuses
  static const streakBonus7 = 50;
  static const streakBonus30 = 200;
  static const streakBonus100 = 1000;

  // Level
  static const xpPerLevel = 100;

  // Photo
  static const photoMaxWidth = 500.0;
  static const photoQuality = 40;
  static const photoMaxBytes = 750000;

  static ({int xp, int coins}) rewardsFor(TaskType type) {
    switch (type) {
      case TaskType.daily:
        return (xp: dailyXp, coins: dailyCoins);
      case TaskType.weekly:
        return (xp: weeklyXp, coins: weeklyCoins);
      case TaskType.monthly:
        return (xp: monthlyXp, coins: monthlyCoins);
    }
  }

  static int levelFromXp(int xp) => (xp ~/ xpPerLevel) + 1;

  static int streakBonus(int streak) {
    if (streak == 100) return streakBonus100;
    if (streak == 30) return streakBonus30;
    if (streak == 7) return streakBonus7;
    return 0;
  }
}
