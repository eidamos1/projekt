import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/achievements.dart';
import '../models/achievement.dart';
import '../models/eval_context.dart';

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

  /// Full Firestore I/O eval. Returns newly unlocked. Implemented in Phase 2.
  Future<List<Achievement>> evaluate() async {
    throw UnimplementedError('Implement in Phase 2 Task 6');
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
