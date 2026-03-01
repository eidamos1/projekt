import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  CollectionReference get _tasksCollection =>
      _firestore.collection('users').doc(_uid).collection('tasks');

  // Stream ukolů pro konkrétní den
  Stream<List<Task>> tasksForDate(String date) {
    return _tasksCollection
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Task.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Stream uzivatelskeho profilu
  Stream<DocumentSnapshot> userProfileStream() {
    return _firestore.collection('users').doc(_uid).snapshots();
  }

  // Vytvorit ukol
  Future<void> createTask({
    required String title,
    required TaskType type,
    required String date,
  }) async {
    int xp, coins;
    switch (type) {
      case TaskType.daily:
        xp = 10;
        coins = 5;
      case TaskType.weekly:
        xp = 50;
        coins = 20;
      case TaskType.monthly:
        xp = 200;
        coins = 100;
    }

    final random = Random();
    String code = (100000 + random.nextInt(900000)).toString();

    Task newTask = Task(
      id: '',
      title: title,
      type: type,
      date: date,
      xp: xp,
      coins: coins,
      code: code,
    );

    final docRef = await _tasksCollection.add(newTask.toMap());

    // Ulozit kod do globalni kolekce taskCodes
    await _firestore.collection('taskCodes').doc(code).set({
      'userId': _uid,
      'taskId': docRef.id,
    });
  }

  // Upravit ukol
  Future<void> updateTask(String taskId, {String? title, TaskType? type}) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (type != null) {
      updates['type'] = type.toString().split('.').last;
      switch (type) {
        case TaskType.daily:
          updates['xp'] = 10;
          updates['coins'] = 5;
        case TaskType.weekly:
          updates['xp'] = 50;
          updates['coins'] = 20;
        case TaskType.monthly:
          updates['xp'] = 200;
          updates['coins'] = 100;
      }
    }
    if (updates.isNotEmpty) {
      await _tasksCollection.doc(taskId).update(updates);
    }
  }

  // Smazat ukol
  Future<void> deleteTask(String taskId) async {
    final doc = await _tasksCollection.doc(taskId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final code = data['code'] as String?;
      if (code != null) {
        await _firestore.collection('taskCodes').doc(code).delete();
      }
    }
    await _tasksCollection.doc(taskId).delete();
  }

  // Ulozit fotku k ukolu
  Future<void> savePhoto(String taskId, String base64Image) async {
    await _tasksCollection.doc(taskId).update({'imageBase64': base64Image});
  }

  // Najit ukol podle kodu (1 query misto N*M)
  Future<TaskLookupResult?> findTaskByCode(String code) async {
    final codeDoc = await _firestore.collection('taskCodes').doc(code).get();
    if (!codeDoc.exists) return null;

    final data = codeDoc.data()!;
    final userId = data['userId'] as String;
    final taskId = data['taskId'] as String;

    final taskDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(taskId)
        .get();

    if (!taskDoc.exists) return null;

    final taskData = taskDoc.data()!;
    if (taskData['completed'] == true) return null;

    return TaskLookupResult(
      taskData: taskData,
      taskRef: taskDoc.reference,
      userRef: _firestore.collection('users').doc(userId),
    );
  }

  // Potvrdit ukol a pricist odmeny
  Future<void> confirmTask(TaskLookupResult lookup) async {
    await _firestore.runTransaction((tx) async {
      final userSnap = await tx.get(lookup.userRef);
      final taskSnap = await tx.get(lookup.taskRef);

      final taskData = taskSnap.data() as Map<String, dynamic>?;
      if (taskData?['completed'] == true) {
        throw Exception('Tento ukol uz byl potvrzen!');
      }

      final userData = userSnap.data() as Map<String, dynamic>;
      int currentXp = userData['xp'] ?? 0;
      int currentCoins = userData['coins'] ?? 0;
      int rewardXp = taskData?['xp'] ?? 0;
      int rewardCoins = taskData?['coins'] ?? 0;

      int newXp = currentXp + rewardXp;
      int newCoins = currentCoins + rewardCoins;
      int newLevel = (newXp ~/ 100) + 1;

      // Streak logika
      String today = _todayString();
      String? lastActive = userData['lastActiveDate'] as String?;
      int streak = userData['streak'] ?? 0;

      if (lastActive == today) {
        // Uz dnes splnil ukol — streak se nemeni
      } else if (lastActive == _yesterdayString()) {
        streak += 1;
      } else {
        streak = 1;
      }

      // Streak bonus XP
      int streakBonus = 0;
      if (streak == 7) streakBonus = 50;
      if (streak == 30) streakBonus = 200;
      if (streak == 100) streakBonus = 1000;
      newXp += streakBonus;
      newLevel = (newXp ~/ 100) + 1;

      tx.update(lookup.userRef, {
        'xp': newXp,
        'coins': newCoins,
        'level': newLevel,
        'streak': streak,
        'lastActiveDate': today,
      });

      tx.update(lookup.taskRef, {
        'completed': true,
        'completedAt': today,
      });
    });
  }

  // Vsechny ukoly uzivatele (pro statistiky)
  Future<List<Task>> allTasks() async {
    final snap = await _tasksCollection.get();
    return snap.docs
        .map((doc) => Task.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayString() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }
}

class TaskLookupResult {
  final Map<String, dynamic> taskData;
  final DocumentReference taskRef;
  final DocumentReference userRef;

  TaskLookupResult({
    required this.taskData,
    required this.taskRef,
    required this.userRef,
  });
}
