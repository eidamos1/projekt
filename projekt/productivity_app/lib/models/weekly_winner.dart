/// A persisted snapshot of who won a friends-leaderboard week from the
/// current user's perspective. Computed lazily on /profile open in a new
/// week, stored to `users/{uid}/weeklyWinners/{weekStart}` so re-renders
/// don't re-query the friends graph.
///
/// "Won" = highest `weeklyXp` among (self + friends) whose
/// `weeklyXpWeekStart` matches [weekStart].
class WeeklyWinner {
  /// 'yyyy-MM-dd' of the Monday this snapshot represents.
  final String weekStart;
  /// 'yyyy-MM-dd HH:mm' — when this client computed and wrote the snapshot.
  final String capturedAt;
  /// Empty string if no participant had any XP that week.
  final String winnerUid;
  final String winnerNickname;
  final int winnerXp;
  /// User's own contribution that week (for "Ty: X XP" line).
  final int myXp;

  const WeeklyWinner({
    required this.weekStart,
    required this.capturedAt,
    required this.winnerUid,
    required this.winnerNickname,
    required this.winnerXp,
    required this.myXp,
  });

  /// Empty-week marker: nobody (self + friends) had any XP for this week.
  bool get nobodyWon => winnerUid.isEmpty && winnerXp == 0;

  factory WeeklyWinner.fromMap(Map<String, dynamic> data) {
    return WeeklyWinner(
      weekStart: data['weekStart'] as String? ?? '',
      capturedAt: data['capturedAt'] as String? ?? '',
      winnerUid: data['winnerUid'] as String? ?? '',
      winnerNickname: data['winnerNickname'] as String? ?? '',
      winnerXp: (data['winnerXp'] as int?) ?? 0,
      myXp: (data['myXp'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'weekStart': weekStart,
        'capturedAt': capturedAt,
        'winnerUid': winnerUid,
        'winnerNickname': winnerNickname,
        'winnerXp': winnerXp,
        'myXp': myXp,
      };
}

/// One participant in a weekly winner calculation. Pure data carrier so
/// the picker is testable without Firestore.
class WeeklyParticipant {
  final String uid;
  final String nickname;
  final int weeklyXp;
  final String? weeklyXpWeekStart;

  const WeeklyParticipant({
    required this.uid,
    required this.nickname,
    required this.weeklyXp,
    required this.weeklyXpWeekStart,
  });
}

/// Pure picker — given participants and the target week, returns the
/// WeeklyWinner record. Tie-break: highest XP first; on equal XP,
/// lexically smallest nickname (stable, jurisdiction-free). [myUid] marks
/// which entry contributes to [WeeklyWinner.myXp].
WeeklyWinner pickWeeklyWinner({
  required Iterable<WeeklyParticipant> participants,
  required String weekStart,
  required String capturedAt,
  required String myUid,
}) {
  int myXp = 0;
  WeeklyParticipant? top;

  for (final p in participants) {
    final isMine = p.uid == myUid;
    final contributes = p.weeklyXpWeekStart == weekStart && p.weeklyXp > 0;
    if (isMine && contributes) myXp = p.weeklyXp;
    if (!contributes) continue;
    if (top == null) {
      top = p;
      continue;
    }
    if (p.weeklyXp > top.weeklyXp) {
      top = p;
    } else if (p.weeklyXp == top.weeklyXp &&
        p.nickname.compareTo(top.nickname) < 0) {
      top = p;
    }
  }

  if (top == null) {
    return WeeklyWinner(
      weekStart: weekStart,
      capturedAt: capturedAt,
      winnerUid: '',
      winnerNickname: '',
      winnerXp: 0,
      myXp: 0,
    );
  }
  return WeeklyWinner(
    weekStart: weekStart,
    capturedAt: capturedAt,
    winnerUid: top.uid,
    winnerNickname: top.nickname,
    winnerXp: top.weeklyXp,
    myXp: myXp,
  );
}
