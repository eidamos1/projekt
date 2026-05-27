/// A single entry in the friend activity feed: one friend, one achievement,
/// one unlock timestamp. Built by [FriendService.activityFeedStream] which
/// fans in achievement subcollections across all friends and merges them
/// into a single chronological list.
class ActivityFeedItem {
  final String friendUid;
  final String friendNickname;
  final String achievementId;
  /// 'yyyy-MM-dd HH:mm' lexically sortable.
  final String unlockedAt;

  const ActivityFeedItem({
    required this.friendUid,
    required this.friendNickname,
    required this.achievementId,
    required this.unlockedAt,
  });

  @override
  bool operator ==(Object other) =>
      other is ActivityFeedItem &&
      other.friendUid == friendUid &&
      other.achievementId == achievementId &&
      other.unlockedAt == unlockedAt;

  @override
  int get hashCode => Object.hash(friendUid, achievementId, unlockedAt);
}
