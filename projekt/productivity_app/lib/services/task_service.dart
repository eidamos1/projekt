import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';
import '../constants/game_config.dart';
import '../utils/date_helpers.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Uzivatel neni prihlasen — nelze pristoupit k uid.');
    }
    return user.uid;
  }

  CollectionReference get _tasksCollection =>
      _firestore.collection('users').doc(_uid).collection('tasks');

  Future<void> checkAndResetStreak() async {
    final userRef = _firestore.collection('users').doc(_uid);
    final doc = await userRef.get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final lastActive = data['lastActiveDate'] as String?;
    final streak = data['streak'] ?? 0;

    if (streak == 0) return;

    if (lastActive == null) {
      await userRef.update({'streak': 0});
      return;
    }

    final today = todayString();
    final yesterday = yesterdayString();

    if (lastActive == today || lastActive == yesterday) {
      return;
    }

    await userRef.update({'streak': 0});
  }

  Stream<List<Task>> tasksForDate(String date) {
    return _tasksCollection
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) =>
                Task.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  Stream<DocumentSnapshot> userProfileStream() {
    return _firestore.collection('users').doc(_uid).snapshots();
  }

  Future<void> createTask({
    required String title,
    required TaskType type,
    required String date,
  }) async {
    final rewards = GameConfig.rewardsFor(type);

    final random = Random();
    String code = (100000 + random.nextInt(900000)).toString();

    Task newTask = Task(
      id: '',
      title: title,
      type: type,
      date: date,
      xp: rewards.xp,
      coins: rewards.coins,
      code: code,
    );

    final docRef = await _tasksCollection.add(newTask.toMap());

    await _firestore.collection('taskCodes').doc(code).set({
      'userId': _uid,
      'taskId': docRef.id,
    });
  }

  Future<void> updateTask(String taskId,
      {String? title, TaskType? type}) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (type != null) {
      updates['type'] = type.toString().split('.').last;
      final rewards = GameConfig.rewardsFor(type);
      updates['xp'] = rewards.xp;
      updates['coins'] = rewards.coins;
    }
    if (updates.isNotEmpty) {
      await _tasksCollection.doc(taskId).update(updates);
    }
  }

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

  Future<void> savePhoto(String taskId, String base64Image) async {
    await _tasksCollection.doc(taskId).update({'imageBase64': base64Image});
  }

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

  Future<String> _getCurrentNickname() async {
    final doc = await _firestore.collection('users').doc(_uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return data['nickname'] ?? 'Nekdo';
    }
    return 'Nekdo';
  }

  Future<bool> _areNotificationsEnabled(DocumentReference userRef) async {
    final doc = await userRef.get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return data['notificationsEnabled'] ?? true;
    }
    return true;
  }

  Future<void> _createNotification({
    required DocumentReference ownerRef,
    required String type,
    required String taskTitle,
    required String fromNickname,
    String? message,
  }) async {
    final enabled = await _areNotificationsEnabled(ownerRef);
    if (!enabled) return;

    final now = DateTime.now();
    final createdAt =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    await ownerRef.collection('notifications').add({
      'type': type,
      'taskTitle': taskTitle,
      'message': message,
      'fromNickname': fromNickname,
      'createdAt': createdAt,
      'read': false,
    });
  }

  Future<void> confirmTask(TaskLookupResult lookup) async {
    final nickname = await _getCurrentNickname();

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
      int newLevel = GameConfig.levelFromXp(newXp);

      // Streak logic
      String today = todayString();
      String? lastActive = userData['lastActiveDate'] as String?;
      int streak = userData['streak'] ?? 0;

      if (lastActive == null) {
        streak = 1;
      } else if (lastActive == today) {
        // Already active today
      } else if (lastActive == yesterdayString()) {
        streak += 1;
      } else {
        streak = 1;
      }

      // Streak bonus XP
      int bonus = GameConfig.streakBonus(streak);
      newXp += bonus;
      newLevel = GameConfig.levelFromXp(newXp);

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

    final taskTitle = lookup.taskData['title'] ?? 'Ukol';
    await _createNotification(
      ownerRef: lookup.userRef,
      type: 'confirmed',
      taskTitle: taskTitle,
      fromNickname: nickname,
    );
  }

  Future<void> rejectTask(TaskLookupResult lookup, String reason) async {
    final nickname = await _getCurrentNickname();

    await lookup.taskRef.update({
      'rejected': true,
      'rejectionReason': reason,
    });

    final taskTitle = lookup.taskData['title'] ?? 'Ukol';
    await _createNotification(
      ownerRef: lookup.userRef,
      type: 'rejected',
      taskTitle: taskTitle,
      fromNickname: nickname,
      message: reason,
    );
  }

  Future<void> resetRejected(String taskId) async {
    await _tasksCollection.doc(taskId).update({
      'rejected': false,
      'rejectionReason': null,
    });
  }

  Stream<int> unreadNotificationCount() {
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<List<Map<String, dynamic>>> notificationsStream() {
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Future<void> markNotificationRead(String notifId) async {
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('notifications')
        .doc(notifId)
        .update({'read': true});
  }

  Future<void> markAllNotificationsRead() async {
    final snap = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> checkExpiringTasks() async {
    final tomorrow = tomorrowString();
    final tasksSnap = await _tasksCollection
        .where('date', isEqualTo: tomorrow)
        .where('completed', isEqualTo: false)
        .get();

    if (tasksSnap.docs.isEmpty) return;

    final notifsRef =
        _firestore.collection('users').doc(_uid).collection('notifications');

    for (final doc in tasksSnap.docs) {
      final taskId = doc.id;
      final data = doc.data() as Map<String, dynamic>;

      // Kontrola duplicit
      final existing = await notifsRef
          .where('type', isEqualTo: 'expiring')
          .where('taskId', isEqualTo: taskId)
          .get();
      if (existing.docs.isNotEmpty) continue;

      final now = DateTime.now();
      final createdAt =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      await notifsRef.add({
        'type': 'expiring',
        'taskTitle': data['title'] ?? 'Ukol',
        'taskId': taskId,
        'message': null,
        'fromNickname': null,
        'createdAt': createdAt,
        'read': false,
      });
    }
  }

  Future<List<Task>> allTasks() async {
    final snap = await _tasksCollection.get();
    return snap.docs
        .map((doc) =>
            Task.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }

  Stream<List<Task>> allTasksStream() {
    return _tasksCollection.snapshots().map((snap) => snap.docs
        .map((doc) =>
            Task.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList());
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
