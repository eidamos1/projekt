import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/game_config.dart';
import '../models/habit.dart';
import '../models/task.dart';
import '../models/achievement.dart';
import '../utils/date_helpers.dart';
import 'task_service.dart';
import 'achievement_service.dart';

class HabitService {
  static HabitService? _instance;
  factory HabitService() => _instance ??= HabitService._();
  HabitService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TaskService _taskService = TaskService();

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Uzivatel neni prihlasen.');
    return u.uid;
  }

  CollectionReference get _habitsCollection =>
      _firestore.collection('users').doc(_uid).collection('habits');

  CollectionReference get _tasksCollection =>
      _firestore.collection('users').doc(_uid).collection('tasks');

  Stream<List<Habit>> habitsStream() {
    // NOTE: Habits without createdAt (from pre-v2-push snapshots) won't appear.
    // We're pre-launch so this isn't a migration concern.
    return _habitsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) {
              final habit =
                  Habit.fromMap(d.id, d.data() as Map<String, dynamic>);
              return _normalizeHabit(habit);
            })
            .toList());
  }

  /// Per-service-lifetime cache: habits we've already reconciled. Prevents
  /// re-querying Firestore on every habitsStream tick.
  final Set<String> _reconciledHabits = {};

  /// In-place migration for legacy habits whose type × recurrence combo no
  /// longer parses under the coupled XP economy (see 2026-05-27 design):
  /// "Weekly + everyday/weekdays" used to yield 250–350 XP/week per habit.
  /// Snap such habits to type=daily (10 XP/instance) and persist.
  ///
  /// Separately, ensures future uncompleted task instances match the habit's
  /// current type (this runs even on already-normalized habits to clean up
  /// old instances generated before the migration code shipped).
  /// Returns the normalized Habit so callers always see the fixed shape.
  Habit _normalizeHabit(Habit h) {
    final isWeeklyButRecurringDaily =
        h.type == TaskType.weekly && h.recurrence != RecurrenceType.custom;
    Habit fixed = h;
    if (isWeeklyButRecurringDaily) {
      fixed = h.copyWith(type: TaskType.daily);
      _habitsCollection.doc(h.id).update({'type': 'daily'}).catchError((_) {
        // Best-effort migration; if the write fails, the next stream tick
        // will surface the same shape again and we'll retry.
      });
    }
    // Reconcile future instances with current habit type — once per session.
    // Catches the case where an old version of the app normalized the habit
    // but couldn't update instances yet (this code didn't exist).
    if (_reconciledHabits.add(h.id)) {
      _reconcileFutureInstances(h.id, fixed.type);
    }
    return fixed;
  }

  /// Fire-and-forget: bring any future uncompleted task instance whose type
  /// doesn't match [expectedType] in sync. Filters completed + future
  /// client-side to avoid needing a 3-field composite index.
  void _reconcileFutureInstances(String habitId, TaskType expectedType) {
    final today = todayString();
    final expectedStr = expectedType.toString().split('.').last;
    final rewards = GameConfig.rewardsFor(expectedType);
    _tasksCollection
        .where('habitId', isEqualTo: habitId)
        .get()
        .then((snap) {
      final batch = _firestore.batch();
      bool any = false;
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['completed'] == true) continue;
        final date = data['date'] as String?;
        if (date == null || date.compareTo(today) < 0) continue;
        if (data['type'] != expectedStr) {
          batch.update(doc.reference, {
            'type': expectedStr,
            'xp': rewards.xp,
            'coins': rewards.coins,
          });
          any = true;
        }
      }
      if (any) batch.commit().catchError((_) {});
    }).catchError((_) {});
  }

  Future<String> createHabit({
    required String title,
    required TaskType type,
    required RecurrenceType recurrence,
    List<int> customDays = const [],
    List<String> categories = const [],
  }) async {
    final startDate = todayString();
    final habit = Habit(
      id: '',
      title: title,
      type: type,
      recurrence: recurrence,
      customDays: customDays,
      startDate: startDate,
      active: true,
      categories: categories,
    );
    final docRef = await _habitsCollection.add({
      ...habit.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _generateInstancesForHabit(docRef.id, habit, days: 30);
    AchievementService().evaluate().catchError((_) => <Achievement>[]);
    return docRef.id;
  }

  Future<void> _generateInstancesForHabit(
      String habitId, Habit habit,
      {required int days, DateTime? from}) async {
    final start = from ?? DateTime.now();
    for (int i = 0; i < days; i++) {
      final day = DateTime(start.year, start.month, start.day)
          .add(Duration(days: i));
      if (!habit.expectedOn(day)) continue;
      final dateStr = formatDate(day);
      // Dedup: don't duplicate if an instance for this (habit, date) already exists
      final existing = await _tasksCollection
          .where('habitId', isEqualTo: habitId)
          .where('date', isEqualTo: dateStr)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) continue;
      await _taskService.createHabitInstance(
        title: habit.title,
        type: habit.type,
        date: dateStr,
        habitId: habitId,
        categories: habit.categories,
      );
    }
  }

  Future<void> pauseHabit(String habitId) async {
    await _habitsCollection.doc(habitId).update({'active': false});
    await _deleteFutureUncompletedInstances(habitId);
  }

  Future<void> resumeHabit(String habitId) async {
    await _habitsCollection.doc(habitId).update({'active': true});
    final doc = await _habitsCollection.doc(habitId).get();
    if (!doc.exists) return;
    final habit = Habit.fromMap(habitId, doc.data() as Map<String, dynamic>);
    await _generateInstancesForHabit(habitId, habit, days: 30);
  }

  Future<void> deleteHabit(String habitId) async {
    await _deleteFutureUncompletedInstances(habitId);
    await _habitsCollection.doc(habitId).delete();
  }

  Future<void> _deleteFutureUncompletedInstances(String habitId) async {
    final today = todayString();
    final snap = await _tasksCollection
        .where('habitId', isEqualTo: habitId)
        .where('completed', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final dateStr = data['date'] as String? ?? '';
      final hasPhoto = data['imageBase64'] != null;
      // Preserve past/today instances (user can still finish them)
      if (dateStr.compareTo(today) <= 0) continue;
      // Preserve pending (photo submitted, awaiting confirmation)
      if (hasPhoto) continue;
      final code = data['code'] as String?;
      batch.delete(doc.reference);
      if (code != null) {
        batch.delete(_firestore.collection('taskCodes').doc(code));
      }
    }
    await batch.commit();
  }

  /// Update title/type/recurrence/customDays on habit doc + regenerate future uncompleted.
  Future<void> updateHabitAndRegenerate({
    required String habitId,
    String? title,
    TaskType? type,
    RecurrenceType? recurrence,
    List<int>? customDays,
    List<String>? categories,
  }) async {
    final doc = await _habitsCollection.doc(habitId).get();
    if (!doc.exists) return;
    final old = Habit.fromMap(habitId, doc.data() as Map<String, dynamic>);

    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (type != null) updates['type'] = type.toString().split('.').last;
    if (recurrence != null) {
      updates['recurrence'] = recurrence.toString().split('.').last;
    }
    if (customDays != null) updates['customDays'] = customDays;
    if (categories != null) updates['categories'] = categories;
    if (updates.isNotEmpty) {
      await _habitsCollection.doc(habitId).update(updates);
    }

    await _deleteFutureUncompletedInstances(habitId);
    final fresh = old.copyWith(
      title: title,
      type: type,
      recurrence: recurrence,
      customDays: customDays,
      categories: categories,
    );
    await _generateInstancesForHabit(habitId, fresh, days: 30);
  }

  /// Rolling window: for each active habit, extend generation to 30 days ahead
  /// if the latest instance is less than 14 days ahead.
  Future<void> extendWindows() async {
    final habitsSnap = await _habitsCollection
        .where('active', isEqualTo: true)
        .get();
    for (final doc in habitsSnap.docs) {
      final habit = Habit.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      final lastSnap = await _tasksCollection
          .where('habitId', isEqualTo: doc.id)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      DateTime startFrom;

      if (lastSnap.docs.isEmpty) {
        startFrom = today;
      } else {
        final lastDate = parseDate(
            (lastSnap.docs.first.data() as Map<String, dynamic>)['date']);
        final daysAhead = lastDate.difference(today).inDays;
        if (daysAhead >= 14) continue; // window still sufficient
        final lastPlusOne = lastDate.add(const Duration(days: 1));
        // Clamp to today to avoid regenerating past instances when user was
        // offline longer than the window.
        startFrom = lastPlusOne.isBefore(today) ? today : lastPlusOne;
      }

      final remaining = 30 - startFrom.difference(today).inDays;
      if (remaining <= 0) continue;
      await _generateInstancesForHabit(doc.id, habit,
          days: remaining, from: startFrom);
    }
  }
}
