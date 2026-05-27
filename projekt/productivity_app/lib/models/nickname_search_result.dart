/// Single match from a [FriendService.searchByNickname] query.
/// Discovery results are intentionally trimmed: nickname + level only,
/// no XP / streak / coins. Adding a friend opens their full profile.
class NicknameSearchResult {
  final String uid;
  final String nickname;
  final int level;

  const NicknameSearchResult({
    required this.uid,
    required this.nickname,
    required this.level,
  });
}
