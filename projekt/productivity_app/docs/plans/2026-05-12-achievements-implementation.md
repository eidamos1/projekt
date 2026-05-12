# Achievements Feature Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Pridat 15 achievementu s osobnosti, ktere konzumuji habit streaky + task completiony + kategorie + rejected stavy. Odemkleny achievement muze byt nastaven jako "titul" vedle nicku.

**Architecture:** Statickyy `Achievements` registry v Dart kodu, per-user state (odemknute + activeTitle) ve Firestore. Pure-function predikat eval (`bool Function(EvalContext)`). Owner-side hybrid trigger: lazy eval na app start + `/stats` open, reaktivni eval pri novych `confirmed` notifkach + lokalnich akcich (createTask, createHabit). In-app `SnackBar` toast pri unlocku + notifikace v existujicim feedu.

**Tech Stack:** Flutter 3.9+, Cloud Firestore (aggregation count), existujici `NeoTheme` styling system.

**Design reference:** `docs/plans/2026-05-12-achievements-design.md`

**Testing strategy:**
- **Unit tests (TDD)** pro pure logiku: `Achievement.evaluate` predikat funkce (vsech 15), `EvalContext` builders, `AchievementService.evaluatePredicates` pure helper. Pouzit `flutter_test`.
- **Manual verification** pro Firestore I/O metody a UI — project nepouziva `fake_cloud_firestore`. Kazda I/O task ma explicit manual steps.

**Commit discipline:** Commit po kazde task, zpravy ve stylu existujicich commitu (kratke, cesky bez diacritiky OK).

**Review batching:** Po fazi 3 → review. Po fazi 4 → review. Po fazi 7 → final review.

---

## Phase 1: Foundation (models + smoke achievement)

### Task 1: AchType enum + Achievement model

**Files:**
- Create: `lib/models/achievement.dart`
- Create: `test/models/achievement_test.dart`

**Step 1: Write failing test**

`test/models/achievement_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/models/achievement.dart';
import 'package:productivity_app/models/eval_context.dart';

void main() {
  group('Achievement', () {
    test('evaluate returns predicate result', () {
      final a = Achievement(
        id: 'test',
        title: 'Test',
        teaser: 'tease',
        description: 'desc',
        type: AchType.situational,
        icon: Icons.star,
        color: Colors.red,
        evaluate: (_) => true,
      );
      expect(a.evaluate(EvalContext.empty()), isTrue);
    });

    test('defaults: isTitleEligible=true, xp/coins=0', () {
      final a = Achievement(
        id: 'test',
        title: 't',
        teaser: 't',
        description: 'd',
        type: AchType.situational,
        icon: Icons.star,
        color: Colors.red,
        evaluate: (_) => false,
      );
      expect(a.isTitleEligible, isTrue);
      expect(a.xpReward, 0);
      expect(a.coinReward, 0);
    });
  });
}
```

**Step 2: Run test (should fail)**

```bash
flutter test test/models/achievement_test.dart
```

Expected: FAIL — `achievement.dart` neexistuje.

**Step 3: Implement**

`lib/models/achievement.dart`:

```dart
import 'package:flutter/material.dart';
import 'eval_context.dart';

enum AchType { situational, antiAchievement, loreTitle, milestone }

class Achievement {
  final String id;
  final String title;
  final String teaser;
  final String description;
  final AchType type;
  final IconData icon;
  final Color color;
  final bool isTitleEligible;
  final int xpReward;
  final int coinReward;
  final bool Function(EvalContext) evaluate;

  const Achievement({
    required this.id,
    required this.title,
    required this.teaser,
    required this.description,
    required this.type,
    required this.icon,
    required this.color,
    this.isTitleEligible = true,
    this.xpReward = 0,
    this.coinReward = 0,
    required this.evaluate,
  });
}
```

**Step 4: Run test (should pass)** — depends on Task 2 (EvalContext). Skip until Task 2 done.

**Step 5: Defer commit** — pojedeme dohromady Task 1+2 v jednom commitu (oba modely jsou male a vzajemne odkazuji).

---

### Task 2: EvalContext model

**Files:**
- Create: `lib/models/eval_context.dart`
- Modify: `test/models/achievement_test.dart` (just to verify imports work)

**Step 1: Implement EvalContext**

`lib/models/eval_context.dart`:

```dart
import 'task.dart';
import 'habit.dart';

class UserSnapshot {
  final int xp;
  final int level;
  final int streak;
  final int coins;
  final String? lastActiveDate;

  const UserSnapshot({
    required this.xp,
    required this.level,
    required this.streak,
    required this.coins,
    this.lastActiveDate,
  });
}

class EvalContext {
  final UserSnapshot user;
  final List<Task> recentTasks;
  final List<Habit> habits;
  final Set<String> alreadyUnlocked;
  final int totalCompletedTasks;

  const EvalContext({
    required this.user,
    required this.recentTasks,
    required this.habits,
    required this.alreadyUnlocked,
    required this.totalCompletedTasks,
  });

  factory EvalContext.empty() => const EvalContext(
        user: UserSnapshot(xp: 0, level: 1, streak: 0, coins: 0),
        recentTasks: [],
        habits: [],
        alreadyUnlocked: {},
        totalCompletedTasks: 0,
      );
}
```

**Step 2: Run tests**

```bash
flutter test test/models/achievement_test.dart
```

Expected: PASS (2 tests).

**Step 3: Commit Task 1+2 together**

```bash
git add lib/models/achievement.dart lib/models/eval_context.dart test/models/achievement_test.dart
git commit -m "feat: add Achievement model + EvalContext"
```

---

### Task 3: Achievements registry with smoke achievement

**Files:**
- Create: `lib/constants/achievements.dart`
- Create: `test/constants/achievements_test.dart`

**Step 1: Write failing test**

`test/constants/achievements_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/constants/achievements.dart';
import 'package:productivity_app/models/eval_context.dart';
import 'package:productivity_app/models/task.dart';

void main() {
  group('Achievements registry', () {
    test('byId returns matching achievement', () {
      final a = Achievements.byId('prvni_krok');
      expect(a, isNotNull);
      expect(a!.title, 'Prvni krok');
    });

    test('byId returns null for unknown id', () {
      expect(Achievements.byId('nonexistent'), isNull);
    });

    test('all ids are unique', () {
      final ids = Achievements.all.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('prvni_krok smoke predicate', () {
    final ach = Achievements.byId('prvni_krok')!;

    test('unlocks when totalCompletedTasks >= 1', () {
      final ctx = EvalContext(
        user: const UserSnapshot(xp: 0, level: 1, streak: 0, coins: 0),
        recentTasks: const [],
        habits: const [],
        alreadyUnlocked: const {},
        totalCompletedTasks: 1,
      );
      expect(ach.evaluate(ctx), isTrue);
    });

    test('does not unlock at 0 tasks', () {
      expect(ach.evaluate(EvalContext.empty()), isFalse);
    });
  });
}
```

**Step 2: Run (should fail)**

```bash
flutter test test/constants/achievements_test.dart
```

Expected: FAIL — registry doesn't exist.

**Step 3: Implement registry with smoke achievement**

`lib/constants/achievements.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/achievement.dart';
import 'app_colors.dart';

abstract final class Achievements {
  static final Achievement _prvniKrok = Achievement(
    id: 'prvni_krok',
    title: 'Prvni krok',
    teaser: 'Kazdy nekdy zacina.',
    description: 'Potvrdil jsi svuj prvni task.',
    type: AchType.situational,
    icon: Icons.flag_rounded,
    color: AppColors.neonPink,
    isTitleEligible: false,
    evaluate: (ctx) => ctx.totalCompletedTasks >= 1,
  );

  static final List<Achievement> all = [
    _prvniKrok,
  ];

  static Achievement? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
```

**Step 4: Run (should pass)**

```bash
flutter test test/constants/achievements_test.dart
```

Expected: PASS (5 tests).

