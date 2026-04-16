import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/habit.dart';
import '../models/task.dart';
import '../utils/date_helpers.dart';
import 'task_service.dart';

class HabitService {
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
            .map((d) => Habit.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList());
  }

  Future<String> createHabit({
    required String title,
    required TaskType type,
    required RecurrenceType recurrence,
    List<int> customDays = const [],
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
    );
    final docRef = await _habitsCollection.add({
      ...habit.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _generateInstancesForHabit(docRef.id, habit, days: 30);
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
    if (updates.isNotEmpty) {
      await _habitsCollection.doc(habitId).update(updates);
    }

    await _deleteFutureUncompletedInstances(habitId);
    final fresh = old.copyWith(
      title: title,
      type: type,
      recurrence: recurrence,
      customDays: customDays,
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
