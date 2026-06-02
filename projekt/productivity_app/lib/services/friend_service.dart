import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/activity_feed_item.dart';
import '../models/friend_profile.dart';
import '../models/friend_rank.dart';
import '../models/nickname_search_result.dart';
import '../models/weekly_winner.dart';
import '../utils/date_helpers.dart';
import '../utils/invite_code.dart';
import '../utils/nickname_search.dart';
import '../utils/week_helpers.dart';

/// Service for friends + invite codes + leaderboard.
///
/// Phase 1: skeleton only. No automated tests in this file — requires
/// Firestore mocking (deferred to integration in later phases).
class FriendService {
  static FriendService? _instance;
  factory FriendService() => _instance ??= FriendService._();
  FriendService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int _kInviteCollisionRetries = 5;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _inviteDoc(String code) =>
      _firestore.collection('userInvites').doc(code);

  CollectionReference<Map<String, dynamic>> _friendsCol(String uid) =>
      _userDoc(uid).collection('friends');

  CollectionReference<Map<String, dynamic>> _notifsCol(String uid) =>
      _userDoc(uid).collection('notifications');

  /// Returns the current user's invite code, generating + persisting it on
  /// first call. Retries on collision up to [_kInviteCollisionRetries] times.
  ///
  /// Writes:
  ///   - `userInvites/{code} = {userId: uid}`
  ///   - `users/{uid}.inviteCode = code`
  /// Both in one batch so they cannot diverge.
  Future<String> myInviteCode() async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Uzivatel neni prihlasen — nelze ziskat invite kod.');
    }

    final mySnap = await _userDoc(uid).get();
    final existing = (mySnap.data() ?? const {})['inviteCode'] as String?;
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    for (var attempt = 0; attempt < _kInviteCollisionRetries; attempt++) {
      final code = generateInviteCode();
      final inviteSnap = await _inviteDoc(code).get();
      if (inviteSnap.exists) continue;

      final batch = _firestore.batch();
      batch.set(_inviteDoc(code), {'userId': uid});
      batch.set(_userDoc(uid), {'inviteCode': code}, SetOptions(merge: true));
      await batch.commit();
      return code;
    }

    throw StateError('Nepodarilo se vygenerovat unikatni invite kod (5 pokusu).');
  }

  /// Deletes the user's current invite code (if any) and issues a new one.
  /// Old invite links silently stop working.
  Future<void> regenerateInviteCode() async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Uzivatel neni prihlasen — nelze regenerovat invite kod.');
    }

    final mySnap = await _userDoc(uid).get();
    final oldCode = (mySnap.data() ?? const {})['inviteCode'] as String?;

    for (var attempt = 0; attempt < _kInviteCollisionRetries; attempt++) {
      final newCode = generateInviteCode();
      if (newCode == oldCode) continue;
      final inviteSnap = await _inviteDoc(newCode).get();
      if (inviteSnap.exists) continue;

      final batch = _firestore.batch();
      if (oldCode != null && oldCode.isNotEmpty) {
        batch.delete(_inviteDoc(oldCode));
      }
      batch.set(_inviteDoc(newCode), {'userId': uid});
      batch.set(_userDoc(uid), {'inviteCode': newCode}, SetOptions(merge: true));
      await batch.commit();
      return;
    }

    throw StateError('Nepodarilo se vygenerovat unikatni invite kod (5 pokusu).');
  }

  /// Looks up an invite code and returns the target user's public data, or
  /// `null` if the code is invalid or the user doc is missing.
  ///
  /// Returned map shape: `{uid: <userId>, ...users/{userId}.data}`.
  Future<Map<String, dynamic>?> resolveInvite(String code) async {
    final inviteSnap = await _inviteDoc(code).get();
    if (!inviteSnap.exists) return null;
    final inviteData = inviteSnap.data();
    if (inviteData == null) return null;
    final targetUid = inviteData['userId'] as String?;
    if (targetUid == null || targetUid.isEmpty) return null;

    final userSnap = await _userDoc(targetUid).get();
    if (!userSnap.exists) return null;
    return {
      'uid': targetUid,
      ...?userSnap.data(),
    };
  }

  /// Adds [otherUid] as a friend (mutual). Writes both edges + a
  /// deterministic `friend_added_{myUid}` notif in the other's inbox so the
  /// operation is idempotent on retry.
  Future<void> addFriend(String otherUid) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Uzivatel neni prihlasen — nelze pridat kamarada.');
    }
    if (uid == otherUid) {
      throw StateError('Nemuzes pridat sam sebe.');
    }

    final mySnap = await _userDoc(uid).get();
    final otherSnap = await _userDoc(otherUid).get();
    if (!otherSnap.exists) {
      throw StateError('Uzivatel nenalezen.');
    }
    final myNickname = (mySnap.data() ?? const {})['nickname'] as String? ?? '';
    final otherNickname = (otherSnap.data() ?? const {})['nickname'] as String? ?? '';
    final addedAt = nowMinuteString();

    // The two mutual edges are the essential write and go in one atomic batch.
    // Both are always permitted (each party may write either edge), so this
    // commit cannot fail on rules — the friendship is created reliably.
    final batch = _firestore.batch();

    // Edge: me -> other (stores other's nickname snapshot)
    batch.set(
      _friendsCol(uid).doc(otherUid),
      {'nickname': otherNickname, 'addedAt': addedAt},
      SetOptions(merge: true),
    );

    // Edge: other -> me (stores my nickname snapshot)
    batch.set(
      _friendsCol(otherUid).doc(uid),
      {'nickname': myNickname, 'addedAt': addedAt},
      SetOptions(merge: true),
    );

    await batch.commit();

    // Notif to the other's inbox — best-effort, decoupled from the edge batch.
    // A non-owner may only *create* a notif, not update one; if a stale
    // `friend_added_$uid` somehow survives (e.g. cleanup didn't run), the
    // set-as-update would be denied. Keeping it out of the batch means that
    // can never roll back the friendship. Deterministic id -> idempotent.
    try {
      await _notifsCol(otherUid).doc('friend_added_$uid').set(
        {
          'type': 'friend_added',
          'fromNickname': myNickname,
          'fromUid': uid,
          'createdAt': addedAt,
          'read': false,
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // best-effort — a notif glitch must not surface as an "add failed" error
    }
  }

  /// Updates the denormalized nickname snapshot in every friend's
  /// friends/{me} edge so leaderboards display the latest name.
  /// Best-effort: silently skips friends where the write fails
  /// (e.g. they unfriended me).
  Future<void> propagateNicknameUpdate(String newNickname) async {
    final uid = _uid;
    if (uid == null) return;
    final friendsSnap = await _friendsCol(uid).get();
    for (final f in friendsSnap.docs) {
      try {
        await _friendsCol(f.id).doc(uid).update({'nickname': newNickname});
      } catch (_) {
        // friend may have unfriended — fine
      }
    }
  }

  /// Writes a `friend_pending` notif to every friend's inbox so they see
  /// the task in their feed and can confirm without copying the code.
  /// Deterministic doc id: `friend_pending_{taskId}`.
  ///
  /// Written per-friend, NOT as one atomic batch: on a photo re-upload the doc
  /// already exists in friends' inboxes, and a non-owner may only *create* a
  /// notif, not update one (see rules). In a single batch that one denied
  /// update would roll back EVERY friend's write — so a re-upload would notify
  /// nobody, including friends added since the first upload. Independent writes
  /// let the creates succeed; the redundant updates fail harmlessly (the
  /// existing notif already carries the same code + task). Best-effort
  /// throughout: a notif glitch must never block the user's photo save.
  Future<void> notifyFriendsOfPendingTask({
    required String taskId,
    required String taskTitle,
    required String code,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final mySnap = await _userDoc(uid).get();
    final myNick = (mySnap.data()?['nickname'] as String?) ?? 'Hráč';
    final friendsSnap = await _friendsCol(uid).get();
    if (friendsSnap.docs.isEmpty) return;
    final payload = {
      'type': 'friend_pending',
      'fromUid': uid,
      'fromNickname': myNick,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'code': code,
      'createdAt': nowMinuteString(),
      'read': false,
    };
    await Future.wait(friendsSnap.docs.map((f) async {
      try {
        await _notifsCol(f.id)
            .doc('friend_pending_$taskId')
            .set(payload, SetOptions(merge: true));
      } catch (_) {
        // Already-present notif -> cross-user update is denied. Fine: the
        // friend still holds an actionable notif for the same task.
      }
    }));
  }

  /// Removes the `friend_pending` notif for [taskId] from every friend's inbox.
  /// Called by the OWNER when the task is confirmed/rejected/expired so the
  /// friend-feed stays in sync. Best-effort.
  Future<void> cleanupFriendPendingNotifs(String taskId) async {
    final uid = _uid;
    if (uid == null) return;
    final friendsSnap = await _friendsCol(uid).get();
    if (friendsSnap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final f in friendsSnap.docs) {
      batch.delete(_notifsCol(f.id).doc('friend_pending_$taskId'));
    }
    try {
      await batch.commit();
    } catch (_) {
      // best-effort
    }
  }

  /// Removes the mutual friendship with [otherUid]. Silent (no notif).
  ///
  /// Also clears the deterministic `friend_added_*` notif from whichever
  /// inbox holds it. This matters: without it the notif survives the unfriend,
  /// and a later re-add — which writes the same doc id via `set(merge)` —
  /// becomes an *update* of a cross-user notif, which the rules forbid for
  /// non-owners, so `addFriend`'s batch would fail. Deleting it here keeps the
  /// re-add path a clean `create`. Both deletes are permitted: I'm the inbox
  /// owner of one, and the original `fromUid` (sender) of the other.
  Future<void> removeFriend(String otherUid) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Uzivatel neni prihlasen — nelze odebrat kamarada.');
    }

    final batch = _firestore.batch();
    batch.delete(_friendsCol(uid).doc(otherUid));
    batch.delete(_friendsCol(otherUid).doc(uid));
    // Notif I sent when I added them (lives in their inbox; I'm fromUid).
    batch.delete(_notifsCol(otherUid).doc('friend_added_$uid'));
    // Notif they sent when they added me (lives in my inbox; I'm owner).
    batch.delete(_notifsCol(uid).doc('friend_added_$otherUid'));
    await batch.commit();
  }

  /// Returns the public-ish snapshot of another user's profile. Returns null
  /// if the user doc doesn't exist or the caller isn't authenticated.
  ///
  /// Reads `users/{otherUid}` plus two `count()` aggregate queries against
  /// the `achievements/` and `tasks where completed=true` subcollections.
  /// Weekly XP is normalised the same way the leaderboard does it —
  /// if the stored `weeklyXpWeekStart` is not the current Monday, the
  /// stored counter is stale and `weeklyXp` is reported as 0.
  Future<FriendProfile?> loadFriendProfile(String otherUid) async {
    if (_uid == null) return null;
    final userDoc = await _firestore.collection('users').doc(otherUid).get();
    if (!userDoc.exists) return null;
    final data = userDoc.data()!;
    final achievementsCount = (await _firestore
                .collection('users')
                .doc(otherUid)
                .collection('achievements')
                .count()
                .get())
            .count ??
        0;
    final tasksCount = (await _firestore
                .collection('users')
                .doc(otherUid)
                .collection('tasks')
                .where('completed', isEqualTo: true)
                .count()
                .get())
            .count ??
        0;
    final mondayStr = mondayStringOf(DateTime.now());
    final weekStartStored = data['weeklyXpWeekStart'] as String?;
    final freshWeeklyXp = weekStartStored == mondayStr
        ? (data['weeklyXp'] as int? ?? 0)
        : 0;
    return FriendProfile(
      uid: otherUid,
      nickname: (data['nickname'] as String?) ?? 'Hráč',
      xp: (data['xp'] as int?) ?? 0,
      coins: (data['coins'] as int?) ?? 0,
      level: (data['level'] as int?) ?? 1,
      streak: (data['streak'] as int?) ?? 0,
      weeklyXp: freshWeeklyXp,
      activeTitleId: data['activeTitle'] as String?,
      achievementsUnlockedCount: achievementsCount,
      totalCompletedTasks: tasksCount,
    );
  }

  /// Stream of the current user's friend list. Each entry:
  /// `{uid: <docId>, nickname: ..., addedAt: ...}`.
  Stream<List<Map<String, dynamic>>> friendsStream() {
    final uid = _uid;
    if (uid == null) {
      return Stream<List<Map<String, dynamic>>>.value(const []);
    }
    return _friendsCol(uid).snapshots().map((snap) => snap.docs
        .map((d) => {'uid': d.id, ...d.data()})
        .toList(growable: false));
  }

  /// Live friend-activity stream: latest unlocked achievements across all
  /// friends, merged + sorted DESC by [ActivityFeedItem.unlockedAt].
  ///
  /// Per-friend query: `users/{uid}/achievements.orderBy(unlockedAt desc)
  /// .limit(perFriendLimit)`. Total feed capped at [limit]. When the friends
  /// list changes, subscriptions are torn down and rebuilt — same pattern
  /// as [leaderboardStream].
  Stream<List<ActivityFeedItem>> activityFeedStream({
    int limit = 20,
    int perFriendLimit = 10,
  }) {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    late StreamController<List<ActivityFeedItem>> controller;
    StreamSubscription<List<Map<String, dynamic>>>? friendsSub;
    StreamSubscription<List<ActivityFeedItem>>? combinedSub;

    Future<void> rebuildFor(List<Map<String, dynamic>> friends) async {
      await combinedSub?.cancel();
      combinedSub = null;
      if (friends.isEmpty) {
        if (!controller.isClosed) controller.add(const []);
        return;
      }
      // uid → nickname snapshot from the friend list, used to denormalize
      // into each feed item without a per-friend user-doc read.
      final nicknameByUid = <String, String>{
        for (final f in friends)
          (f['uid'] as String): (f['nickname'] as String?) ?? '',
      };
      final queryStreams = friends.map((f) {
        final fuid = f['uid'] as String;
        return _userDoc(fuid)
            .collection('achievements')
            .orderBy('unlockedAt', descending: true)
            .limit(perFriendLimit)
            .snapshots();
      }).toList();

      combinedSub = _combineLatestQuery(queryStreams).map((snaps) {
        final items = <ActivityFeedItem>[];
        for (int i = 0; i < snaps.length; i++) {
          final friendUid = friends[i]['uid'] as String;
          final nick = nicknameByUid[friendUid] ?? '';
          for (final doc in snaps[i].docs) {
            final data = doc.data();
            final unlockedAt = data['unlockedAt'] as String?;
            if (unlockedAt == null || unlockedAt.isEmpty) continue;
            items.add(ActivityFeedItem(
              friendUid: friendUid,
              friendNickname: nick,
              achievementId: doc.id,
              unlockedAt: unlockedAt,
            ));
          }
        }
        items.sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
        if (items.length > limit) {
          return items.sublist(0, limit);
        }
        return items;
      }).listen(controller.add, onError: controller.addError);
    }

    controller = StreamController<List<ActivityFeedItem>>(
      onListen: () {
        friendsSub = friendsStream().listen(
          rebuildFor,
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await friendsSub?.cancel();
        await combinedSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Live leaderboard stream: self + each friend, sorted DESC by weekly XP.
  ///
  /// Re-subscribes to per-user doc streams whenever the friends list itself
  /// changes (add/remove). Within a stable friends list, updates flow from
  /// any user doc changing (XP confirm, nickname rename, etc.).
  ///
  /// Subscription lifecycle is managed explicitly via a [StreamController] so
  /// that the inner `_combineLatest` subscription is cancelled deterministically
  /// when the friends list changes (avoids leaking Firestore listeners).
  Stream<List<FriendRank>> leaderboardStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    late StreamController<List<FriendRank>> controller;
    StreamSubscription<List<Map<String, dynamic>>>? friendsSub;
    StreamSubscription<List<FriendRank>>? combinedSub;

    Future<void> rebuildFor(List<Map<String, dynamic>> friends) async {
      await combinedSub?.cancel();
      combinedSub = null;
      final allUids = <String>{uid, ...friends.map((f) => f['uid'] as String)}
          .toList();
      final docStreams =
          allUids.map((u) => _userDoc(u).snapshots()).toList();
      // mondayStr is computed once per friends-list change. Acceptable: weekly
      // boundary only matters at midnight Sunday→Monday, when the user-doc
      // stream will re-emit anyway (weeklyXpWeekStart gets re-stamped on next
      // XP write), so any staleness is self-correcting.
      final mondayStr = mondayStringOf(DateTime.now());
      combinedSub = _combineLatest(docStreams).map((snaps) {
        final raw = <FriendRankRaw>[];
        for (final s in snaps) {
          final data = s.data();
          if (data == null) continue;
          raw.add(FriendRankRaw(
            uid: s.id,
            nickname: (data['nickname'] as String?) ?? '',
            weeklyXp: (data['weeklyXp'] as int?) ?? 0,
            weeklyXpWeekStart: data['weeklyXpWeekStart'] as String?,
            streak: (data['streak'] as int?) ?? 0,
          ));
        }
        return FriendRank.buildLeaderboard(
          entries: raw,
          myUid: uid,
          currentMondayStr: mondayStr,
        );
      }).listen(controller.add, onError: controller.addError);
    }

    controller = StreamController<List<FriendRank>>(
      onListen: () {
        friendsSub = friendsStream().listen(
          rebuildFor,
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await friendsSub?.cancel();
        await combinedSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Global leaderboard stream — top [limit] opt-in (`discoverable=true`)
  /// users by weeklyXp this week.
  ///
  /// The query is scoped to `weeklyXpWeekStart == this Monday` so the server
  /// only ranks users who actually scored *this* week. Without that filter the
  /// server ordered by raw `weeklyXp DESC` and the top slots at the start of a
  /// new week were filled by people still carrying last week's (stale) total —
  /// which the client then zeroes, pushing the real current leader out of the
  /// `limit` window entirely. Requires composite index
  /// `users (discoverable ASC, weeklyXpWeekStart ASC, weeklyXp DESC)`.
  Stream<List<FriendRank>> globalLeaderboardStream({int limit = 20}) {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    final mondayStr = mondayStringOf(DateTime.now());
    return _firestore
        .collection('users')
        .where('discoverable', isEqualTo: true)
        .where('weeklyXpWeekStart', isEqualTo: mondayStr)
        .orderBy('weeklyXp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final raw = <FriendRankRaw>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        raw.add(FriendRankRaw(
          uid: doc.id,
          nickname: (data['nickname'] as String?) ?? '',
          weeklyXp: (data['weeklyXp'] as int?) ?? 0,
          weeklyXpWeekStart: data['weeklyXpWeekStart'] as String?,
          streak: (data['streak'] as int?) ?? 0,
        ));
      }
      return FriendRank.buildLeaderboard(
        entries: raw,
        myUid: uid,
        currentMondayStr: mondayStr,
      );
    });
  }

  /// Case-insensitive prefix search of opt-in discoverable users by nickname.
  /// Filters out the current user and existing friends client-side so we
  /// don't list people the user can't usefully act on.
  ///
  /// Returns up to [limit] results. Empty query returns the empty list
  /// without hitting Firestore.
  Future<List<NicknameSearchResult>> searchByNickname(
    String query, {
    int limit = 20,
  }) async {
    final q = nicknameSearchKey(query);
    if (q.isEmpty) return const [];
    final uid = _uid;

    // Build a friends-set client-side so we can hide already-mutual rows.
    final friendsIds = <String>{};
    if (uid != null) {
      try {
        final friendsSnap = await _friendsCol(uid).get();
        friendsIds.addAll(friendsSnap.docs.map((d) => d.id));
      } catch (_) {/* fall back to unfiltered */}
    }

    final qSnap = await _firestore
        .collection('users')
        .where('discoverable', isEqualTo: true)
        .where('nicknameLower', isGreaterThanOrEqualTo: q)
        .where('nicknameLower', isLessThan: nicknamePrefixUpperBound(q))
        .limit(limit)
        .get();

    final results = <NicknameSearchResult>[];
    for (final doc in qSnap.docs) {
      if (doc.id == uid) continue; // self
      if (friendsIds.contains(doc.id)) continue; // already friend
      final data = doc.data();
      results.add(NicknameSearchResult(
        uid: doc.id,
        nickname: (data['nickname'] as String?) ?? '',
        level: (data['level'] as int?) ?? 1,
      ));
    }
    return results;
  }

  /// Returns the [WeeklyWinner] for last week from this user's perspective,
  /// creating the snapshot on first call of a new week. Subsequent calls in
  /// the same week return the cached version, so reads stay cheap.
  ///
  /// Tradeoff (documented in design doc 2026-05-27): if a friend confirms a
  /// task on Monday morning before this user opens the app, their weeklyXp
  /// is already reset and they won't contribute to the snapshot. Acceptable
  /// for an MVP without a server-side cron.
  ///
  /// Returns null when the user is not authenticated.
  Future<WeeklyWinner?> fetchOrCreateLastWeekSnapshot() async {
    final uid = _uid;
    if (uid == null) return null;
    final now = DateTime.now();
    final lastWeekMonday =
        mondayStringOf(now.subtract(const Duration(days: 7)));

    final snapRef =
        _userDoc(uid).collection('weeklyWinners').doc(lastWeekMonday);

    // Cache read: best-effort. If rules deny (e.g. pre-deploy state) we
    // just fall through to recompute — UI degrades to "always-fresh" instead
    // of blank.
    try {
      final existing = await snapRef.get();
      if (existing.exists) {
        return WeeklyWinner.fromMap(existing.data()!);
      }
    } catch (_) {/* fall through to compute */}

    // Build participant list: self + each friend's user doc.
    final friendsSnap = await _friendsCol(uid).get();
    final allUids = <String>{uid, ...friendsSnap.docs.map((d) => d.id)};
    final docs = await Future.wait(
      allUids.map((u) => _userDoc(u).get()),
    );

    final participants = <WeeklyParticipant>[];
    for (final doc in docs) {
      final data = doc.data();
      if (data == null) continue;
      participants.add(WeeklyParticipant(
        uid: doc.id,
        nickname: (data['nickname'] as String?) ?? '',
        weeklyXp: (data['weeklyXp'] as int?) ?? 0,
        weeklyXpWeekStart: data['weeklyXpWeekStart'] as String?,
      ));
    }

    final winner = pickWeeklyWinner(
      participants: participants,
      weekStart: lastWeekMonday,
      capturedAt: nowMinuteString(),
      myUid: uid,
    );

    // Persist so the next /profile open in the same week is a single doc
    // read instead of N+1 reads. Best-effort: tolerates rules denial.
    try {
      await snapRef.set(winner.toMap());
    } catch (_) {/* best-effort */}

    return winner;
  }

  /// Same shape as [_combineLatest] but fans in QuerySnapshot streams
  /// (collection queries) instead of single-doc snapshots.
  Stream<List<QuerySnapshot<Map<String, dynamic>>>> _combineLatestQuery(
      List<Stream<QuerySnapshot<Map<String, dynamic>>>> streams) {
    if (streams.isEmpty) {
      return Stream.value(<QuerySnapshot<Map<String, dynamic>>>[]);
    }
    late StreamController<List<QuerySnapshot<Map<String, dynamic>>>> controller;
    final latest = List<QuerySnapshot<Map<String, dynamic>>?>.filled(
        streams.length, null);
    final subs = <StreamSubscription>[];

    controller = StreamController<List<QuerySnapshot<Map<String, dynamic>>>>(
      onListen: () {
        for (int i = 0; i < streams.length; i++) {
          final idx = i;
          subs.add(streams[i].listen(
            (snap) {
              latest[idx] = snap;
              if (latest.every((x) => x != null) && !controller.isClosed) {
                controller.add(
                  [...latest.cast<QuerySnapshot<Map<String, dynamic>>>()],
                );
              }
            },
            onError: (err, st) {
              if (!controller.isClosed) controller.addError(err, st);
            },
          ));
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
        subs.clear();
      },
    );
    return controller.stream;
  }

  /// Combines a list of single-doc snapshot streams into one stream that
  /// emits whenever ANY input emits, once all inputs have produced at least
  /// one value. Order in the emitted list matches the input list. Subscriptions
  /// and the internal controller are cleaned up when the consumer cancels.
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> _combineLatest(
      List<Stream<DocumentSnapshot<Map<String, dynamic>>>> streams) {
    if (streams.isEmpty) {
      return Stream.value(<DocumentSnapshot<Map<String, dynamic>>>[]);
    }
    late StreamController<List<DocumentSnapshot<Map<String, dynamic>>>> controller;
    final latest = List<DocumentSnapshot<Map<String, dynamic>>?>.filled(
        streams.length, null);
    final subs = <StreamSubscription>[];

    controller = StreamController<List<DocumentSnapshot<Map<String, dynamic>>>>(
      onListen: () {
        for (int i = 0; i < streams.length; i++) {
          final idx = i;
          subs.add(streams[i].listen(
            (snap) {
              latest[idx] = snap;
              if (latest.every((x) => x != null) && !controller.isClosed) {
                // Emit a defensive copy — consumer must not see future
                // in-place mutations as new inner events arrive.
                controller.add(
                  [...latest.cast<DocumentSnapshot<Map<String, dynamic>>>()],
                );
              }
            },
            onError: (err, st) {
              if (!controller.isClosed) controller.addError(err, st);
            },
          ));
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
        subs.clear();
        // Don't close the controller in onCancel — Dart will dispose it.
      },
    );
    return controller.stream;
  }
}
