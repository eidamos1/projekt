# Friends + Leaderboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a social layer to Motivator: invite-link friends (mutual handshake), weekly XP leaderboard, and a passive friend-feed that lets friends confirm each other's tasks without copying codes.

**Architecture:** Reuses existing Firestore-subcollection-per-user pattern. New `users.inviteCode` field plus `userInvites/{code}` global index for lookup. `users/{uid}/friends/{friendUid}` mutual edges, `users.weeklyXp + weeklyXpWeekStart` denormalized counters reset lazily on `confirmTask`. UI is hybrid: dedicated `/profile` page (entered via profile chip) plus a compact leaderboard widget in `/stats`. Friend-feed reuses existing notifications subcollection with a new `friend_pending` type.

**Tech Stack:** Flutter 3.9+, Dart, Firebase (Auth + Firestore + Hosting), Provider, fl_chart.

**Design doc:** `docs/plans/2026-05-13-friends-leaderboard-design.md` (read first).

**Review cadence:** Phase-level. After each phase finishes, run `flutter analyze && flutter test`, sanity-check on live deploy via Playwright, then proceed.

---

## Phase 1: Foundation (week helpers, invite codes, FriendRank model, service skeleton, Firestore rules)

Goal of phase: pure-logic building blocks ready, no UI yet. All testable headlessly. Phase ends with `flutter test` green and rules deployed without breaking existing flows.

### Task 1.1: Add `lib/utils/week_helpers.dart` with `mondayOf`

**Files:**
- Create: `lib/utils/week_helpers.dart`
- Create: `test/utils/week_helpers_test.dart`

**Step 1: Write the failing test**

```dart
// test/utils/week_helpers_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/utils/week_helpers.dart';

void main() {
  group('mondayOf', () {
    test('Monday returns same date at midnight', () {
      final m = mondayOf(DateTime(2026, 5, 11, 14, 30)); // Po
      expect(m, DateTime(2026, 5, 11));
    });

    test('Wednesday returns previous Monday', () {
      final m = mondayOf(DateTime(2026, 5, 13, 9, 0)); // St
      expect(m, DateTime(2026, 5, 11));
    });

    test('Sunday returns previous Monday', () {
      final m = mondayOf(DateTime(2026, 5, 17, 23, 59)); // Ne
      expect(m, DateTime(2026, 5, 11));
    });

    test('crosses month boundary correctly', () {
      // Wed 2026-06-03 → Monday 2026-06-01
      expect(mondayOf(DateTime(2026, 6, 3)), DateTime(2026, 6, 1));
      // Tue 2026-06-02 → Monday 2026-06-01
      expect(mondayOf(DateTime(2026, 6, 2)), DateTime(2026, 6, 1));
      // Mon 2026-06-01 → 2026-06-01
      expect(mondayOf(DateTime(2026, 6, 1)), DateTime(2026, 6, 1));
      // Sun 2026-05-31 → 2026-05-25
      expect(mondayOf(DateTime(2026, 5, 31)), DateTime(2026, 5, 25));
    });

    test('strips time-of-day', () {
      expect(mondayOf(DateTime(2026, 5, 13, 23, 59, 59, 999)),
          DateTime(2026, 5, 11));
    });
  });

  group('mondayStringOf', () {
    test('returns yyyy-MM-dd of mondayOf', () {
      expect(mondayStringOf(DateTime(2026, 5, 13)), '2026-05-11');
      expect(mondayStringOf(DateTime(2026, 6, 1)), '2026-06-01');
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/utils/week_helpers_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:productivity_app/utils/week_helpers.dart'`

**Step 3: Write minimal implementation**

```dart
// lib/utils/week_helpers.dart
/// Returns Monday 00:00 of the week containing [d]. Stripping time-of-day.
DateTime mondayOf(DateTime d) {
  // weekday: Mon=1, Sun=7
  final daysSinceMonday = d.weekday - 1;
  return DateTime(d.year, d.month, d.day - daysSinceMonday);
}

/// yyyy-MM-dd of [mondayOf](d).
String mondayStringOf(DateTime d) {
  final m = mondayOf(d);
  return '${m.year}-${m.month.toString().padLeft(2, '0')}-${m.day.toString().padLeft(2, '0')}';
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/utils/week_helpers_test.dart`
Expected: PASS (all 6 tests)

**Step 5: Commit**

```bash
git add lib/utils/week_helpers.dart test/utils/week_helpers_test.dart
git commit -m "feat(friends): mondayOf helper for weekly XP reset"
```

---

### Task 1.2: Add `lib/utils/invite_code.dart` generator

**Files:**
- Create: `lib/utils/invite_code.dart`
- Create: `test/utils/invite_code_test.dart`

**Step 1: Write the failing test**

```dart
// test/utils/invite_code_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/utils/invite_code.dart';

void main() {
  group('generateInviteCode', () {
    test('returns 8-char string', () {
      for (int i = 0; i < 50; i++) {
        expect(generateInviteCode().length, 8);
      }
    });

    test('uses only [A-Z0-9] charset (no ambiguous chars)', () {
      final pattern = RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]+$');
      for (int i = 0; i < 50; i++) {
        expect(pattern.hasMatch(generateInviteCode()), true,
            reason: 'should match charset (no 0/O/1/I/L)');
      }
    });

    test('produces varied codes', () {
      final codes = <String>{};
      for (int i = 0; i < 100; i++) {
        codes.add(generateInviteCode());
      }
      // 30 charset ^ 8 = trillions of options. 100 should be unique.
      expect(codes.length, greaterThan(95));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/utils/invite_code_test.dart`
Expected: FAIL — file not found.

**Step 3: Write minimal implementation**

```dart
// lib/utils/invite_code.dart
import 'dart:math';

// No 0/O, no 1/I/L — humans copy-paste these wrong.
const _kInviteCharset = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const _kInviteCodeLength = 8;

final _rng = Random.secure();

/// Generates an 8-char invite code from a no-ambiguity alphanumeric charset.
/// Caller must check uniqueness against `userInvites/` and retry on collision.
String generateInviteCode() {
  return String.fromCharCodes(List.generate(
    _kInviteCodeLength,
    (_) => _kInviteCharset.codeUnitAt(_rng.nextInt(_kInviteCharset.length)),
  ));
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/utils/invite_code_test.dart`
Expected: PASS (3 tests)

**Step 5: Commit**

```bash
git add lib/utils/invite_code.dart test/utils/invite_code_test.dart
git commit -m "feat(friends): invite code generator (8-char, no ambiguous chars)"
```

---

### Task 1.3: Add `lib/models/friend_rank.dart`

**Files:**
- Create: `lib/models/friend_rank.dart`
- Create: `test/models/friend_rank_test.dart`

**Step 1: Write the failing test**