**Step 5: Commit**

```bash
git add lib/constants/achievements.dart test/constants/achievements_test.dart
git commit -m "feat: add achievements registry with prvni_krok smoke"
```

---

### Task 4: AchievementService skeleton

**Files:**
- Create: `lib/services/achievement_service.dart`

**Step 1: Skeleton implementation (no tests yet — pure I/O wraps tested in Phase 2)**

`lib/services/achievement_service.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/achievements.dart';
import '../models/achievement.dart';
import '../models/eval_context.dart';

class AchievementService {
  static AchievementService? _instance;
  factory AchievementService() => _instance ??= AchievementService._();
  AchievementService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
```

**Step 2: Verify it compiles**

```bash
flutter analyze
```

Expected: 0 errors (warnings about UnimplementedError OK).

**Step 3: Commit**

```bash
git add lib/services/achievement_service.dart
git commit -m "feat: AchievementService skeleton with pure evaluatePredicates"
```

---

## Phase 2: Eval engine + Firestore I/O

### Task 5: Unit test for `evaluatePredicates` idempotence

**Files:**
- Create: `test/services/achievement_service_test.dart`

**Step 1: Write failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/models/eval_context.dart';
import 'package:productivity_app/services/achievement_service.dart';

void main() {
  group('AchievementService.evaluatePredicates', () {
    final svc = AchievementService();

    test('returns prvni_krok when totalCompletedTasks >= 1 and not already unlocked', () {
      final ctx = EvalContext(
        user: const UserSnapshot(xp: 0, level: 1, streak: 0, coins: 0),
        recentTasks: const [],
        habits: const [],
        alreadyUnlocked: const {},
        totalCompletedTasks: 1,
      );
      final result = svc.evaluatePredicates(ctx);
      expect(result.map((a) => a.id), contains('prvni_krok'));
    });

    test('skips already unlocked', () {
      final ctx = EvalContext(
        user: const UserSnapshot(xp: 0, level: 1, streak: 0, coins: 0),
        recentTasks: const [],
        habits: const [],
        alreadyUnlocked: const {'prvni_krok'},
        totalCompletedTasks: 1,
      );
      final result = svc.evaluatePredicates(ctx);
      expect(result, isEmpty);
    });
  });
}
```

**Step 2: Run**

```bash
flutter test test/services/achievement_service_test.dart
```

Expected: PASS (2 tests).

**Step 3: Commit**

```bash
git add test/services/achievement_service_test.dart
git commit -m "test: AchievementService.evaluatePredicates idempotence"
```

---

### Task 6: Implement `AchievementService.evaluate()` (Firestore I/O)

**Files:**
- Modify: `lib/services/achievement_service.dart`

**Step 1: Implement evaluate() with all reads + writes**

Nahradit `evaluate()` stub:

```dart
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

    // XP/coin bumping pres transakci (level recompute).
    if (totalXp > 0 || totalCoins > 0) {
      final userRef = _firestore.collection('users').doc(_uid);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final data = snap.data() as Map<String, dynamic>;
        final newXp = (data['xp'] ?? 0) + totalXp;
        final newCoins = (data['coins'] ?? 0) + totalCoins;
        // levelFromXp = (xp ~/ 100) + 1
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

Future<void> _createUnlockNotifications(List<Achievement> newly, String now) async {
  final notifsRef = _firestore
      .collection('users')
      .doc(_uid)
      .collection('notifications');

  for (final a in newly) {
    // Dedupe: skip kdyz notif s timto achievementId uz existuje.
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
```

Pridat importy nahoru souboru:

```dart
import '../models/task.dart';
import '../models/habit.dart';
```

**Step 2: Verify compilation**

```bash
flutter analyze
```

Expected: 0 errors.

**Step 3: Manual test**

Spustit:
```bash
flutter run -d chrome
```

1. Prihlasit se dev userem (smoke@example.cz).
2. Otevrit Chrome DevTools console.
3. V kalendari potvrdit (pres kamarada / dev confirm) jeden task.
4. Po confirm: v jine zalozce kalendare zavolat z DevTools (debug volani — pripadne docasne via plovouci tlacitko v stats page).
5. **Acceptable verifikace:** otevrit Firestore console pro `users/{uid}/achievements/prvni_krok` — dokument existuje s `unlockedAt`.
6. Otevrit `users/{uid}/notifications` — najit `type: 'achievement', achievementId: 'prvni_krok'`.

**Step 4: Commit**

```bash
git add lib/services/achievement_service.dart
git commit -m "feat: AchievementService.evaluate with Firestore I/O + unlock notif"
```

---

### Task 7: Wire app-start trigger in `lib/pages/login.dart`

**Files:**
- Modify: `lib/pages/login.dart` (po successful auth → trigger AchievementService.evaluate())

**Step 1: Najdi misto kde se po prihlaseni naviguje na `/calendar`**

Read `lib/pages/login.dart` a najdi successful login handler. Pridat fire-and-forget:

```dart
import '../services/achievement_service.dart';
// ...
// po Navigator.pushReplacementNamed(context, '/calendar'):
AchievementService().evaluate().catchError((_) => <Achievement>[]);
```

**Pozor:** `evaluate()` fire-and-forget, nikdy nezablokuje login flow. Catch error vraci prazdny list (uz definovany ucinek).

**Step 2: Verify compilation**

```bash
flutter analyze
```

**Step 3: Manual test**

1. Sign out, sign back in.
2. Network tab v DevTools — videt requesty na Firestore (5 paralelnich).
3. Bez errors v console.

**Step 4: Commit**

```bash
git add lib/pages/login.dart
git commit -m "feat: trigger achievement eval on app start"
```

---

### Task 8: Reactive trigger v `lib/main.dart` (notif stream listener)

**Files:**
- Modify: `lib/main.dart`

**Step 1: Add notif stream listener**

Najit kde se inicializuje hlavni navigator. Pridat globalni listener (jedno-shot per session):

```dart
// V hlavnim widget initState (napr. _MyAppState):
StreamSubscription<List<Map<String, dynamic>>>? _notifSub;
int _lastNotifSeen = -1;

@override
void initState() {
  super.initState();
  _hookAchievementTrigger();
}

void _hookAchievementTrigger() {
  // Listener fires pri zmene notif feedu. Po prvnim emitu si zapamatujeme
  // delku — kazdy dalsi emit s vetsim count = nova notif = trigger eval.
  _notifSub = TaskService().notificationsStream().listen((notifs) {
    if (_lastNotifSeen < 0) {
      _lastNotifSeen = notifs.length;
      return;
    }
    if (notifs.length > _lastNotifSeen) {
      _lastNotifSeen = notifs.length;
      // Fire-and-forget. Result se obstara cez UI listener v Phase 7.
      AchievementService().evaluate().catchError((_) => <Achievement>[]);
    } else {
      _lastNotifSeen = notifs.length;
    }
  });
}

@override
void dispose() {
  _notifSub?.cancel();
  super.dispose();
}
```

**Step 2: Verify compilation + manual test**

```bash
flutter analyze
flutter run -d chrome
```

1. Potvrdit task pres confirm flow (kamarad zarizenim — nebo simulovat: jiny accountem confirm).
2. Cca 1-2s po confirm → kontrola Firestore `users/{uid}/achievements/prvni_krok`. Pokud uz odemkly z app-start triggeru: zalozit novy ucet a opakovat.

**Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: reactive achievement eval on new notification"
```

---

### Task 9: Local action triggers v service vrstve

**Files:**
- Modify: `lib/services/task_service.dart` (po `createTask`)
- Modify: `lib/services/habit_service.dart` (po `createHabit`)

**Step 1: Add fire-and-forget eval po `createTask`**

V `task_service.dart` `createTask()` po `_createTaskInstance`:

```dart
// Posledni radek pred `}`:
AchievementService().evaluate().catchError((_) => <Achievement>[]);
```

Pridat import na vrchol `task_service.dart`:

```dart
import 'achievement_service.dart';
import '../models/achievement.dart';
```

**Step 2: Same pro `habit_service.dart` `createHabit()`**

Po `_generateInstancesForHabit`:

```dart
AchievementService().evaluate().catchError((_) => <Achievement>[]);
return docRef.id;
```

**Step 3: Verify + commit**

```bash
flutter analyze
git add lib/services/task_service.dart lib/services/habit_service.dart
git commit -m "feat: trigger achievement eval on createTask + createHabit"
```

---

## Phase 3: Task model upgrade (wasRejected + full timestamp)

### Task 10: Add `wasRejected` field to `Task`

**Files:**
- Modify: `lib/models/task.dart`
- Modify: `test/task_model_test.dart`

**Step 1: Write failing test**

Pridat do `test/task_model_test.dart`:

```dart
test('Task.wasRejected default false', () {
  final t = Task(
    id: '1', title: 'x', type: TaskType.daily,
    date: '2026-05-12', xp: 10, coins: 5, code: '123456',
  );
  expect(t.wasRejected, isFalse);
});

test('Task.fromMap reads wasRejected', () {
  final t = Task.fromMap('1', {
    'title': 'x', 'type': 'daily', 'date': '2026-05-12',
    'xp': 10, 'coins': 5, 'code': '123456',
    'wasRejected': true,
  });
  expect(t.wasRejected, isTrue);
});

test('Task.fromMap defaults wasRejected to false for legacy doc', () {
  final t = Task.fromMap('1', {
    'title': 'x', 'type': 'daily', 'date': '2026-05-12',
    'xp': 10, 'coins': 5, 'code': '123456',
  });
  expect(t.wasRejected, isFalse);
});

test('Task.toMap includes wasRejected', () {
  final t = Task(
    id: '1', title: 'x', type: TaskType.daily,
    date: '2026-05-12', xp: 10, coins: 5, code: '123456',
    wasRejected: true,
  );
  expect(t.toMap()['wasRejected'], isTrue);
});
```

**Step 2: Run (should fail)**

```bash
flutter test test/task_model_test.dart
```

Expected: FAIL — `wasRejected` neexistuje.

**Step 3: Modify `lib/models/task.dart`**

Pridat field:
- `final bool wasRejected;` do trídy
- `this.wasRejected = false,` do konstruktoru
- `wasRejected: data['wasRejected'] ?? false,` do `fromMap`
- `'wasRejected': wasRejected,` do `toMap`

**Step 4: Run (should pass)**

```bash
flutter test test/task_model_test.dart
```

Expected: PASS (all tests).

**Step 5: Commit**

```bash
git add lib/models/task.dart test/task_model_test.dart
git commit -m "feat: add Task.wasRejected (persistent rejection flag)"
```

---

### Task 11: Upgrade `completedAt` to support full timestamp

**Files:**
- Modify: `lib/services/task_service.dart` (confirmTask — use minute timestamp)
- Modify: `lib/utils/date_helpers.dart` (add helper)
- Create test: `test/utils/date_helpers_test.dart`

**Step 1: Add helper**

V `lib/utils/date_helpers.dart`:

```dart
String nowMinuteString() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
      '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
}

/// Parses either 'yyyy-MM-dd' (10 chars) or 'yyyy-MM-dd HH:mm' (16 chars).
/// Returns null if format unrecognized.
DateTime? parseFlexibleTimestamp(String? s) {
  if (s == null) return null;
  if (s.length == 10) {
    try { return DateFormat('yyyy-MM-dd').parse(s); } catch (_) { return null; }
  }
  if (s.length == 16) {
    try { return DateFormat('yyyy-MM-dd HH:mm').parse(s); } catch (_) { return null; }
  }
  return null;
}

/// Vraci hodinu z flexible timestampu. Null kdyz format jen 'yyyy-MM-dd'.
int? hourOf(String? s) {
  if (s == null || s.length != 16) return null;
  return parseFlexibleTimestamp(s)?.hour;
}
```

**Step 2: Write tests**

`test/utils/date_helpers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/utils/date_helpers.dart';

void main() {
  group('parseFlexibleTimestamp', () {
    test('parses date-only string', () {
      final d = parseFlexibleTimestamp('2026-05-12');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.day, 12);
      expect(d.hour, 0);
    });

    test('parses date+time string', () {
      final d = parseFlexibleTimestamp('2026-05-12 23:45');
      expect(d, isNotNull);
      expect(d!.hour, 23);
      expect(d.minute, 45);
    });

    test('returns null for malformed input', () {
      expect(parseFlexibleTimestamp('garbage'), isNull);
      expect(parseFlexibleTimestamp(null), isNull);
    });
  });

  group('hourOf', () {
    test('extracts hour from full timestamp', () {
      expect(hourOf('2026-05-12 23:45'), 23);
    });

    test('returns null for date-only string', () {
      expect(hourOf('2026-05-12'), isNull);
    });

    test('returns null for null', () {
      expect(hourOf(null), isNull);
    });
  });
}
```

**Step 3: Run**

```bash
flutter test test/utils/date_helpers_test.dart
```

Expected: PASS.

**Step 4: Update `task_service.dart` `confirmTask`**

V `confirmTask` transakce — zmenit:

```dart
String today = todayString();
// ...
tx.update(lookup.taskRef, {
  'completed': true,
  'completedAt': today,
});
```

na:

```dart
String today = todayString();
String completedAtTs = nowMinuteString();
// ...
tx.update(lookup.taskRef, {
  'completed': true,
  'completedAt': completedAtTs,
});
```

Pozn: streak logic uvnitr transakce dal pouziva `today` (compareTo yesterdayString). Jen `completedAt` se meni na full timestamp.

Pridat import:
```dart
// nahore task_service.dart:
// (uz tam je '../utils/date_helpers.dart' — nepotreba dalsi)
```

**Step 5: Manual verify**

```bash
flutter run -d chrome
```

1. Vytvorit + potvrdit jeden task.
2. Firestore console → task doc → `completedAt` ma format `'2026-05-12 14:32'` (16 znaku).
3. Stary task v DB (od pred-zmenou) ma `completedAt: '2026-05-12'` (10 znaku) — appka nepada.

**Step 6: Commit**

```bash
git add lib/utils/date_helpers.dart test/utils/date_helpers_test.dart lib/services/task_service.dart
git commit -m "feat: completedAt now full timestamp (backward compat)"
```

---

### Task 12: Set `wasRejected = true` v `rejectTask`

**Files:**
- Modify: `lib/services/task_service.dart`

**Step 1: Upravit `rejectTask`**

```dart
Future<void> rejectTask(TaskLookupResult lookup, String reason) async {
  final nickname = await _getCurrentNickname();

  await lookup.taskRef.update({
    'rejected': true,
    'wasRejected': true,    // <-- NEW: persistent flag, nikdy se nemaze
    'rejectionReason': reason,
  });

  // ...zbytek nezmeneny
}
```

`resetRejected` zustava — maze jen `rejected`/`rejectionReason`, `wasRejected` zustava `true`:

```dart
Future<void> resetRejected(String taskId) async {
  await _tasksCollection.doc(taskId).update({
    'rejected': false,
    'rejectionReason': null,
    // wasRejected NEZASAHUJEME — chceme aby comeback_kid se odemkl
  });
}
```

**Step 2: Manual verify**

1. Vytvor task → potvrdit (kamarad) → zamitnout.
2. Firestore: `wasRejected: true`, `rejected: true`.
3. V appce reset rejected, znovu pridat foto, potvrdit.
4. Firestore: `wasRejected: true` ZUSTAVA, `completed: true`, `rejected: false`.

**Step 3: Commit**

```bash
git add lib/services/task_service.dart
git commit -m "feat: wasRejected persisted on reject (drives comeback_kid)"
```

---

> ## REVIEW CHECKPOINT — Phase 1-3
>
> Stop pred Phase 4. Spustit `superpowers:requesting-code-review`. Klice k overit:
> - Models compile, tests green.
> - `evaluate()` runs against real Firestore (manual test in Task 6).
> - `prvni_krok` se odemyka pri prvnim confirmu.
> - `wasRejected` se persistuje napriklad reject.
> - `completedAt` ma novy format v novych docs, stary docs neselzou.

---

## Phase 4: Content — 15 achievementu

> **Pattern pro vsech 15 tasku v teto fazi:**
> 1. Pridat constant do `lib/constants/achievements.dart` (Achievement objekt s predikat funkci).
> 2. Pridat positive + negative test do `test/constants/achievements_test.dart`.
> 3. Aktualizovat `Achievements.all` list.
> 4. Run testy.
> 5. Commit s message `feat: achievement <id> + tests`.
>
> **DRY:** Pri psani testu vyuzij helper builders. Hned na zacatku Task 13 vytvorime `test/_fixtures.dart` s `_buildTask(...)`, `_buildHabit(...)`, `_buildContext(...)` ktere reuse vsechny dalsi testy.

### Task 13: Test fixtures + replace `prvni_krok` smoke

**Files:**
- Create: `test/_achievement_fixtures.dart`
- Modify: `test/constants/achievements_test.dart`

**Step 1: Vytvor fixtures**

```dart
// test/_achievement_fixtures.dart
import 'package:productivity_app/models/eval_context.dart';
import 'package:productivity_app/models/task.dart';
import 'package:productivity_app/models/habit.dart';

Task buildTask({
  String id = 't',
  String title = 'Task',
  TaskType type = TaskType.daily,
  String date = '2026-05-12',
  String? completedAt,
  bool completed = true,
  bool wasRejected = false,
  String? habitId,
  List<String> categories = const [],
}) {
  return Task(
    id: id, title: title, type: type, date: date,
    xp: 10, coins: 5, code: '111111',
    completed: completed,
    wasRejected: wasRejected,
    habitId: habitId,
    categories: categories,
  );
  // pozn: completedAt neni field constructoru? Pokud bude potreba simulovat —
  // viz Task model. Pridat completedAt jako readonly field je TODO v Phase 3
  // — pokud chybi, pridat behem Task 14 nize.
}

Habit buildHabit({
  String id = 'h',
  String title = 'Habit',
  TaskType type = TaskType.daily,
  RecurrenceType recurrence = RecurrenceType.everyday,
  List<int> customDays = const [],
  String startDate = '2026-01-01',
  bool active = true,
  int streak = 0,
  int longestStreak = 0,
  String? lastCompletedDate,
  List<String> categories = const [],
}) =>
    Habit(
      id: id, title: title, type: type, recurrence: recurrence,
      customDays: customDays, startDate: startDate, active: active,
      streak: streak, longestStreak: longestStreak,
      lastCompletedDate: lastCompletedDate, categories: categories,
    );

EvalContext buildContext({
  List<Task> recentTasks = const [],
  List<Habit> habits = const [],
  Set<String> alreadyUnlocked = const {},
  int totalCompletedTasks = 0,
  int userXp = 0,
  int userLevel = 1,
  int userStreak = 0,
}) =>
    EvalContext(
      user: UserSnapshot(
        xp: userXp, level: userLevel, streak: userStreak, coins: 0,
      ),
      recentTasks: recentTasks,
      habits: habits,
      alreadyUnlocked: alreadyUnlocked,
      totalCompletedTasks: totalCompletedTasks,
    );
```

**POZN:** `Task` model ma `completedAt`? **Ne** — task model nese jen `date`, `completed`, `imageBase64` atd. `completedAt` se ulozi do Firestore docu, ale neni v `Task.fromMap`/`toMap`.

**ROZHODNUTI:** Pridat `completedAt` jako field na `Task` modelu (read-only, optional). Pokud chybi v fromMap, zustava `null`. Tato zmena patri do Phase 3 Task 11 — pokud se na ni zapomnelo, retroaktivne pridat ted.

Update `lib/models/task.dart`:

```dart
final String? completedAt;     // 'yyyy-MM-dd HH:mm' or 'yyyy-MM-dd' or null
// ...
this.completedAt,
// ...
completedAt: data['completedAt'] as String?,
// ...
'completedAt': completedAt,
```

Update test fixtures `buildTask` aby brala `completedAt`.

**Step 2: `prvni_krok` po faze 4 zustane jako smoke?** Ne — Phase 4 nahradi `prvni_krok` 15ti production achievementy. `prvni_krok` smaze. Vymen `Achievements.all = [_prvniKrok]` na nove jmena (postupne pridavame).

Pred odstraneni `prvni_krok`: nejdriv pridat alespon jeden plnohodnotny achievement. Smaz `prvni_krok` v poslednim tasku faze 4 (Task 28).

**Step 3: Run testy**

```bash
flutter test
```

Mit zelene.

**Step 4: Commit**

```bash
git add test/_achievement_fixtures.dart lib/models/task.dart
git commit -m "chore: achievement test fixtures + Task.completedAt field"
```

---

### Task 14: `patecni_hrdina` — 4 patky po sobe

**Files:**
- Modify: `lib/constants/achievements.dart`
- Modify: `test/constants/achievements_test.dart`

**Step 1: Test**

```dart
group('patecni_hrdina', () {
  final ach = Achievements.byId('patecni_hrdina');

  test('unlocks for 4 consecutive Fridays with habit task', () {
    final friday1 = '2026-05-08';  // patek
    final friday2 = '2026-05-01';
    final friday3 = '2026-04-24';
    final friday4 = '2026-04-17';
    final ctx = buildContext(
      recentTasks: [
        buildTask(date: friday1, completedAt: '$friday1 18:00', habitId: 'h1'),
        buildTask(date: friday2, completedAt: '$friday2 18:00', habitId: 'h1'),
        buildTask(date: friday3, completedAt: '$friday3 18:00', habitId: 'h1'),
        buildTask(date: friday4, completedAt: '$friday4 18:00', habitId: 'h1'),
      ],
    );
    expect(ach!.evaluate(ctx), isTrue);
  });

  test('does NOT unlock with only 3 Fridays', () {
    final ctx = buildContext(
      recentTasks: [
        buildTask(date: '2026-05-08', habitId: 'h1'),
        buildTask(date: '2026-05-01', habitId: 'h1'),
        buildTask(date: '2026-04-24', habitId: 'h1'),
      ],
    );
    expect(ach!.evaluate(ctx), isFalse);
  });
});
```

**Step 2: Implement**

V `lib/constants/achievements.dart`:

```dart
static final Achievement _patecniHrdina = Achievement(
  id: 'patecni_hrdina',
  title: 'Patecni hrdina',
  teaser: 'Nekdo zna cenu vikendu.',
  description: 'Splnil jsi habit ctyri patky po sobe.',
  type: AchType.situational,
  icon: Icons.weekend_rounded,
  color: AppColors.neonYellow,
  evaluate: (ctx) {
    // Najdi habit-tasky v posledni 4 patkach po sobe, pocínaje od nejnovejsiho.
    final fridays = <String>{};
    for (final t in ctx.recentTasks) {
      if (t.habitId == null || !t.completed) continue;
      final d = parseDate(t.date);
      if (d.weekday == DateTime.friday) fridays.add(t.date);
    }
    if (fridays.length < 4) return false;

    // Zkontroluj ze 4 nejnovejsi tvori po sobe jdouci patky.
    final sortedDesc = fridays.toList()..sort((a, b) => b.compareTo(a));
    DateTime prev = parseDate(sortedDesc[0]);
    for (int i = 1; i < 4; i++) {
      final cur = parseDate(sortedDesc[i]);
      final diff = prev.difference(cur).inDays;
      if (diff != 7) return false;
      prev = cur;
    }
    return true;
  },
);
```

Pridat do `Achievements.all`.
Pridat import `import '../utils/date_helpers.dart';`.

**Step 3: Run + commit**

```bash
flutter test test/constants/achievements_test.dart
git add lib/constants/achievements.dart test/constants/achievements_test.dart
git commit -m "feat: achievement patecni_hrdina + tests"
```

---

### Task 15: `comeback_kid` — task wasRejected -> completed

**Test:**

```dart
group('comeback_kid', () {
  final ach = Achievements.byId('comeback_kid');

  test('unlocks when a completed task has wasRejected=true', () {
    final ctx = buildContext(
      recentTasks: [buildTask(wasRejected: true, completed: true)],
    );
    expect(ach!.evaluate(ctx), isTrue);
  });

  test('does NOT unlock with completed but never rejected task', () {
    final ctx = buildContext(
      recentTasks: [buildTask(wasRejected: false, completed: true)],
    );
    expect(ach!.evaluate(ctx), isFalse);
  });
});
```

**Impl:**

```dart
static final Achievement _comebackKid = Achievement(
  id: 'comeback_kid',
  title: 'Comeback',
  teaser: 'Nevzdal jsi to po prvni rane.',
  description: 'Potvrdil jsi task, ktery byl drive zamitnut.',
  type: AchType.situational,
  icon: Icons.refresh_rounded,
  color: AppColors.neonGreen,
  evaluate: (ctx) =>
      ctx.recentTasks.any((t) => t.completed && t.wasRejected),
);
```

Commit: `feat: achievement comeback_kid + tests`.

---

### Task 16: `pulnocni_zachrana` — task po 23:00

**Test:**

```dart
group('pulnocni_zachrana', () {
  final ach = Achievements.byId('pulnocni_zachrana');

  test('unlocks at hour 23', () {
    final ctx = buildContext(
      recentTasks: [buildTask(completedAt: '2026-05-12 23:45')],
    );
    expect(ach!.evaluate(ctx), isTrue);
  });

  test('does NOT unlock at hour 22', () {
    final ctx = buildContext(
      recentTasks: [buildTask(completedAt: '2026-05-12 22:59')],
    );
    expect(ach!.evaluate(ctx), isFalse);
  });

  test('skips legacy date-only completedAt', () {
    final ctx = buildContext(
      recentTasks: [buildTask(completedAt: '2026-05-12')],
    );
    expect(ach!.evaluate(ctx), isFalse);
  });
});
```

**Impl:**

```dart
static final Achievement _pulnocniZachrana = Achievement(
  id: 'pulnocni_zachrana',
  title: 'Pulnocni zachrana',
  teaser: 'Nekdo to nevzda ani v posledni minute.',
  description: 'Splnil jsi task po 23:00.',
  type: AchType.situational,
  icon: Icons.access_time_rounded,
  color: AppColors.neonPink,
  evaluate: (ctx) => ctx.recentTasks.any((t) {
    final h = hourOf(t.completedAt);
    return h != null && h >= 23;
  }),
);
```

Commit: `feat: achievement pulnocni_zachrana + tests`.

---

### Task 17: `rano_je_moudrejsi` — task pred 7:00

```dart
static final Achievement _ranoJeMoudrejsi = Achievement(
  id: 'rano_je_moudrejsi',
  title: 'Rano je moudrejsi',
  teaser: 'Vstavas s prvnimi taxiky.',
  description: 'Splnil jsi task pred 7:00.',
  type: AchType.situational,
  icon: Icons.wb_sunny_rounded,
  color: AppColors.neonOrange,
  evaluate: (ctx) => ctx.recentTasks.any((t) {
    final h = hourOf(t.completedAt);
    return h != null && h < 7;
  }),
);
```

Test obdobne (positive: `'2026-05-12 06:30'`, negative: `'2026-05-12 07:00'`, negative legacy).

Commit: `feat: achievement rano_je_moudrejsi + tests`.

---

### Task 18: `bourak` — 3+ tasku v jeden den

```dart
static final Achievement _bourak = Achievement(
  id: 'bourak',
  title: 'Bourak',
  teaser: 'Manana? Tak ne dnes.',
  description: 'Splnil jsi 3+ tasku za jeden den.',
  type: AchType.situational,
  icon: Icons.bolt_rounded,
  color: AppColors.neonCyan,
  evaluate: (ctx) {
    final counts = <String, int>{};
    for (final t in ctx.recentTasks) {
      if (!t.completed) continue;
      // Pouziti `t.date` (= datum tasku, ne completedAt). Tasky ze stejneho dne.
      counts.update(t.date, (v) => v + 1, ifAbsent: () => 1);
    }
    return counts.values.any((c) => c >= 3);
  },
);
```

Tests: positive 3 tasky stejny date; negative 2 tasky stejny date + 5 ruznych dat.

Commit: `feat: achievement bourak + tests`.

---

### Task 19: `hat_trick` — daily+weekly+monthly v jeden den

```dart
static final Achievement _hatTrick = Achievement(
  id: 'hat_trick',
  title: 'Hat-trick',
  teaser: 'Trojita kombinace.',
  description: 'Splnil jsi daily, weekly i monthly task v jeden den.',
  type: AchType.situational,
  icon: Icons.emoji_events_rounded,
  color: AppColors.neonYellow,
  evaluate: (ctx) {
    final byDate = <String, Set<TaskType>>{};
    for (final t in ctx.recentTasks) {
      if (!t.completed) continue;
      byDate.putIfAbsent(t.date, () => {}).add(t.type);
    }
    return byDate.values.any((types) =>
        types.contains(TaskType.daily) &&
        types.contains(TaskType.weekly) &&
        types.contains(TaskType.monthly));
  },
);
```

Commit: `feat: achievement hat_trick + tests`.

---

### Task 20: `nedelni_klid` — habit ve 4 nedelich po sobe

Identicky pattern jako `patecni_hrdina`, jen `DateTime.sunday`.

Commit: `feat: achievement nedelni_klid + tests`.

---

### Task 21: `univerzal` — 3 ruzne kategorie v jeden den

```dart
static final Achievement _univerzal = Achievement(
  id: 'univerzal',
  title: 'Univerzal',
  teaser: 'Jeden mozek, sto sluzeb.',
  description: 'Splnil jsi tasky ze 3 ruznych kategorii v jeden den.',
  type: AchType.situational,
  icon: Icons.dynamic_feed_rounded,
  color: AppColors.neonPink,
  evaluate: (ctx) {
    final byDate = <String, Set<String>>{};
    for (final t in ctx.recentTasks) {
      if (!t.completed) continue;
      byDate.putIfAbsent(t.date, () => {}).addAll(t.categories);
    }
    return byDate.values.any((cats) => cats.length >= 3);
  },
);
```

Tests: positive — 1 datum se 3 kategoriemi; negative — 1 datum se 2 kategoriemi + jine datum se 3 ale jen castecne overlap. Vlastne: 1 datum se 2 kategoriemi = false. Done.

Commit: `feat: achievement univerzal + tests`.

---

### Task 22: `prokrastinator` — 5 tasku po 23:00

```dart
static final Achievement _prokrastinator = Achievement(
  id: 'prokrastinator',
  title: 'Prokrastinator',
  teaser: 'Cas leti nejak rychle, ze?',
  description: 'Splnil jsi 5 tasku v posledni hodine pred pulnoci.',
  type: AchType.antiAchievement,
  icon: Icons.hourglass_bottom_rounded,
  color: AppColors.neonOrange,
  evaluate: (ctx) {
    int count = 0;
    for (final t in ctx.recentTasks) {
      final h = hourOf(t.completedAt);
      if (h != null && h >= 23) count++;
    }
    return count >= 5;
  },
);
```

Commit: `feat: achievement prokrastinator + tests`.

---

### Task 23: `zlomeny_slib` — habit longestStreak >= 7 && longestStreak > streak

```dart
static final Achievement _zlomenySlib = Achievement(
  id: 'zlomeny_slib',
  title: 'Zlomeny slib',
  teaser: 'Tak blizko.',
  description: 'Rozbil jsi habit streak 7+ dni.',
  type: AchType.antiAchievement,
  icon: Icons.heart_broken_rounded,
  color: AppColors.neonPink,
  evaluate: (ctx) => ctx.habits.any(
    (h) => h.longestStreak >= 7 && h.longestStreak > h.streak,
  ),
);
```

Commit: `feat: achievement zlomeny_slib + tests`.

---

### Task 24: `krasove_panstvi` — 3 wasRejected v poslednim tydnu

```dart
static final Achievement _krasovePanstvi = Achievement(
  id: 'krasove_panstvi',
  title: 'Krasove panstvi',
  teaser: 'Vsechno chce trening.',
  description: 'Mas 3 zamitnuti za jeden tyden.',
  type: AchType.antiAchievement,
  icon: Icons.do_not_disturb_rounded,
  color: AppColors.neonOrange,
  evaluate: (ctx) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    int count = 0;
    for (final t in ctx.recentTasks) {
      if (!t.wasRejected) continue;
      final d = parseDate(t.date);
      if (d.isAfter(sevenDaysAgo)) count++;
    }
    return count >= 3;
  },
);
```

**Pozn:** test pouzije fixne datum, mockuje `now` neni triv — zaplacni vykladem dat v testu (tasks v poslednich 3 dnech od dneska = pass; vsechny stari pred 10 dni = fail). Pri pisani testu pouzij `DateTime.now()` jen v assertion — generate dates relativni vuci `DateTime.now().subtract(Duration(days: X))`.

Commit: `feat: achievement krasove_panstvi + tests`.

---

### Task 25: `fantom` — 5+ expirovanych nesplnenych tasku

```dart
static final Achievement _fantom = Achievement(
  id: 'fantom',
  title: 'Fantom kalendare',
  teaser: 'Planovat je snadnejsi nez plnit.',
  description: 'Pet plus tvych tasku vyprshelo bez splneni.',
  type: AchType.antiAchievement,
  icon: Icons.event_busy_rounded,
  color: AppColors.neonPink,
  evaluate: (ctx) {
    final today = todayString();
    int count = 0;
    for (final t in ctx.recentTasks) {
      if (t.completed) continue;
      if (t.date.compareTo(today) < 0) count++;
    }
    return count >= 5;
  },
);
```

**WAIT** — `recentTasks` v `_buildContext` ma `where('completed', isEqualTo: true)`. Takze ctx.recentTasks NEOBSAHUJE nesplnene tasky!

**FIX:** Bud:
- Rozšířit `_buildContext` aby fetchoval i `incompleteTasks` (extra query).
- Nebo přidat `expiredTaskCount: int` aggregaci do EvalContext (`count where completed=false and date<today`).

Vybereme **přidat aggregation count** — cheap (1 read), nedrz cely doc. Update `EvalContext`:

```dart
class EvalContext {
  // ...
  final int expiredUncompletedCount;
}
```

V `_buildContext` v `AchievementService`:

```dart
final expiredCountFuture = tasksCol
    .where('completed', isEqualTo: false)
    .where('date', isLessThan: todayString())
    .count()
    .get();
```

`_fantom.evaluate: (ctx) => ctx.expiredUncompletedCount >= 5`.

Test: positive `expiredUncompletedCount: 5` → true; negative `4` → false.

Commit: `feat: achievement fantom + expiredUncompletedCount in EvalContext`.

---

### Task 26: `nocni_sova` — 10 tasku po 22:00

```dart
static final Achievement _nocniSova = Achievement(
  id: 'nocni_sova',
  title: 'Nocni sova',
  teaser: 'Den ma 24 hodin, pouziva se jen ta druha polovina.',
  description: 'Splnil jsi 10 tasku po 22:00.',
  type: AchType.loreTitle,
  icon: Icons.nightlight_round,
  color: AppColors.neonCyan,
  evaluate: (ctx) {
    int count = 0;
    for (final t in ctx.recentTasks) {
      final h = hourOf(t.completedAt);
      if (h != null && h >= 22) count++;
    }
    return count >= 10;
  },
);
```

Commit: `feat: achievement nocni_sova + tests`.

---

### Task 27: `spartanek` — sport-kategoria streak >= 14

```dart
static final Achievement _spartanek = Achievement(
  id: 'spartanek',
  title: 'Spartanek',
  teaser: 'Telo je chram.',
  description: '14denni streak na sport-kategorii habitu.',
  type: AchType.loreTitle,
  icon: Icons.fitness_center_rounded,
  color: AppColors.neonCyan,
  evaluate: (ctx) => ctx.habits.any(
    (h) => h.categories.contains('sport') && h.streak >= 14,
  ),
);
```

Commit: `feat: achievement spartanek + tests`.

---

### Task 28: `stovkar` — 100 splnenych tasku (milestone)

```dart
static final Achievement _stovkar = Achievement(
  id: 'stovkar',
  title: 'Stovkar',
  teaser: 'Trochu klasika.',
  description: 'Splnil jsi 100 tasku.',
  type: AchType.milestone,
  icon: Icons.military_tech_rounded,
  color: AppColors.neonYellow,
  isTitleEligible: false,
  xpReward: 500,
  coinReward: 200,
  evaluate: (ctx) => ctx.totalCompletedTasks >= 100,
);
```

Commit: `feat: achievement stovkar + milestone reward`.

---

### Task 29: Final cleanup — odebrat `prvni_krok` smoke, finalize registry order

**Files:**
- Modify: `lib/constants/achievements.dart`

**Step 1:** Smaz `_prvniKrok` constant + nahrad `Achievements.all` finalnim listem (15 achievementu v poradi z design docu):

```dart
static final List<Achievement> all = [
  _patecniHrdina, _comebackKid, _pulnocniZachrana, _ranoJeMoudrejsi,
  _bourak, _hatTrick, _nedelniKlid, _univerzal,
  _prokrastinator, _zlomenySlib, _krasovePanstvi, _fantom,
  _nocniSova, _spartanek,
  _stovkar,
];
```

**Step 2:** V `test/constants/achievements_test.dart` smazat `prvni_krok` test grupu. Aktualizovat unique-ids test (uz tam je).

**Step 3:** Run vsechny testy:

```bash
flutter test
```

Expected: PASS — vsech ~30+ testu.

**Step 4:** Commit

```bash
git add lib/constants/achievements.dart test/constants/achievements_test.dart
git commit -m "chore: finalize achievement registry (15 production achievements)"
```

---

> ## REVIEW CHECKPOINT — Phase 4
>
> Stop. Spustit `superpowers:requesting-code-review`. Klice:
> - Vsech 15 achievementu ma positive + negative test (29-31 testu celkove v achievements_test.dart).
> - `flutter test` zelene.
> - `flutter analyze` 0 errors.
> - Predikat funkce jsou peclive napsane — ne kopipastny boilerplate.

---

## Phase 5: UI — stats sekce

### Task 30: `AchievementCard` widget

**Files:**
- Create: `lib/widgets/achievement_card.dart`

**Step 1:** Implement widget. Bere `Achievement` + `bool isUnlocked` + `String? unlockedAt` + optional `int? progressCurrent`, `int? progressTarget` pro milestone. Tap callback.

Klicove vizualni elementy:
- `NeoTheme.cardDecoration` (2px border, hard offset shadow).
- Locked: dark scaffold barva, sedy `?` icon, `???` v title misto realneho titulu, telo = `teaser`.
- Unlocked: plne barevna ikona (`achievement.color`), CAPS title, telo = `description`.
- Milestone locked: pridat tiny progress bar pod telo (`{current} / {target}`).
- `NeoPressable` wrap pro press anim.

Detail kodu vychazi z existujicich karticek (`task_card.dart`) — ten ma podobny styling.

**Step 2:** Manual visual check — pridat docasne na konec `stats_page.dart` jako preview (smaz pred commitu nebo nechej skryte za debug flagem).

**Step 3:** Commit

```bash
git add lib/widgets/achievement_card.dart
git commit -m "feat: AchievementCard widget (locked + unlocked + progress)"
```

---

### Task 31: `AchievementGrid` widget s filter chipy

**Files:**
- Create: `lib/widgets/achievement_grid.dart`

**Step 1:** Implement. Vstup: `Stream<Set<String>> unlockedIdsStream` (z `AchievementService`), volitelne `Map<String, String> unlockedAtMap` (z `achievements` subcollection — separate stream).

Layout:
- Header: "ACHIEVEMENTY" CAPS + counter `{n unlocked} / {n total} odhaleno`.
- Filter chipy: `vse`, `situacni`, `tituly`, `anti`, `milestones`. State v widget (StatefulWidget).
- `Wrap` s `AchievementCard`-y, unlocked first (desc by unlockedAt), pak locked.
- Empty state pri 0 unlocked: hint "Splni neco neobvykleho a uvidi se".

**Step 2:** Manual visual check. Spustit appku, zatim ne integrovane do stats — preview screen.

**Step 3:** Commit

```bash
git add lib/widgets/achievement_grid.dart
git commit -m "feat: AchievementGrid with filter chips"
```

---

### Task 32: `AchievementDetailSheet` bottom sheet

**Files:**
- Create: `lib/widgets/dialogs/achievement_detail_sheet.dart`

**Step 1:** Implementace. Pouziva `showNeoBottomSheet` helper. Vstup: `Achievement`, `String unlockedAt`, `bool isActiveTitle`.

Layout:
- Velka ikona + barva.
- CAPS title.
- `description`.
- `Odemknuto {unlockedAt}`.
- Tlacitko (jen kdyz `isTitleEligible`):
  - Pokud `isActiveTitle == false`: "NASADIT JAKO TITUL" (primary)
  - Pokud `isActiveTitle == true`: "SUNDAT TITUL" (subtle)

OnTap → callback do volajiciho widgetu, ten zavola `AchievementService().setActiveTitle(...)`. Tlacitko se vizualne prepise (StatefulWidget nebo `StreamBuilder<String?>` na `activeTitleStream`).

**Step 2:** Commit

```bash
git add lib/widgets/dialogs/achievement_detail_sheet.dart
git commit -m "feat: AchievementDetailSheet bottom sheet"
```

---

### Task 33: Integrace `AchievementGrid` do `StatsPage`

**Files:**
- Modify: `lib/pages/stats_page.dart`

**Step 1:** Pridat sekci pod existujici grafy. `_loadStats` rozsirit o nacteni `unlockedAtMap` z `achievements` subcollection.

```dart
final unlockedSnap = await FirebaseFirestore.instance
    .collection('users').doc(uid).collection('achievements').get();
final unlockedAtMap = {
  for (final d in unlockedSnap.docs)
    d.id: (d.data() as Map<String, dynamic>)['unlockedAt'] as String,
};
```

Pak v `build`:

```dart
AchievementGrid(
  unlockedAtMap: unlockedAtMap,
  totalCompletedTasks: completedCount,
  onTapCard: (ach) {
    showNeoBottomSheet(
      context: context,
      child: AchievementDetailSheet(
        achievement: ach,
        unlockedAt: unlockedAtMap[ach.id],
      ),
    );
  },
),
```

**Step 2:** Pridat `evaluate()` call na init (lazy trigger pro `/stats` open):

```dart
@override
void initState() {
  super.initState();
  _loadStats();
  AchievementService().evaluate().catchError((_) => <Achievement>[]);
}
```

**Step 3:** Manual test

```bash
flutter run -d chrome
```

1. Otevri `/stats`.
2. Vidis "ACHIEVEMENTY 0 / 15 odhaleno".
3. Filter chipy fungujou.
4. Locked karty maji `???` + teaser.
5. Splnit task — vratit se → najit unlocked card (po 1-2s reload nebo refresh).
6. Tap na unlocked card → detail sheet otevre.

**Step 4:** Commit

```bash
git add lib/pages/stats_page.dart
git commit -m "feat: integrate AchievementGrid into StatsPage"
```

---

## Phase 6: Title management

### Task 34: `AchievementService.setActiveTitle`

**Files:**
- Modify: `lib/services/achievement_service.dart`

**Step 1:** Implementace:

```dart
Future<void> setActiveTitle(String? id) async {
  await _firestore.collection('users').doc(_uid).update({
    'activeTitle': id,
  });
}
```

**Step 2:** Manual test

1. Po unlocku jakeho titul-eligible achievementu, zavolat z DevTools nebo pres UI (Task 36).
2. Firestore: `users/{uid}.activeTitle` ma id.

**Step 3:** Commit

```bash
git add lib/services/achievement_service.dart
git commit -m "feat: setActiveTitle on user doc"
```

---

### Task 35: `TitleChip` widget

**Files:**
- Create: `lib/widgets/title_chip.dart`

**Step 1:** Widget bere `Achievement? achievement` (z registry pres lookup) a renderuje chip. Pokud `achievement == null` → nic.

Layout:
- `NeoTheme` border, `achievement.color`, ikona + title.
- Tap callback (volitelny — pouzity volajicim k navigaci).

```dart
class TitleChip extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback? onTap;

  const TitleChip({super.key, required this.achievement, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: achievement.color,
          border: Border.all(color: Colors.black, width: NeoTheme.borderWidthThin),
          borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(achievement.icon, size: 14, color: Colors.black),
            const SizedBox(width: 4),
            Text(
              achievement.title,
              style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.w700, fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 2:** Commit

```bash
git add lib/widgets/title_chip.dart
git commit -m "feat: TitleChip widget"
```

---

### Task 36: Wire `TitleChip` into `StatsSidebar`

**Files:**
- Modify: `lib/widgets/stats_sidebar.dart`

**Step 1:** Pridat `StreamBuilder<String?>` na `activeTitleStream`. Pokud title id existuje, najit `Achievement` v registry a vykreslit `TitleChip` pod XP/coins radkem. Tap → nav na `/stats`.

```dart
// Pod XP card v `Column`:
StreamBuilder<String?>(
  stream: AchievementService().activeTitleStream(),
  builder: (context, snap) {
    final id = snap.data;
    if (id == null) return const SizedBox.shrink();
    final ach = Achievements.byId(id);
    if (ach == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TitleChip(
        achievement: ach,
        onTap: () => Navigator.pushNamed(context, '/stats'),
      ),
    );
  },
),
```

**Step 2:** Pridat importy.

**Step 3:** Manual test

1. Setnout `activeTitle` na nejaky odemknuty achievement (pres detail sheet — viz Task 38).
2. Vratit se na kalendar.
3. V sidebaru videt chip s nazvem titulu.
4. Tap → naviguje na `/stats`.

**Step 4:** Commit

```bash
git add lib/widgets/stats_sidebar.dart
git commit -m "feat: TitleChip in StatsSidebar"
```

---

### Task 37: Wire `TitleChip` into `/settings`

**Files:**
- Modify: `lib/pages/settings.dart`

**Step 1:** Pod nick editovatelne sekci pridat stejny `StreamBuilder` + `TitleChip`. Tap otevre `showNeoBottomSheet` s buttonem "OTEVRIT STATS" → naviguje.

**Step 2:** Manual test + commit

```bash
git add lib/pages/settings.dart
git commit -m "feat: TitleChip in settings profile section"
```

---

### Task 38: "Nasadit jako titul" akce v `AchievementDetailSheet`

**Files:**
- Modify: `lib/widgets/dialogs/achievement_detail_sheet.dart`

**Step 1:** Akce v button:

```dart
ElevatedButton(
  onPressed: () async {
    final isCurrent = currentActiveTitle == achievement.id;
    await AchievementService().setActiveTitle(isCurrent ? null : achievement.id);
    // Bottom sheet zustava otevreny, button se prepise pres StreamBuilder.
  },
  child: Text(isCurrent ? 'SUNDAT TITUL' : 'NASADIT JAKO TITUL'),
)
```

Wrap button do `StreamBuilder<String?>` na `activeTitleStream` aby se prepsalo automaticky.

**Step 2:** Manual test

1. Otevrit unlocked achievement detail.
2. Klik "NASADIT JAKO TITUL" — button se zmeni na "SUNDAT TITUL".
3. Zavrit sheet, vratit se — `TitleChip` v sidebaru.
4. Otevrit jiny odemknuty achievement → "NASADIT JAKO TITUL". Klik. Predchozi titul zmizel z chipu.
5. Otevrit puvodni → button rika "NASADIT JAKO TITUL" (uz neni aktivni).
6. Klik na aktivni titul → "SUNDAT" → chip zmizí v sidebaru.

**Step 3:** Commit

```bash
git add lib/widgets/dialogs/achievement_detail_sheet.dart
git commit -m "feat: title set/unset from achievement detail sheet"
```

---

## Phase 7: Unlock surface (notifikace + toast)

### Task 39: `'achievement'` notif type v `NotificationsPage`

**Files:**
- Modify: `lib/pages/notifications_page.dart`

**Step 1:** Najit if-else type discrimination (radky ~66-78). Pridat vetev `type == 'achievement'`:

```dart
} else if (type == 'achievement') {
  final ach = Achievements.byId(notif['achievementId'] as String? ?? '');
  icon = Icons.emoji_events_rounded;
  accentColor = ach?.color ?? AppColors.neonYellow;
  titleText = 'ODEMKL JSI ACHIEVEMENT';
  // V karte ukazat taskTitle = ach.title.
}
```

Update karta to render `ach.title` v sub-text (pripadne pres pomocnou variable `subText` co se prida nad existujici layout). Tap → naviguje na `/stats` s argumentem `highlightAchievementId`.

**Step 2:** Manual test

1. Splnit task ktery odemkne achievement.
2. Otevrit `/notifications` — najit kartu "ODEMKL JSI ACHIEVEMENT" + title.
3. Tap → naviguje na `/stats` + scrolluje k achievementu.

**Step 3:** Commit

```bash
git add lib/pages/notifications_page.dart
git commit -m "feat: 'achievement' notification type rendering"
```

---

### Task 40: `AchievementUnlockToast` (in-app SnackBar)

**Files:**
- Create: `lib/widgets/achievement_unlock_toast.dart`

**Step 1:** Funkce `showAchievementUnlockToast(BuildContext, Achievement)`:

```dart
void showAchievementUnlockToast(BuildContext context, Achievement ach) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.transparent,
      elevation: 0,
      content: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/stats'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: ach.color,
            border: Border.all(color: Colors.black, width: NeoTheme.borderWidth),
            boxShadow: [BoxShadow(color: Colors.black, offset: NeoTheme.shadowOffsetSmall, blurRadius: 0)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ach.icon, color: Colors.black),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Odemknul jsi: ${ach.title}',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

**Step 2:** Commit

```bash
git add lib/widgets/achievement_unlock_toast.dart
git commit -m "feat: AchievementUnlockToast SnackBar wrapper"
```

---

### Task 41: Hook toast do `evaluate()` results

**Files:**
- Modify: `lib/main.dart`
- Pripadne: `lib/pages/login.dart`, `lib/services/task_service.dart`, `lib/services/habit_service.dart`

**Step 1:** Problem: `evaluate()` se vola fire-and-forget z mnoha mist, ale toast vyzaduje `BuildContext`. Reseni: vystavit `ValueNotifier<List<Achievement>>` v `AchievementService` ktery globalni listener v `main.dart` posluchne pres `navigatorKey.currentContext`.

V `AchievementService`:

```dart
final ValueNotifier<List<Achievement>> newlyUnlocked = ValueNotifier([]);

Future<List<Achievement>> evaluate() async {
  // ...existujici logika...
  // Pred return:
  if (newly.isNotEmpty) newlyUnlocked.value = newly;
  return newly;
}
```

V `main.dart`:

```dart
@override
void initState() {
  super.initState();
  _hookAchievementTrigger();
  AchievementService().newlyUnlocked.addListener(_handleUnlock);
}

void _handleUnlock() {
  final list = AchievementService().newlyUnlocked.value;
  if (list.isEmpty) return;
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;
  // Ukaz toast jen pro POSLEDNI unlocked (zbytek je v notif feedu).
  showAchievementUnlockToast(ctx, list.last);
  AchievementService().newlyUnlocked.value = [];
}

@override
void dispose() {
  AchievementService().newlyUnlocked.removeListener(_handleUnlock);
  _notifSub?.cancel();
  super.dispose();
}
```

**Step 2:** Manual test

1. Splnit task ktery odemkne achievement.
2. Po ~1-2s toast pristane se nazvem achievementu.
3. Tap → naviguje na `/stats`.
4. Toast se nezobrazi pri achievement uz odemknutem (idempotence).

**Step 3:** Commit

```bash
git add lib/services/achievement_service.dart lib/main.dart
git commit -m "feat: unlock toast on evaluate result"
```

---

### Task 42: Highlight-on-navigate od notif

**Files:**
- Modify: `lib/main.dart` (route table)
- Modify: `lib/pages/stats_page.dart`
- Modify: `lib/pages/notifications_page.dart`

**Step 1:** Predat argument pri navigaci ze notif:

```dart
// V notifications_page.dart, tap handler:
Navigator.pushNamed(context, '/stats', arguments: {'highlightId': notif['achievementId']});
```

**Step 2:** V `StatsPage` initState precist argument a po `_loadStats` scrollovat k te karte + 2s border pulse anim.

Implementace pulse: `AnimationController` s `Tween<Color>` na border. Trigger 2s, pak normal.

**Step 3:** Manual test

1. Odemknout achievement.
2. Otevrit `/notifications` → tap.
3. `/stats` se otevre, scroll k te karte, 2s pulse.

**Step 4:** Commit

```bash
git add lib/main.dart lib/pages/stats_page.dart lib/pages/notifications_page.dart
git commit -m "feat: highlight achievement card on navigate from notif"
```

---

> ## FINAL REVIEW CHECKPOINT — Phase 5-7
>
> Stop. Spustit `superpowers:requesting-code-review` + manual acceptance tests v sekci 5 design docu (`docs/plans/2026-05-12-achievements-design.md`).
>
> Acceptance tests:
> 1. Cisty install + 1 confirm → smoke achievement test (`comeback_kid` po reject + retry, nebo `bourak` po 3 confirms).
> 2. Odemkni 3 achievementy ruznych typu rychle → 3 unlocks v `/stats`, 3 notif, 1 toast (posledni).
> 3. Tap unlocked card → detail sheet. "Nasadit jako titul" → chip v sidebaru + settings.
> 4. Sundat titul → chip zmizí (zadny placeholder).
> 5. Reinstal appky → odemknute pretazeny z Firestore.
> 6. Vytvorit habit → eval bezi v pozadi.
> 7. Locked karty: `???` + teaser, milestone ma progress bar.
> 8. Filter chipy fungujou.
> 9. Notif tap → highlight pulse na `/stats`.

---

## Yagni reminders

Co NEpridavat:
- Sdileni achievementu (screenshot → social).
- Repeatable / leveled achievementy.
- Push notifikace.
- Konfety / blokujici modaly pri unlocku.
- Achievement editor / admin panel.
- Migrace existujicich `completedAt` na full timestamp.

---

## Po dokonceni

1. Update memory `project_v2_push.md` (achievements DONE, dalsi krok stats refactor).
2. Merge `feat/habits` (nebo nova branch `feat/achievements`) do `main` pres `superpowers:finishing-a-development-branch`.
3. Pristi v2 faze: stats refactor.
