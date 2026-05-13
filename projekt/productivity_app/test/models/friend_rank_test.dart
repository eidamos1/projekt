import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/models/friend_rank.dart';

void main() {
  group('FriendRank.buildLeaderboard', () {
    test('sorts DESC by weeklyXp and assigns ranks 1..n', () {
      final entries = [
        const FriendRankRaw(uid: 'a', nickname: 'alice', weeklyXp: 50, weeklyXpWeekStart: '2026-05-11', streak: 1),
        const FriendRankRaw(uid: 'b', nickname: 'bob', weeklyXp: 320, weeklyXpWeekStart: '2026-05-11', streak: 3),
        const FriendRankRaw(uid: 'c', nickname: 'carol', weeklyXp: 110, weeklyXpWeekStart: '2026-05-11', streak: 0),
      ];
      final lb = FriendRank.buildLeaderboard(
        entries: entries,
        myUid: 'a',
        currentMondayStr: '2026-05-11',
      );
      expect(lb.length, 3);
      expect(lb[0].uid, 'b');
      expect(lb[0].rank, 1);
      expect(lb[0].weeklyXp, 320);
      expect(lb[1].uid, 'c');
      expect(lb[1].rank, 2);
      expect(lb[2].uid, 'a');
      expect(lb[2].rank, 3);
    });

    test('marks isMe correctly based on myUid', () {
      final entries = [
        const FriendRankRaw(uid: 'a', nickname: 'alice', weeklyXp: 50, weeklyXpWeekStart: '2026-05-11', streak: 1),
        const FriendRankRaw(uid: 'b', nickname: 'bob', weeklyXp: 320, weeklyXpWeekStart: '2026-05-11', streak: 3),
      ];
      final lb = FriendRank.buildLeaderboard(
        entries: entries,
        myUid: 'a',
        currentMondayStr: '2026-05-11',
      );
      final me = lb.firstWhere((r) => r.uid == 'a');
      final other = lb.firstWhere((r) => r.uid == 'b');
      expect(me.isMe, isTrue);
      expect(other.isMe, isFalse);
    });

    test('treats stale weeklyXpWeekStart as 0', () {
      final entries = [
        const FriendRankRaw(uid: 'a', nickname: 'alice', weeklyXp: 999, weeklyXpWeekStart: '2026-05-04', streak: 1),
        const FriendRankRaw(uid: 'b', nickname: 'bob', weeklyXp: 50, weeklyXpWeekStart: '2026-05-11', streak: 2),
      ];
      final lb = FriendRank.buildLeaderboard(
        entries: entries,
        myUid: 'a',
        currentMondayStr: '2026-05-11',
      );
      // alice's 999 is stale -> treated as 0, so bob (50) is rank 1, alice rank 2
      expect(lb[0].uid, 'b');
      expect(lb[0].weeklyXp, 50);
      expect(lb[1].uid, 'a');
      expect(lb[1].weeklyXp, 0);
    });

    test('treats null weeklyXpWeekStart as 0', () {
      final entries = [
        const FriendRankRaw(uid: 'a', nickname: 'alice', weeklyXp: 100, weeklyXpWeekStart: null, streak: 0),
        const FriendRankRaw(uid: 'b', nickname: 'bob', weeklyXp: 10, weeklyXpWeekStart: '2026-05-11', streak: 0),
      ];
      final lb = FriendRank.buildLeaderboard(
        entries: entries,
        myUid: 'b',
        currentMondayStr: '2026-05-11',
      );
      expect(lb[0].uid, 'b');
      expect(lb[0].weeklyXp, 10);
      expect(lb[1].uid, 'a');
      expect(lb[1].weeklyXp, 0);
    });

    test('breaks ties alphabetically by nickname (case-insensitive ASC)', () {
      final entries = [
        const FriendRankRaw(uid: 'u1', nickname: 'Zara', weeklyXp: 100, weeklyXpWeekStart: '2026-05-11', streak: 0),
        const FriendRankRaw(uid: 'u2', nickname: 'alice', weeklyXp: 100, weeklyXpWeekStart: '2026-05-11', streak: 0),
        const FriendRankRaw(uid: 'u3', nickname: 'Bob', weeklyXp: 100, weeklyXpWeekStart: '2026-05-11', streak: 0),
      ];
      final lb = FriendRank.buildLeaderboard(
        entries: entries,
        myUid: 'u2',
        currentMondayStr: '2026-05-11',
      );
      // All tied on weeklyXp; case-insensitive ASC -> alice, Bob, Zara
      expect(lb[0].nickname, 'alice');
      expect(lb[1].nickname, 'Bob');
      expect(lb[2].nickname, 'Zara');
    });

    test('handles empty entries list', () {
      final lb = FriendRank.buildLeaderboard(
        entries: const [],
        myUid: 'a',
        currentMondayStr: '2026-05-11',
      );
      expect(lb, isEmpty);
    });
  });
}