```dart
// test/models/friend_rank_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/models/friend_rank.dart';

void main() {
  group('FriendRank.buildLeaderboard', () {
    test('sorts entries DESC by weeklyXp, finds my index', () {
      final raw = [
        _entry('a', 'alice', 100),
        _entry('me', 'tralala', 250),
        _entry('b', 'bob', 320),
      ];
      final result = FriendRank.buildLeaderboard(
        entries: raw,
        myUid: 'me',
        currentMondayStr: '2026-05-11',
      );
      expect(result.length, 3);
      expect(result[0].uid, 'b');
      expect(result[0].rank, 1);
      expect(result[1].uid, 'me');
      expect(result[1].rank, 2);
      expect(result[1].isMe, true);
      expect(result[2].uid, 'a');
    });

    test('treats stale weeklyXpWeekStart as zero', () {
      final raw = [
        _entry('a', 'alice', 100, weekStart: '2026-05-04'), // stale
        _entry('me', 'tralala', 50, weekStart: '2026-05-11'),
      ];
      final result = FriendRank.buildLeaderboard(
        entries: raw,
        myUid: 'me',
        currentMondayStr: '2026-05-11',
      );
      expect(result[0].uid, 'me');
      expect(result[0].weeklyXp, 50);
      expect(result[1].uid, 'a');
      expect(result[1].weeklyXp, 0);
    });

    test('breaks ties stably by nickname', () {
      final raw = [
        _entry('b', 'bob', 100),
        _entry('a', 'alice', 100),
      ];
      final result = FriendRank.buildLeaderboard(
        entries: raw,
        myUid: '_other',
        currentMondayStr: '2026-05-11',
      );
      expect(result[0].uid, 'a'); // alphabetical fallback
      expect(result[1].uid, 'b');
    });
  });
}

FriendRankRaw _entry(String uid, String nickname, int xp,
    {String weekStart = '2026-05-11', int streak = 0}) {
  return FriendRankRaw(
    uid: uid,
    nickname: nickname,
    weeklyXp: xp,
    weeklyXpWeekStart: weekStart,
    streak: streak,
  );
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/models/friend_rank_test.dart`
Expected: FAIL — file not found.

**Step 3: Write minimal implementation**

```dart
// lib/models/friend_rank.dart
/// Raw input shape: read from Firestore user doc.
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

/// Sorted leaderboard row.
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

  /// Filters stale weeklyXp (week boundary crossed for that user but they
  /// haven't completed anything yet) to 0, sorts DESC, attaches rank+isMe.
  static List<FriendRank> buildLeaderboard({
    required List<FriendRankRaw> entries,
    required String myUid,
    required String currentMondayStr,
  }) {
    final normalized = entries.map((e) {
      final fresh = e.weeklyXpWeekStart == currentMondayStr;
      return FriendRankRaw(
        uid: e.uid,
        nickname: e.nickname,
        weeklyXp: fresh ? e.weeklyXp : 0,
        weeklyXpWeekStart: currentMondayStr,
        streak: e.streak,
      );
    }).toList();

    normalized.sort((a, b) {
      final byXp = b.weeklyXp.compareTo(a.weeklyXp);
      if (byXp != 0) return byXp;
      return a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase());
    });

    return [
      for (int i = 0; i < normalized.length; i++)
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
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/models/friend_rank_test.dart`
Expected: PASS (3 tests)

**Step 5: Commit**

```bash
git add lib/models/friend_rank.dart test/models/friend_rank_test.dart
git commit -m "feat(friends): FriendRank model with leaderboard builder"
```

---

### Task 1.4: Add `lib/services/friend_service.dart` skeleton

**Files:**
- Create: `lib/services/friend_service.dart`

**Step 1: Stub the service**

```dart
// lib/services/friend_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/invite_code.dart';
import '../utils/week_helpers.dart';
import '../models/friend_rank.dart';

class FriendService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Returns user's persistent invite code, generating one (with collision
  /// retry against userInvites/) if missing.
  Future<String> myInviteCode() async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');
    final userRef = _firestore.collection('users').doc(uid);
    final snap = await userRef.get();
    final existing = (snap.data()?['inviteCode'] as String?);
    if (existing != null && existing.isNotEmpty) return existing;

    // Generate with collision retry (max 5 attempts).
    for (int i = 0; i < 5; i++) {
      final code = generateInviteCode();
      final indexRef = _firestore.collection('userInvites').doc(code);
      final exists = (await indexRef.get()).exists;
      if (exists) continue;
      final batch = _firestore.batch();
      batch.set(indexRef, {'userId': uid});
      batch.update(userRef, {'inviteCode': code});
      await batch.commit();
      return code;
    }
    throw StateError('Could not generate unique invite code');
  }

  Future<void> regenerateInviteCode() async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');
    final userRef = _firestore.collection('users').doc(uid);
    final snap = await userRef.get();
    final old = (snap.data()?['inviteCode'] as String?);
    final batch = _firestore.batch();
    if (old != null && old.isNotEmpty) {
      batch.delete(_firestore.collection('userInvites').doc(old));
    }
    // Generate new
    for (int i = 0; i < 5; i++) {
      final code = generateInviteCode();
      final indexRef = _firestore.collection('userInvites').doc(code);
      if ((await indexRef.get()).exists) continue;
      batch.set(indexRef, {'userId': uid});
      batch.update(userRef, {'inviteCode': code});
      await batch.commit();
      return;
    }
    throw StateError('Could not generate unique invite code');
  }

  /// Resolves an invite code to the inviting user's profile. Null if not found.
  Future<Map<String, dynamic>?> resolveInvite(String code) async {
    final idx = await _firestore.collection('userInvites').doc(code).get();
    if (!idx.exists) return null;
    final uid = idx.data()!['userId'] as String;
    final user = await _firestore.collection('users').doc(uid).get();
    if (!user.exists) return null;
    return {'uid': uid, ...user.data()!};
  }

  /// Mutual add transaction. Idempotent.
  Future<void> addFriend(String otherUid) async {
    final myUid = _uid;
    if (myUid == null) throw StateError('Not signed in');
    if (otherUid == myUid) throw ArgumentError('Cannot friend yourself');

    final myRef = _firestore.collection('users').doc(myUid);
    final otherRef = _firestore.collection('users').doc(otherUid);

    final mySnap = await myRef.get();
    final otherSnap = await otherRef.get();
    final myNick = (mySnap.data()?['nickname'] as String?) ?? 'Hrac';
    final otherNick = (otherSnap.data()?['nickname'] as String?) ?? 'Hrac';

    final now = DateTime.now().toIso8601String();
    final batch = _firestore.batch();
    batch.set(
        myRef.collection('friends').doc(otherUid),
        {'nickname': otherNick, 'addedAt': now},
        SetOptions(merge: true));
    batch.set(
        otherRef.collection('friends').doc(myUid),
        {'nickname': myNick, 'addedAt': now},
        SetOptions(merge: true));
    // friend_added notif for the invite owner (deterministic doc id = idempotent)
    batch.set(
        otherRef.collection('notifications').doc('friend_added_$myUid'),
        {
          'type': 'friend_added',
          'fromNickname': myNick,
          'fromUid': myUid,
          'createdAt': now,
          'read': false,
        },
        SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> removeFriend(String otherUid) async {
    final myUid = _uid;
    if (myUid == null) return;
    final batch = _firestore.batch();
    batch.delete(_firestore
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(otherUid));
    batch.delete(_firestore
        .collection('users')
        .doc(otherUid)
        .collection('friends')
        .doc(myUid));
    await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> friendsStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'uid': d.id, ...d.data()})
            .toList());
  }

  /// Emits the leaderboard whenever any friend's `weeklyXp` changes.
  /// Listens to self + all friend user docs.
  Stream<List<FriendRank>> leaderboardStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return friendsStream().asyncExpand((friends) {
      final uids = [uid, ...friends.map((f) => f['uid'] as String)];
      // Watch all relevant user docs. Snapshot fan-in via combineLatest pattern.
      final streams = uids.map((u) =>
          _firestore.collection('users').doc(u).snapshots());
      return _combineLatest(streams).map((snapshots) {
        final mondayStr = mondayStringOf(DateTime.now());
        final raw = <FriendRankRaw>[];
        for (final s in snapshots) {
          if (!s.exists) continue;
          final d = s.data()!;
          raw.add(FriendRankRaw(
            uid: s.id,
            nickname: (d['nickname'] as String?) ?? 'Hrac',
            weeklyXp: (d['weeklyXp'] as int?) ?? 0,
            weeklyXpWeekStart: d['weeklyXpWeekStart'] as String?,
            streak: (d['streak'] as int?) ?? 0,
          ));
        }
        return FriendRank.buildLeaderboard(
          entries: raw,
          myUid: uid,
          currentMondayStr: mondayStr,
        );
      });
    });
  }

  // Tiny combineLatest helper — emits when any input stream emits, with
  // the latest snapshot from every input. Used by leaderboardStream.
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> _combineLatest(
      Iterable<Stream<DocumentSnapshot<Map<String, dynamic>>>> streams) async* {
    final list = streams.toList();
    if (list.isEmpty) {
      yield [];
      return;
    }
    final latest = List<DocumentSnapshot<Map<String, dynamic>>?>.filled(
        list.length, null);
    final controllers = <Stream<({int idx, DocumentSnapshot<Map<String, dynamic>> snap})>>[];
    for (int i = 0; i < list.length; i++) {
      controllers.add(list[i].map((s) => (idx: i, snap: s)));
    }
    await for (final event in _merge(controllers)) {
      latest[event.idx] = event.snap;
      if (latest.every((e) => e != null)) {
        yield latest.cast<DocumentSnapshot<Map<String, dynamic>>>();
      }
    }
  }

  Stream<T> _merge<T>(Iterable<Stream<T>> streams) async* {
    final controller = StreamController<T>();
    final subs = streams.map((s) => s.listen(controller.add,
        onError: controller.addError)).toList();
    try {
      await for (final v in controller.stream) {
        yield v;
      }
    } finally {
      for (final s in subs) {
        await s.cancel();
      }
    }
  }
}
```

