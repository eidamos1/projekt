import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_rank.dart';
import '../utils/date_helpers.dart';
import '../utils/invite_code.dart';
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

    // Deterministic notif id -> idempotent on retry.
    batch.set(
      _notifsCol(otherUid).doc('friend_added_$uid'),
      {
        'type': 'friend_added',
        'fromNickname': myNickname,
        'fromUid': uid,
        'createdAt': addedAt,
        'read': false,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
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

  /// Removes the mutual friendship with [otherUid]. Silent (no notif).
  Future<void> removeFriend(String otherUid) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Uzivatel neni prihlasen — nelze odebrat kamarada.');
    }

    final batch = _firestore.batch();
    batch.delete(_friendsCol(uid).doc(otherUid));
    batch.delete(_friendsCol(otherUid).doc(uid));
    await batch.commit();
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
