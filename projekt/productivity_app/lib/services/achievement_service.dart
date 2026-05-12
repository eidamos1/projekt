import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/achievements.dart';
import '../models/achievement.dart';
import '../models/eval_context.dart';
import '../models/task.dart';
import '../models/habit.dart';

class AchievementService {
  static AchievementService? _instance;
  factory AchievementService() => _instance ??= AchievementService._();
  AchievementService._();

  // Lazy so that pure unit tests of evaluatePredicates() can instantiate
  // AchievementService without Firebase.initializeApp().
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  bool _running = false;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) {
      throw StateError('Uzivatel neni prihlasen.');
    }
    return u.uid;
  }

  CollectionReference get _achievementsCollection =>
      _firestore.collection('users').doc(_uid).collection('achievements');

  Future<Set<String>> unlockedIds() async {
    final snap = await _achievementsCollection.get();
    return snap.docs.map((d) => d.id).toSet();
  }

  Stream<Set<String>> unlockedIdsStream() {
    return _achievementsCollection
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  /// Pure predicate eval — testable without Firestore.
  /// Returns achievements whose predicate is true and which aren't already in `ctx.alreadyUnlocked`.
  List<Achievement> evaluatePredicates(EvalContext ctx) {
    final result = <Achievement>[];
    for (final a in Achievements.all) {
      if (ctx.alreadyUnlocked.contains(a.id)) continue;
      try {
        if (a.evaluate(ctx)) result.add(a);
      } catch (_) {
        // Predikat selhal (napr. stary data format) — skip, nelogujeme.
      }
    }
    return result;
  }

  /// Full Firestore I/O eval. Returns newly unlocked.
  Future<List<Achievement>> evaluate() async {
    if (_running) return [];
    _running = true;
    try {
      final ctx = await _buildContext();
      final newly = evaluatePredicates(ctx);
      if (newly.isEmpty) return [];

      final now = _nowMinuteString();
      final batch = _firestore.batch();
      int totalXp = 0;
      int totalCoins = 0;

      for (final a in newly) {
        final ref = _achievementsCollection.doc(a.id);
        batch.set(ref, {'unlockedAt': now});
        totalXp += a.xpReward;
        totalCoins += a.coinReward;
      }

      if (totalXp > 0 || totalCoins > 0) {
        final userRef = _firestore.collection('users').doc(_uid);
        await _firestore.runTransaction((tx) async {
          final snap = await tx.get(userRef);
          final data = snap.data() as Map<String, dynamic>;
          final newXp = (data['xp'] ?? 0) + totalXp;
          final newCoins = (data['coins'] ?? 0) + totalCoins;
          final newLevel = (newXp ~/ 100) + 1;
          tx.update(userRef, {
            'xp': newXp,
            'coins': newCoins,
            'level': newLevel,
          });
        });
      }

      await batch.commit();
      await _createUnlockNotifications(newly, now);
      return newly;
    } finally {
      _running = false;
    }
  }

  Future<EvalContext> _buildContext() async {
    final userRef = _firestore.collection('users').doc(_uid);
    final tasksCol = userRef.collection('tasks');
    final habitsCol = userRef.collection('habits');

    final userFuture = userRef.get();
    final tasksFuture = tasksCol
        .where('completed', isEqualTo: true)
        .orderBy('completedAt', descending: true)
        .limit(200)
        .get();
    final habitsFuture = habitsCol.get();
    final unlockedFuture = _achievementsCollection.get();
    final countFuture = tasksCol
        .where('completed', isEqualTo: true)
        .count()
        .get();

    final results = await Future.wait([
      userFuture, tasksFuture, habitsFuture, unlockedFuture, countFuture,
    ]);

    final userSnap = results[0] as DocumentSnapshot;
    final tasksSnap = results[1] as QuerySnapshot;
    final habitsSnap = results[2] as QuerySnapshot;
    final unlockedSnap = results[3] as QuerySnapshot;
    final countSnap = results[4] as AggregateQuerySnapshot;

    final userData = userSnap.exists
        ? userSnap.data() as Map<String, dynamic>
        : <String, dynamic>{};

    return EvalContext(
      user: UserSnapshot(
        xp: userData['xp'] ?? 0,
        level: userData['level'] ?? 1,
        streak: userData['streak'] ?? 0,
        coins: userData['coins'] ?? 0,
        lastActiveDate: userData['lastActiveDate'] as String?,
      ),
      recentTasks: tasksSnap.docs
          .map((d) => Task.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList(),
      habits: habitsSnap.docs
          .map((d) => Habit.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList(),
      alreadyUnlocked: unlockedSnap.docs.map((d) => d.id).toSet(),
      totalCompletedTasks: countSnap.count ?? 0,
    );
  }

  Future<void> _createUnlockNotifications(
      List<Achievement> newly, String now) async {
    final notifsRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('notifications');

    for (final a in newly) {
      final existing = await notifsRef
          .where('type', isEqualTo: 'achievement')
          .where('achievementId', isEqualTo: a.id)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) continue;

      await notifsRef.add({
        'type': 'achievement',
        'achievementId': a.id,
        'taskTitle': a.title,
        'message': a.description,
        'fromNickname': null,
        'createdAt': now,
        'read': false,
      });
    }
  }

  String _nowMinuteString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> setActiveTitle(String? id) async {
    throw UnimplementedError('Implement in Phase 6');
  }

  Stream<String?> activeTitleStream() {
    return _firestore
        .collection('users')
        .doc(_uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return (doc.data() as Map<String, dynamic>)['activeTitle'] as String?;
    });
  }
}