(Note: `import 'dart:async';` needed for `StreamController`.)

**Step 2: Verify it compiles**

Run: `flutter analyze lib/services/friend_service.dart`
Expected: PASS (no issues). If `StreamController` undefined, add `import 'dart:async';` at top.

**Step 3: Commit**

```bash
git add lib/services/friend_service.dart
git commit -m "feat(friends): FriendService — invite, add/remove, leaderboard stream"
```

---

### Task 1.5: Update Firestore rules + deploy

**Files:**
- Modify: `firestore.rules` (add friends, userInvites, expand notification rules)

**Step 1: Read existing rules**

Open `firestore.rules` to understand current structure.

**Step 2: Add new match blocks**

Append before the closing brace of `service cloud.firestore { match /databases/{database}/documents { ... } }`:

```
match /userInvites/{code} {
  allow read: if request.auth != null;
  allow create: if request.auth.uid == request.resource.data.userId
                  && request.resource.data.keys().hasOnly(['userId']);
  allow delete: if request.auth.uid == resource.data.userId;
}

match /users/{userId}/friends/{friendId} {
  // Either side can read their own list, but not the other side's.
  allow read: if request.auth.uid == userId;
  // Mutual write: either party may write either edge (used by addFriend
  // transaction which writes both edges atomically).
  allow create, update: if request.auth != null
                          && (request.auth.uid == userId
                              || request.auth.uid == friendId);
  allow delete: if request.auth.uid == userId
                  || request.auth.uid == friendId;
}
```

Update existing `notifications` rule to allow cross-user create when sender is a friend:

```
match /users/{userId}/notifications/{notifId} {
  allow read, update, delete: if request.auth.uid == userId;
  // Owner can create freely; friends can create only friend_pending/friend_added types.
  allow create: if request.auth.uid == userId
                  || (request.auth != null
                      && exists(/databases/$(database)/documents/users/$(userId)/friends/$(request.auth.uid))
                      && request.resource.data.type in ['friend_pending', 'friend_added']);
}
```

Adjust the existing `users/{userId}` read rule to allow auth'd users to read other users' public-ish profile fields. If current rule is `allow read: if request.auth.uid == userId`, change to `allow read: if request.auth != null` (we rely on app-side never exposing private fields; if there are sensitive fields, list them in deny rules separately).

**Step 3: Deploy rules**

```bash
firebase deploy --only firestore:rules
```
Expected: `+ firestore: released rules`

**Step 4: Smoke-test existing flows**

In Playwright (logged-in dev account `sm@example.cz`):
- Open /calendar — should load tasks (no read error)
- Confirm a task — should succeed (no write error)
- Open /stats — should load
- Open /notifications — should load

If any breaks, narrow the new rule (compare deny vs allow) before proceeding.

**Step 5: Commit**

```bash
git add firestore.rules
git commit -m "feat(friends): firestore rules for friends, userInvites, friend-notifs"
```

---

### Phase 1 checkpoint

Run: `flutter analyze && flutter test`
Expected: clean + all tests green (existing 106 + new 12 = 118).

Manual: rules deployed without breaking existing flows.

---

## Phase 2: Invite + add friend (UI, deep link, mutual transaction)

Goal of phase: user A can share invite link from `/profile`, user B opens link and adds A, both see edges and A gets `friend_added` notif. No leaderboard rendering yet.

### Task 2.1: Add friends Strings

**Files:**
- Modify: `lib/constants/strings.dart`

**Step 1: Append to Strings**

