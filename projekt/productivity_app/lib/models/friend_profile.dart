/// Read-only snapshot of another user's public-ish profile.
///
/// Returned by `FriendService.loadFriendProfile`. The shape intentionally
/// mirrors only the fields shown on the friend profile page so we don't
/// accidentally leak unrelated user-doc data (the page is read-only and
/// shouldn't surface anything beyond what a friend would expect to be
/// visible — nickname, level/xp, streak, coins, weekly XP, achievements).
class FriendProfile {
  final String uid;
  final String nickname;
  final int xp;
  final int coins;
  final int level;
  final int streak;
  final int weeklyXp;
  final String? activeTitleId;
  final int achievementsUnlockedCount;
  final int totalCompletedTasks;

  const FriendProfile({
    required this.uid,
    required this.nickname,
    required this.xp,
    required this.coins,
    required this.level,
    required this.streak,
    required this.weeklyXp,
    required this.activeTitleId,
    required this.achievementsUnlockedCount,
    required this.totalCompletedTasks,
  });
}
