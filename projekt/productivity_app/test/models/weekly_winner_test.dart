import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/models/weekly_winner.dart';

WeeklyParticipant p(String uid, String nick, int xp, String? weekStart) =>
    WeeklyParticipant(
      uid: uid,
      nickname: nick,
      weeklyXp: xp,
      weeklyXpWeekStart: weekStart,
    );

void main() {
  group('pickWeeklyWinner', () {
    const weekStart = '2026-05-18';
    const capturedAt = '2026-05-25 10:00';

    test('returns empty winner when no participants', () {
      final w = pickWeeklyWinner(
        participants: const [],
        weekStart: weekStart,
        capturedAt: capturedAt,
        myUid: 'me',
      );
      expect(w.nobodyWon, isTrue);
      expect(w.winnerUid, '');
      expect(w.winnerXp, 0);
      expect(w.myXp, 0);
    });

    test('returns empty winner when nobody contributed last week', () {
      final w = pickWeeklyWinner(
        participants: [
          p('me', 'Me', 0, weekStart),
          p('a', 'Alice', 30, '2026-05-11'), // wrong week
        ],
        weekStart: weekStart,
        capturedAt: capturedAt,
        myUid: 'me',
      );
      expect(w.nobodyWon, isTrue);
    });

    test('picks highest XP', () {
      final w = pickWeeklyWinner(
        participants: [
          p('a', 'Alice', 50, weekStart),
          p('b', 'Bob', 30, weekStart),
          p('me', 'Me', 20, weekStart),
        ],
        weekStart: weekStart,
        capturedAt: capturedAt,
        myUid: 'me',
      );
      expect(w.winnerUid, 'a');
      expect(w.winnerNickname, 'Alice');
      expect(w.winnerXp, 50);
      expect(w.myXp, 20);
    });

    test('myXp is 0 when self has stale week start', () {
      final w = pickWeeklyWinner(
        participants: [
          p('me', 'Me', 90, '2026-05-11'), // stale
          p('a', 'Alice', 10, weekStart),
        ],
        weekStart: weekStart,
        capturedAt: capturedAt,
        myUid: 'me',
      );
      expect(w.winnerUid, 'a');
      expect(w.myXp, 0);
    });

    test('ignores participants with weeklyXp=0 even if week matches', () {
      final w = pickWeeklyWinner(
        participants: [
          p('a', 'Alice', 0, weekStart),
          p('b', 'Bob', 0, weekStart),
        ],
        weekStart: weekStart,
        capturedAt: capturedAt,
        myUid: 'me',
      );
      expect(w.nobodyWon, isTrue);
    });

    test('tie-breaks by lexically smallest nickname', () {
      final w = pickWeeklyWinner(
        participants: [
          p('a', 'Bob', 50, weekStart),
          p('b', 'Alice', 50, weekStart),
        ],
        weekStart: weekStart,
        capturedAt: capturedAt,
        myUid: 'me',
      );
      expect(w.winnerUid, 'b');
      expect(w.winnerNickname, 'Alice');
    });

    test('self can win', () {
      final w = pickWeeklyWinner(
        participants: [
          p('me', 'Me', 100, weekStart),
          p('a', 'Alice', 50, weekStart),
        ],
        weekStart: weekStart,
        capturedAt: capturedAt,
        myUid: 'me',
      );
      expect(w.winnerUid, 'me');
      expect(w.winnerXp, 100);
      expect(w.myXp, 100);
    });
  });

  group('WeeklyWinner serialization', () {
    test('round-trips through fromMap/toMap', () {
      const w = WeeklyWinner(
        weekStart: '2026-05-18',
        capturedAt: '2026-05-25 10:00',
        winnerUid: 'a',
        winnerNickname: 'Alice',
        winnerXp: 50,
        myXp: 30,
      );
      final restored = WeeklyWinner.fromMap(w.toMap());
      expect(restored.weekStart, w.weekStart);
      expect(restored.winnerUid, w.winnerUid);
      expect(restored.winnerXp, w.winnerXp);
      expect(restored.myXp, w.myXp);
    });
  });
}