```dart
  // Friends
  static const profileTitle = 'Profil';
  static const friendsHeader = 'KAMARADI';
  static const inviteHeader = 'TVUJ INVITE';
  static const shareInvite = 'Sdilet pozvanku';
  static const regenerateInvite = 'Regenerovat';
  static const addFriend = 'Pridat kamarada';
  static const inviteShareText =
      'Cau! Pridej me na Motivatoru. Otevri tenhle odkaz:\n';
  static const inviteScreenTitle = 'Pozvanka';
  static const inviteAddPrompt = 'Pridat jako kamarada?';
  static const inviteAddButton = 'Pridat';
  static const inviteOwnCode = 'Tohle je tvuj vlastni invite. Sdilej ho s kamarady.';
  static const inviteAlreadyFriend = 'uz je tvuj kamarad.';
  static const inviteNotFound = 'Pozvanka nenalezena. Mozna byla zrusena.';
  static const friendAddedToast = 'Pridano do kamaradu.';
  static const removeFriend = 'Odstranit z kamaradu';
  static const removeFriendConfirm = 'Odstranit z kamaradu?';
  static const noFriendsYet = 'Zatim zadne. Sdilej svou pozvanku.';
  static const leaderboardHeader = 'KAMARADI TENTO TYDEN';
  static const leaderboardEmpty = 'Pridej kamarade abys videl zebricek.';
  static const leaderboardMoreFmt = '+ {n} dalsi';  // {n} replaced at render
  static const friendPendingFmt = '{nickname} caka na potvrzeni';
  static const friendAddedNotifFmt = '{nickname} te pridal jako kamarada';
  static const xpThisWeekShort = 'XP tento tyden';
```

**Step 2: Run analyze**

Run: `flutter analyze lib/constants/strings.dart`
Expected: clean.

**Step 3: Commit**

```bash
git add lib/constants/strings.dart
git commit -m "feat(friends): czech strings for invite/friend flow"
```

---

### Task 2.2: Stub `/profile` page + register route

**Files:**
- Create: `lib/pages/profile_page.dart`
- Modify: `lib/main.dart` (add route)

**Step 1: Create page skeleton**

```dart
// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import '../constants/strings.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.profileTitle)),
      body: const Center(child: Text('TODO profile')),
    );
  }
}
```

**Step 2: Register route**

In `lib/main.dart`, find the `routes:` map and add:

```dart
'/profile': (_) => const ProfilePage(),
```

Import the page at the top:

```dart
import 'pages/profile_page.dart';
```

**Step 3: Run analyze**

Run: `flutter analyze`
Expected: clean.

**Step 4: Manual verification**

Run: `flutter run -d chrome`
Navigate to `https://localhost:PORT/#/profile`. Expected: page loads with title "Profil" and placeholder text.

**Step 5: Commit**

```bash
git add lib/pages/profile_page.dart lib/main.dart
git commit -m "feat(friends): stub /profile route"
```

---

### Task 2.3: Wire profile chip → /profile navigation

**Files:**
- Locate: profile chip widget (likely `lib/widgets/user_chip.dart` or inline in `calendar_page.dart`)
- Modify: that widget to `onTap: () => Navigator.pushNamed(context, '/profile')`

**Step 1: Locate the profile chip**

Run: `flutter analyze` doesn't help — use grep:

```bash
grep -rn "tralala\|UserChip\|profile.*chip\|nickname.*avatar" lib/
```

Most likely candidate: a widget rendered in AppBar.leading or AppBar.title. Could be in `lib/widgets/user_chip.dart`, or inline in `calendar_page.dart` / `stats_page.dart`.

**Step 2: Add tap handler**

Wrap the chip in `InkWell` or `GestureDetector` with `onTap: () => Navigator.pushNamed(context, '/profile')`. If it's a TitleChip widget, add `onTap` parameter, otherwise wrap inline.

Example for inline change:

```dart
// before:
return Row(children: [
  CircleAvatar(child: Text(nick[0].toUpperCase())),
  Text(nick),
]);

// after:
return InkWell(
  onTap: () => Navigator.pushNamed(context, '/profile'),
  borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(children: [
      CircleAvatar(child: Text(nick[0].toUpperCase())),
      const SizedBox(width: 8),
      Text(nick),
    ]),
  ),
);
```

**Step 3: Verify in Playwright**

After deploy: navigate to /calendar, click on the "T tralala" chip in top-left. Should navigate to /profile.

**Step 4: Commit**

```bash
git add lib/widgets/<location>.dart  # whichever file contained the chip
git commit -m "feat(friends): profile chip taps into /profile"
```

---

### Task 2.4: Profile page — render invite section

**Files:**
- Modify: `lib/pages/profile_page.dart` (full rewrite of body)

**Step 1: Replace stub with real content**

```dart
// lib/pages/profile_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';
import '../utils/context_extensions.dart';
import '../utils/ui_helpers.dart';
import '../widgets/neo_bottom_nav.dart';
import '../widgets/responsive_layout.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _friendService = FriendService();
  final _userService = UserService();
  String? _inviteCode;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  Future<void> _loadInvite() async {
    try {
      final code = await _friendService.myInviteCode();
      if (mounted) setState(() {
        _inviteCode = code;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _shareInvite() async {
    if (_inviteCode == null) return;
    final url = 'https://calendar-mot.web.app/#/friend?code=$_inviteCode';
    await SharePlus.instance.share(ShareParams(text: '${Strings.inviteShareText}$url'));
  }

  Future<void> _regenerate() async {
    setState(() => _loading = true);
    try {
      await _friendService.regenerateInviteCode();
      final code = await _friendService.myInviteCode();
      if (mounted) setState(() {
        _inviteCode = code;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.profileTitle)),
      body: ResponsiveLayout(
        child: ListView(
          padding: const EdgeInsets.all(NeoTheme.spaceMd),
          children: [
            Text(
              Strings.inviteHeader,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: isDark ? AppColors.textSecondary : Colors.black54,
              ),
            ),
            const SizedBox(height: NeoTheme.spaceSm),
            Container(
              decoration: NeoTheme.cardDecoration(isDark: isDark),
              padding: const EdgeInsets.symmetric(
                  horizontal: NeoTheme.spaceMd, vertical: NeoTheme.spaceMd),
              child: _loading
                  ? const SizedBox(
                      height: 24,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  : SelectableText(
                      _inviteCode ?? '—',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
            ),
            const SizedBox(height: NeoTheme.spaceSm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _shareInvite,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text(Strings.shareInvite),
                  ),
                ),
                const SizedBox(width: NeoTheme.spaceSm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _regenerate,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(Strings.regenerateInvite),
                  ),
                ),
              ],
            ),
            // TODO Task 2.7: friend list section
          ],
        ),
      ),
      bottomNavigationBar: const NeoBottomNav(currentIndex: -1),
    );
  }
}
```

