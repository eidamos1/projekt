/// Raw input for leaderboard building. One per user (self + each friend).
///
/// Reflects the persisted shape on `users/{uid}` — [weeklyXp] is the stored
/// counter and [weeklyXpWeekStart] is the Monday-yyyy-MM-dd it was bucketed
/// against. The builder applies stale-week normalization.
class FriendRankRaw {
  final String uid;
  final String nickname;
  final int weeklyXp;
  final String? weeklyXpWeekStart;
  final int streak;

  const FriendRankRaw({
    required this.uid,
    required this.nickname,
    required this.weeklyXp,
    required this.weeklyXpWeekStart,
    required this.streak,
  });
}

/// A single leaderboard row, ready for display.
class FriendRank {
  final int rank;
  final String uid;
  final String nickname;
  final int weeklyXp;
  final int streak;
  final bool isMe;

  const FriendRank({
    required this.rank,
    required this.uid,
    required this.nickname,
    required this.weeklyXp,
    required this.streak,
    required this.isMe,
  });

  /// Builds a sorted leaderboard from [entries].
  ///
  /// Normalization: if a raw entry's [FriendRankRaw.weeklyXpWeekStart] does
  /// not match [currentMondayStr], that entry's `weeklyXp` is treated as 0
  /// (stale week — has not been confirmed this week yet).
  ///
  /// Sort: DESC by `weeklyXp`, ties broken by case-insensitive nickname ASC.
  ///
  /// Ranks are assigned by position (1..n) after sorting. `isMe` is set when
  /// the row's uid equals [myUid].
  static List<FriendRank> buildLeaderboard({
    required List<FriendRankRaw> entries,
    required String myUid,
    required String currentMondayStr,
  }) {
    // Step 1: normalize weeklyXp for stale weeks.
    final normalized = entries.map((e) {
      final fresh = e.weeklyXpWeekStart == currentMondayStr;
      return (
        uid: e.uid,
        nickname: e.nickname,
        weeklyXp: fresh ? e.weeklyXp : 0,
        streak: e.streak,
      );
    }).toList();

    // Step 2: sort DESC by weeklyXp, tie-break by lowercase nickname ASC.
    normalized.sort((a, b) {
      final cmp = b.weeklyXp.compareTo(a.weeklyXp);
      if (cmp != 0) return cmp;
      return a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase());
    });

    // Step 3: assign ranks and isMe flag.
    return [
      for (var i = 0; i < normalized.length; i++)
        FriendRank(
          rank: i + 1,
          uid: normalized[i].uid,
          nickname: normalized[i].nickname,
          weeklyXp: normalized[i].weeklyXp,
          streak: normalized[i].streak,
          isMe: normalized[i].uid == myUid,
        ),
    ];
  }
}