(Note: `NeoBottomNav(currentIndex: -1)` means no tab highlighted. If that's not supported, omit the bottom nav for now.)

**Step 2: Verify deploys + invite generates**

After build + deploy + open `/profile` in Playwright:
- "TVUJ INVITE" header
- A code shows (8 chars)
- Sdilet + Regenerovat buttons

Verify the code persists by:

```js
// in browser console after page loads
await new Promise(r => setTimeout(r, 1000));
const code1 = document.body.innerText.match(/[A-Z2-9]{8}/)[0];
location.reload();
// after reload, same code
```

**Step 3: Commit**

```bash
git add lib/pages/profile_page.dart
git commit -m "feat(friends): profile page — invite code + share/regenerate"
```

---

### Task 2.5: FriendInviteScreen with edge cases

**Files:**
- Create: `lib/pages/friend_invite_screen.dart`
- Modify: `lib/main.dart` (route + deep link parsing)

**Step 1: Build the screen**

```dart
// lib/pages/friend_invite_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../services/friend_service.dart';
import '../utils/context_extensions.dart';
import '../utils/ui_helpers.dart';

class FriendInviteScreen extends StatefulWidget {
  final String code;
  const FriendInviteScreen({super.key, required this.code});
  @override
  State<FriendInviteScreen> createState() => _FriendInviteScreenState();
}

class _FriendInviteScreenState extends State<FriendInviteScreen> {
  final _service = FriendService();
  Map<String, dynamic>? _profile;
  String? _errorMsg;
  bool _alreadyFriend = false;
  bool _selfInvite = false;
  bool _loading = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final p = await _service.resolveInvite(widget.code);
    if (p == null) {
      setState(() {
        _errorMsg = Strings.inviteNotFound;
        _loading = false;
      });
      return;
    }
    // Self?
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (p['uid'] == myUid) {
      setState(() {
        _profile = p;
        _selfInvite = true;
        _loading = false;
      });
      return;
    }
    // Already friend?
    if (myUid != null) {
      final edge = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .doc(p['uid'] as String)
          .get();
      if (edge.exists) {
        setState(() {
          _profile = p;
          _alreadyFriend = true;
          _loading = false;
        });
        return;
      }
    }
    setState(() {
      _profile = p;
      _loading = false;
    });
  }

  Future<void> _add() async {
    if (_profile == null) return;
    setState(() => _adding = true);
    try {
      await _service.addFriend(_profile!['uid'] as String);
      if (mounted) {
        showSuccessSnack(context, Strings.friendAddedToast);
        Navigator.pushReplacementNamed(context, '/profile');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _adding = false);
        showErrorSnack(context, 'Chyba: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.inviteScreenTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(NeoTheme.spaceLg),
            child: _loading
                ? const CircularProgressIndicator()
                : _body(isDark),
          ),
        ),
      ),
    );
  }

  Widget _body(bool isDark) {
    if (_errorMsg != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_errorMsg!, textAlign: TextAlign.center),
          const SizedBox(height: NeoTheme.spaceMd),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(Strings.goBack),
          ),
        ],
      );
    }
    final nick = (_profile?['nickname'] as String?) ?? '—';
    final letter = nick.isEmpty ? '?' : nick[0].toUpperCase();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: context.primaryColor,
          child: Text(letter,
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black)),
        ),
        const SizedBox(height: NeoTheme.spaceMd),
        Text(nick,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: NeoTheme.spaceMd),
        if (_selfInvite)
          Text(Strings.inviteOwnCode, textAlign: TextAlign.center)
        else if (_alreadyFriend)
          Text('$nick ${Strings.inviteAlreadyFriend}',
              textAlign: TextAlign.center)
        else
          Text(Strings.inviteAddPrompt,
              textAlign: TextAlign.center),
        const SizedBox(height: NeoTheme.spaceLg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(Strings.cancel),
              ),
            ),
            if (!_selfInvite && !_alreadyFriend) ...[
              const SizedBox(width: NeoTheme.spaceSm),
              Expanded(
                child: ElevatedButton(
                  onPressed: _adding ? null : _add,
                  child: _adding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text(Strings.inviteAddButton),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
```

Note: `FirebaseAuth` import needed: `import 'package:firebase_auth/firebase_auth.dart';`.

**Step 2: Route registration with code param**

Flutter's named routes don't natively pass query params. The app already uses `app_links` for deep link parsing (per CLAUDE.md). Find where `/confirm?code=` is parsed and add analogous handler for `/friend?code=`.

Most likely the parsing is in `main.dart` inside an `onGenerateRoute` or in the deep link listener.

Pattern to follow:

```dart
// in main.dart's MaterialApp.onGenerateRoute or AppLinks listener
if (settings.name?.startsWith('/friend') == true) {
  final uri = Uri.parse(settings.name!);
  final code = uri.queryParameters['code'] ?? '';
  return MaterialPageRoute(builder: (_) => FriendInviteScreen(code: code));
}
```

If unsure, grep:

```bash
grep -n "code=\|queryParameters\|confirm" lib/main.dart
```

Add the friend handler mirroring the confirm handler.

**Step 3: Manual test**

After deploy:
- Open `https://calendar-mot.web.app/#/friend?code=INVALIDCODE` → "Pozvanka nenalezena." + Zpet
- Open `https://calendar-mot.web.app/#/friend?code=<my-own-code>` → self-invite screen
- (Second account in incognito) Open same URL → "Pridat tralala jako kamarada?" with Zrusit / Pridat

**Step 4: Commit**

```bash
git add lib/pages/friend_invite_screen.dart lib/main.dart
git commit -m "feat(friends): /friend?code= deep link with edge-case copies"
```

---

### Task 2.6: End-to-end friend add via Playwright

**Files:** none — test scenario.

This is a verification step before phase exit. Use two browser contexts (or 2 separate sessions in Playwright).

**Step 1: Session A — generate invite**

- Login as `sm@example.cz`
- Open `/profile`
- Read invite code from page (8-char string)
- Build URL: `https://calendar-mot.web.app/#/friend?code=<code>`

**Step 2: Session B — accept**

- Open second Playwright session (incognito or different account, e.g., register fresh smoke@example.cz)
- Navigate to friend URL
- Click "Pridat"
- Expect: redirect to /profile + success snackbar

**Step 3: Verify**

- In Session B's `/profile`, friend list area should later show A (Task 2.7 step). For now just check via Firestore console: `users/{B-uid}/friends/{A-uid}` and `users/{A-uid}/friends/{B-uid}` both exist.
- A's `users/{A-uid}/notifications/friend_added_{B-uid}` exists.

**Step 4: No commit** (just verification)

---

### Phase 2 checkpoint

Run: `flutter analyze && flutter test` — clean + green.

Manual: friend add flow works end-to-end on live deploy. Edge cases (self, already-friend, invalid code) all show correct copy.

---

## Phase 3: Friend list view (display + unfriend + delete-account cleanup)

Goal: friend list renders in `/profile`, long-press → unfriend with confirm, deleteAccount cleans up reverse edges.

### Task 3.1: Friend list section in profile_page

**Files:**
- Modify: `lib/pages/profile_page.dart`

**Step 1: Add friend list below invite section**

Replace the `// TODO Task 2.7: friend list section` comment with:

```dart
const SizedBox(height: NeoTheme.spaceLg),
Text(
  Strings.friendsHeader,
  style: TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
    color: isDark ? AppColors.textSecondary : Colors.black54,
  ),
),
const SizedBox(height: NeoTheme.spaceSm),
StreamBuilder<List<Map<String, dynamic>>>(
  stream: _friendService.friendsStream(),
  builder: (context, snap) {
    if (!snap.hasData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: NeoTheme.spaceMd),
        child: Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final friends = snap.data!;
    if (friends.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: NeoTheme.spaceMd),
        child: Text(
          Strings.noFriendsYet,
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: isDark ? AppColors.textSecondary : Colors.black54,
          ),
        ),
      );
    }
    return Column(
      children: friends.map((f) {
        final uid = f['uid'] as String;
        final nick = (f['nickname'] as String?) ?? '—';
        return GestureDetector(
          onLongPress: () => _confirmRemove(uid, nick),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(
                horizontal: NeoTheme.spaceMd, vertical: NeoTheme.spaceSm + 2),
            decoration: NeoTheme.cardDecoration(isDark: isDark),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: context.primaryColor,
                  child: Text(
                    nick.isEmpty ? '?' : nick[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: NeoTheme.spaceMd),
                Expanded(child: Text(nick,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
                // weekly XP/streak appended in Phase 5
              ],
            ),
          ),
        );
      }).toList(),
    );
  },
),
```

Add the `_confirmRemove` method:

```dart
Future<void> _confirmRemove(String uid, String nick) async {
  final isDark = context.isDark;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
        side: BorderSide(
          color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
          width: NeoTheme.borderWidth,
        ),
      ),
      title: const Text(Strings.removeFriendConfirm),
      content: Text(nick),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(Strings.cancel)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonPink,
              foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(Strings.delete),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await _friendService.removeFriend(uid);
}
```

**Step 2: Verify on live**

- /profile shows friends from Phase 2 test
- Long-press a card → confirm dialog → Smazat → friend disappears from both sides (verify second session refreshes)

**Step 3: Commit**

```bash
git add lib/pages/profile_page.dart
git commit -m "feat(friends): friend list + unfriend long-press in /profile"
```

---

### Task 3.2: Clean up reverse edges on deleteAccount

**Files:**
- Modify: `lib/services/auth_service.dart`

**Step 1: Locate deleteAccount**

```bash
grep -n "deleteAccount" lib/services/auth_service.dart
```

**Step 2: Add cleanup before account deletion**

Add inside `deleteAccount()`, before the existing user-doc delete (or wherever account data is removed):

```dart
// Clean up friend reverse edges so leaderboards don't show ghost rows.
final friendsSnap = await _firestore
    .collection('users')
    .doc(user.uid)
    .collection('friends')
    .get();
for (final f in friendsSnap.docs) {
  try {
    await _firestore
        .collection('users')
        .doc(f.id)
        .collection('friends')
        .doc(user.uid)
        .delete();
  } catch (_) {
    // best-effort: rule might forbid if friend already removed me, fine
  }
}
// Also drop the userInvites index entry so the code can be reused.
final userSnap = await _firestore.collection('users').doc(user.uid).get();
final myInviteCode = userSnap.data()?['inviteCode'] as String?;
if (myInviteCode != null && myInviteCode.isNotEmpty) {
  try {
    await _firestore.collection('userInvites').doc(myInviteCode).delete();
  } catch (_) {}
}
```

**Step 3: Manual test (do NOT delete production account)**

In a sacrificial test account: add a friend, then delete account, then in the other account check that the deleted user is no longer in `/profile` friend list. Skip if testing manually is too costly — code review of the cleanup is sufficient.

**Step 4: Commit**

```bash
git add lib/services/auth_service.dart
git commit -m "feat(friends): cleanup reverse edges + invite index on deleteAccount"
```

---

### Phase 3 checkpoint

Run: `flutter analyze && flutter test` clean + green.

Manual: friend list renders in /profile, unfriend removes from both sides, no orphan edges.

---

## Phase 4: Weekly XP plumbing (confirmTask update + nickname sync)

Goal: completing a task increments `weeklyXp` with lazy week reset. Nickname change propagates to all friend snapshots.

### Task 4.1: Update TaskService.confirmTask

**Files:**
- Modify: `lib/services/task_service.dart` (the `confirmTask` transaction)

**Step 1: Locate confirmTask transaction**

```bash
grep -n "confirmTask\|runTransaction" lib/services/task_service.dart
```

**Step 2: Add weeklyXp update**

Inside the existing transaction, after computing reward XP and before the user-doc `tx.update`, add:

```dart
import '../utils/week_helpers.dart';  // top of file
```

And inside the transaction (replace the existing user-doc update):

```dart
final mondayStr = mondayStringOf(DateTime.now());
final storedWeekStart = userData['weeklyXpWeekStart'] as String?;
final stale = storedWeekStart != mondayStr;
final newWeeklyXp = (stale ? 0 : (userData['weeklyXp'] as int? ?? 0)) + reward.xp;

tx.update(userRef, {
  // ...existing updates: xp, coins, level, streak, lastActiveDate
  'weeklyXp': newWeeklyXp,
  'weeklyXpWeekStart': mondayStr,
});
```

(Exact patch will depend on existing variable names. Don't break existing fields.)

**Step 3: Write a unit-style test (using `FakeFirebaseFirestore` if installed, or a simple call-tracking mock)**

Check whether the project uses any Firestore fake. If not, skip this test and rely on integration verification via Playwright.

```bash
grep -l "fake_cloud_firestore\|FakeFirebaseFirestore" pubspec.yaml test/
```

If fake exists, write `test/services/task_service_weekly_xp_test.dart`. If not, document and move on to integration.

**Step 4: Integration verify via Playwright**

- Note current `weeklyXp` value in Firestore console (or via JS in browser)
- Confirm a daily task (10 XP)
- Verify `weeklyXp` incremented by 10
- Verify `weeklyXpWeekStart` equals current Monday (yyyy-MM-dd)
- To test stale-week: manually edit `weeklyXpWeekStart` in Firestore to a previous Monday, then confirm another task. Expect `weeklyXp` resets to 0 + new reward.

**Step 5: Commit**

```bash
git add lib/services/task_service.dart
git commit -m "feat(friends): weekly XP increment + lazy week reset on confirmTask"
```

---

### Task 4.2: Nickname sync to friend snapshots

**Files:**
- Modify: `lib/services/user_service.dart` (`updateNickname`)
- Modify: `lib/services/friend_service.dart` (add helper)

**Step 1: Add helper in FriendService**

```dart
// In FriendService
Future<void> propagateNicknameUpdate(String newNickname) async {
  final uid = _uid;
  if (uid == null) return;
  final friendsSnap = await _firestore
      .collection('users')
      .doc(uid)
      .collection('friends')
      .get();
  for (final f in friendsSnap.docs) {
    try {
      await _firestore
          .collection('users')
          .doc(f.id)
          .collection('friends')
          .doc(uid)
          .update({'nickname': newNickname});
    } catch (_) {
      // friend may have unfriended, fine
    }
  }
}
```

**Step 2: Call from UserService.updateNickname**

```dart
// In UserService.updateNickname, after the existing update:
await FriendService().propagateNicknameUpdate(nickname);
```

**Step 3: Verify**

- In Session A `/settings` → Prezdivka edit → save
- In Session B `/profile`, friend list shows updated nickname (after stream rebuild)

**Step 4: Commit**

```bash
git add lib/services/user_service.dart lib/services/friend_service.dart
git commit -m "feat(friends): propagate nickname change to all friend snapshots"
```

---

### Phase 4 checkpoint

`flutter analyze && flutter test` — green.

Manual: confirm task → `weeklyXp` += reward. Edit nickname → reflected on friend side.

---

## Phase 5: Leaderboard rendering

Goal: `/profile` shows friends with weekly XP + streak, `/stats` shows compact leaderboard widget.

### Task 5.1: Enhance friend list rows with weekly XP

**Files:**
- Modify: `lib/pages/profile_page.dart` (replace `StreamBuilder` with leaderboard stream)

**Step 1: Swap friendsStream for leaderboardStream**

Replace the existing `StreamBuilder<List<Map<String, dynamic>>>` with:

```dart
StreamBuilder<List<FriendRank>>(
  stream: _friendService.leaderboardStream(),
  builder: (context, snap) {
    if (!snap.hasData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: NeoTheme.spaceMd),
        child: Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    // Drop self from the friend list display (self is shown in the header,
    // but we still want self in the sort to highlight rank).
    final entries = snap.data!.where((r) => !r.isMe).toList();
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: NeoTheme.spaceMd),
        child: Text(
          Strings.noFriendsYet,
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: isDark ? AppColors.textSecondary : Colors.black54,
          ),
        ),
      );
    }
    return Column(
      children: entries.map((e) => _FriendCard(
            rank: e.rank,
            uid: e.uid,
            nickname: e.nickname,
            weeklyXp: e.weeklyXp,
            streak: e.streak,
            isDark: isDark,
            onRemove: () => _confirmRemove(e.uid, e.nickname),
          )).toList(),
    );
  },
),
```

Add the `_FriendCard` widget at the bottom of the file:

```dart
class _FriendCard extends StatelessWidget {
  final int rank;
  final String uid;
  final String nickname;
  final int weeklyXp;
  final int streak;
  final bool isDark;
  final VoidCallback onRemove;

  const _FriendCard({
    required this.rank,
    required this.uid,
    required this.nickname,
    required this.weeklyXp,
    required this.streak,
    required this.isDark,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onRemove,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(
            horizontal: NeoTheme.spaceMd, vertical: NeoTheme.spaceSm + 2),
        decoration: NeoTheme.cardDecoration(isDark: isDark),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: context.primaryColor,
              child: Text(
                nickname.isEmpty ? '?' : nickname[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: NeoTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nickname,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          size: 12, color: AppColors.neonPink),
                      const SizedBox(width: 3),
                      Text('$streak', style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 8),
                      Text('· $weeklyXp ${Strings.xpThisWeekShort}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textSecondary
                                : Colors.black54,
                          )),
                    ],
                  ),
                ],
              ),
            ),
            Text('${rank}.',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textSecondary : Colors.black54)),
          ],
        ),
      ),
    );
  }
}
```

**Step 2: Verify**

- /profile shows friend cards with 🔥 + XP + rank
- Confirm a task in Session A; Session B's /profile updates rank in real-time

**Step 3: Commit**

```bash
git add lib/pages/profile_page.dart
git commit -m "feat(friends): leaderboard rows with weeklyXp/streak/rank"
```

---

### Task 5.2: Compact leaderboard widget in stats_page

**Files:**
- Modify: `lib/pages/stats_page.dart`

**Step 1: Add widget below metric cards**

After the `_MetricRow` and before the heatmap section, inject:

```dart
// Compact friends leaderboard. Hidden if user has no friends.
_LeaderboardWidget(isDark: isDark),
const SizedBox(height: NeoTheme.spaceLg),
```

Add the `_LeaderboardWidget` class at the bottom of `stats_page.dart`:

```dart
class _LeaderboardWidget extends StatelessWidget {
  final bool isDark;
  const _LeaderboardWidget({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendRank>>(
      stream: FriendService().leaderboardStream(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final ranks = snap.data!;
        // Hide widget entirely if user has no friends (own entry only)
        if (ranks.length <= 1) return const SizedBox.shrink();

        final top = ranks.take(3).toList();
        final more = ranks.length - top.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Strings.leaderboardHeader, style: NeoTheme.subhead),
            const SizedBox(height: NeoTheme.spaceSm),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/profile'),
              child: Container(
                decoration: NeoTheme.cardDecoration(isDark: isDark),
                padding: const EdgeInsets.all(NeoTheme.spaceMd),
                child: Column(
                  children: [
                    for (final r in top)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text('${r.rank}.',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                            ),
                            Expanded(
                              child: Text(
                                r.nickname,
                                style: TextStyle(
                                  fontWeight: r.isMe
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: r.isMe
                                      ? context.primaryColor
                                      : null,
                                ),
                              ),
                            ),
                            Text('${r.weeklyXp} XP',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    if (more > 0) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          Strings.leaderboardMoreFmt.replaceAll('{n}', '$more'),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondary
                                : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
```

Add imports at top:

```dart
import '../models/friend_rank.dart';
import '../services/friend_service.dart';
```

**Step 2: Verify**

- In Session B (which has friend A), /stats shows widget with both A and self ranked
- Tap widget → navigates to /profile
- In a session with no friends, widget is hidden

**Step 3: Commit**

```bash
git add lib/pages/stats_page.dart
git commit -m "feat(friends): compact leaderboard widget in /stats"
```

---

### Phase 5 checkpoint

Both views render. Real-time updates on confirm.

---

## Phase 6: Passive friend-feed (notif on photo upload + cleanup)

Goal: friend nahraje fotku → ostatní vidí friend_pending notif → tap = confirm bez kódu. Cleanup při confirm/reject/expire.

### Task 6.1: Notify friends when photo uploaded

**Files:**
- Modify: `lib/services/friend_service.dart` (add `notifyFriendsOfPendingTask`)
- Modify: `lib/widgets/task_card.dart` (call from `_savePhoto`)

**Step 1: Add method in FriendService**

```dart
Future<void> notifyFriendsOfPendingTask({
  required String taskId,
  required String taskTitle,
  required String code,
  String? thumbnailBase64,
}) async {
  final uid = _uid;
  if (uid == null) return;
  final mySnap = await _firestore.collection('users').doc(uid).get();
  final myNick = (mySnap.data()?['nickname'] as String?) ?? 'Hrac';
  final friendsSnap = await _firestore
      .collection('users')
      .doc(uid)
      .collection('friends')
      .get();
  final now = DateTime.now().toIso8601String();
  final batch = _firestore.batch();
  for (final f in friendsSnap.docs) {
    final ref = _firestore
        .collection('users')
        .doc(f.id)
        .collection('notifications')
        .doc('friend_pending_$taskId');  // deterministic
    batch.set(ref, {
      'type': 'friend_pending',
      'fromUid': uid,
      'fromNickname': myNick,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'code': code,
      if (thumbnailBase64 != null) 'thumbnailBase64': thumbnailBase64,
      'createdAt': now,
      'read': false,
    }, SetOptions(merge: true));
  }
  try {
    await batch.commit();
  } catch (_) {
    // best-effort: notif failure shouldn't block photo save
  }
}

Future<void> cleanupFriendPendingNotifs(String taskId) async {
  final uid = _uid;
  if (uid == null) return;
  final friendsSnap = await _firestore
      .collection('users')
      .doc(uid)
      .collection('friends')
      .get();
  final batch = _firestore.batch();
  for (final f in friendsSnap.docs) {
    batch.delete(_firestore
        .collection('users')
        .doc(f.id)
        .collection('notifications')
        .doc('friend_pending_$taskId'));
  }
  try {
    await batch.commit();
  } catch (_) {}
}
```

**Step 2: Hook into task_card._savePhoto**

In `lib/widgets/task_card.dart`, find `_savePhoto` (or whatever method does the photo upload). After the existing image save succeeds, add:

```dart
// After Firestore image write
await FriendService().notifyFriendsOfPendingTask(
  taskId: widget.task.id,
  taskTitle: widget.task.title,
  code: widget.task.code,
  thumbnailBase64: imageBase64,  // already compressed
);
```

(If `imageBase64` is too large for a notif, generate a smaller thumbnail or omit. Firestore doc limit is 1MB — base64 of 750KB image is ~1MB, will fail. Better: write only first 80x60 thumbnail or skip thumbnail entirely.)

**Decision:** omit `thumbnailBase64` for MVP — friend_pending notif shows just text + icon. Add thumbnail later if needed.

Remove the `thumbnailBase64` line from the call and from the optional field set.

**Step 3: Commit**

```bash
git add lib/services/friend_service.dart lib/widgets/task_card.dart
git commit -m "feat(friends): notify friends when photo uploaded"
```

---

### Task 6.2: Render friend_pending + friend_added notif types

**Files:**
- Modify: `lib/pages/notifications_page.dart`

**Step 1: Locate notif rendering**

```bash
grep -n "type.*==.*'confirmed'\|case.*'confirmed'\|switch.*type" lib/pages/notifications_page.dart
```

**Step 2: Add friend_pending + friend_added cases**

Inside the existing notif card builder (probably a switch on `notif.type`):

```dart
case 'friend_pending':
  borderColor = AppColors.neonGreen;
  icon = Icons.hourglass_top_rounded;
  title = '${notif.fromNickname} caka na potvrzeni';
  body = notif.taskTitle ?? '';
  onTap = () => Navigator.pushNamed(
      context, '/confirm', arguments: {'code': notif.code});
  break;
case 'friend_added':
  borderColor = AppColors.neonCyan;
  icon = Icons.person_add_rounded;
  title = '${notif.fromNickname} te pridal jako kamarada';
  body = '';
  onTap = () => Navigator.pushNamed(context, '/profile');
  break;
```

(Adapt to existing structure. If notifications use a model class, add the missing fields like `code` and `taskTitle` parsing in `fromMap`.)

**Step 3: Verify**

- In Session A: nahraj fotku na úkol
- In Session B: otevři /notifications — zelená karta "tralala caka na potvrzeni: huh"
- Tap → /confirm page se vyplněným kódem
- Confirm → notif zmizí (cleanup, Task 6.3)

**Step 4: Commit**

```bash
git add lib/pages/notifications_page.dart
# also lib/models/notification.dart if changed
git commit -m "feat(friends): render friend_pending + friend_added notifs"
```

---

### Task 6.3: Cleanup notifs on confirm/reject/expire

**Files:**
- Modify: `lib/services/task_service.dart` (`confirmTask`, `rejectTask`, expire flow)

**Step 1: After confirmTask transaction commits, call cleanup**

```dart
// At end of confirmTask, after tx commit
await FriendService().cleanupFriendPendingNotifs(taskId);
```

Same for `rejectTask` and wherever tasks expire (typically `checkExpiringTasks` or similar — grep for it).

**Step 2: Verify**

- Session A nahraje fotku → Session B vidí notif
- Session A potvrdí (kód flow) → Session B otevře /notifications → notif už není

**Step 3: Commit**

```bash
git add lib/services/task_service.dart
git commit -m "feat(friends): cleanup friend_pending notifs on task resolve"
```

---

### Phase 6 checkpoint

Full feedback loop: A upload → B notif → B tap → B confirm → notif vanishes.

---

## Phase 7: Polish

Goal: copy review, empty states, error toasts, manual QA.

### Task 7.1: Empty state pass

- `/profile` no invite yet (network slow): loading spinner shown, no crash.
- `/profile` no friends: empty state copy ("Zatim zadne. Sdilej svou pozvanku.")
- `/stats` no friends: leaderboard widget hidden (don't show "Empty leaderboard" placeholder)
- `/notifications` no notifs: existing `Strings.noNotifications` ("Klid. Nikdo se neozyva.") still works.

### Task 7.2: Error toast pass

- `addFriend` fails (network) → "Chyba pri pridavani kamarada."
- `removeFriend` fails → "Chyba pri odstranovani."
- Invite code resolve fails (network) → loading spinner stays + retry button? Or just inviteNotFound copy. Decide based on UX feel.

### Task 7.3: Manual QA via Playwright

Two-session test:
- Account A: register fresh
- Account B: register fresh
- A generates invite → shares URL
- B opens URL → adds A → confirm both edges + notif
- A nahraje úkol → B vidí pending notif → confirms → A gets XP + reward toast
- B's /profile shows A with weekly XP
- A's /stats shows leaderboard widget with both
- B unfriends A → A no longer in B's list (and vice versa, since mutual delete)
- B regenerates invite → old URL stops working
- A edits nickname → B sees updated nick in /profile after stream refresh

### Task 7.4: Final commit + deploy

```bash
git add -A docs/plans/  # in case of plan doc tweaks during execution
git commit -m "polish: copy + empty states + qa pass for friends/leaderboard"
flutter build web
firebase deploy --only hosting,firestore:rules
```

### Task 7.5: Memory update

Update `~/.claude/projects/.../memory/project_v2_push.md`: move "Friends + leaderboard" to DONE list with deploy date + commit hash.

---

## Risks & known unknowns

| Risk | Mitigation |
|------|------------|
| Firestore rules block existing flows after rule update | Smoke test stávající flows v Task 1.5 — pokud break, narrow new rules a redeploy |
| `combineLatest` helper in FriendService is custom + might have edge bugs | Smoke-test leaderboardStream manually; if unstable, fall back to polling `friendsStream + Future.wait` |
| Friend deletes account → ghost row | Task 3.2 cleans reverse edges, but if cleanup fails partway, leftover edge points to nonexistent user — `leaderboardStream` filter via `if (!s.exists) continue` handles it |
| Notification doc size limit | We skipped `thumbnailBase64` in MVP. If user wants thumbnail later, generate 80x60 (≤20KB base64) |
| Web Share API not available on desktop browsers | `SharePlus` falls back to clipboard on desktop. Test on Chrome — code copied to clipboard with toast |

## Time estimate

- Phase 1: 2h
- Phase 2: 3h
- Phase 3: 1h
- Phase 4: 1h
- Phase 5: 2h
- Phase 6: 2h
- Phase 7: 1.5h

Total: ~12h focused work. Plan for 2-3 sessions.
