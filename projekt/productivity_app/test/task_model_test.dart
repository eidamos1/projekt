import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/models/task.dart';

void main() {
  group('Task model', () {
    test('fromMap creates Task correctly', () {
      final data = {
        'title': 'Testovaci ukol',
        'type': 'daily',
        'date': '2025-01-15',
        'xp': 10,
        'coins': 5,
        'code': '123456',
        'completed': false,
        'imageBase64': null,
      };

      final task = Task.fromMap('test-id', data);

      expect(task.id, 'test-id');
      expect(task.title, 'Testovaci ukol');
      expect(task.type, TaskType.daily);
      expect(task.date, '2025-01-15');
      expect(task.xp, 10);
      expect(task.coins, 5);
      expect(task.code, '123456');
      expect(task.completed, false);
      expect(task.imageBase64, null);
    });

    test('fromMap handles weekly type', () {
      final data = {
        'title': 'Tydenni ukol',
        'type': 'weekly',
        'date': '2025-01-15',
        'xp': 50,
        'coins': 20,
        'code': '654321',
      };

      final task = Task.fromMap('id2', data);
      expect(task.type, TaskType.weekly);
      expect(task.xp, 50);
      expect(task.coins, 20);
    });

    test('fromMap handles monthly type', () {
      final data = {
        'title': 'Mesicni ukol',
        'type': 'monthly',
        'date': '2025-01-15',
        'xp': 200,
        'coins': 100,
        'code': '111111',
      };

      final task = Task.fromMap('id3', data);
      expect(task.type, TaskType.monthly);
      expect(task.xp, 200);
      expect(task.coins, 100);
    });

    test('fromMap defaults to daily for unknown type', () {
      final data = {
        'title': 'Unknown type',
        'type': 'unknown',
        'date': '2025-01-15',
        'xp': 0,
        'coins': 0,
        'code': '000000',
      };

      final task = Task.fromMap('id4', data);
      expect(task.type, TaskType.daily);
    });

    test('fromMap handles missing fields gracefully', () {
      final data = <String, dynamic>{};
      final task = Task.fromMap('id5', data);

      expect(task.title, '');
      expect(task.type, TaskType.daily);
      expect(task.date, '');
      expect(task.xp, 0);
      expect(task.coins, 0);
      expect(task.code, '');
      expect(task.completed, false);
      expect(task.imageBase64, null);
    });

    test('toMap produces correct map', () {
      final task = Task(
        id: 'test-id',
        title: 'Muj ukol',
        type: TaskType.weekly,
        date: '2025-03-01',
        xp: 50,
        coins: 20,
        code: '999999',
        completed: true,
        imageBase64: 'base64data',
      );

      final map = task.toMap();

      expect(map['title'], 'Muj ukol');
      expect(map['type'], 'weekly');
      expect(map['date'], '2025-03-01');
      expect(map['xp'], 50);
      expect(map['coins'], 20);
      expect(map['code'], '999999');
      expect(map['completed'], true);
      expect(map['imageBase64'], 'base64data');
      // id neni v mape (generuje Firestore)
      expect(map.containsKey('id'), false);
    });

    test('toMap roundtrip preserves data', () {
      final original = Task(
        id: 'roundtrip',
        title: 'Roundtrip test',
        type: TaskType.monthly,
        date: '2025-06-15',
        xp: 200,
        coins: 100,
        code: '555555',
        completed: false,
      );

      final map = original.toMap();
      final restored = Task.fromMap('roundtrip', map);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.type, original.type);
      expect(restored.date, original.date);
      expect(restored.xp, original.xp);
      expect(restored.coins, original.coins);
      expect(restored.code, original.code);
      expect(restored.completed, original.completed);
    });

    test('categories default to empty list when missing', () {
      final task = Task.fromMap('id', {'title': 't'});
      expect(task.categories, isEmpty);
    });

    test('categories survive fromMap/toMap roundtrip', () {
      final original = Task(
        id: 'cat',
        title: 'Categorized',
        type: TaskType.daily,
        date: '2026-04-29',
        xp: 10,
        coins: 5,
        code: '111222',
        categories: const ['work', 'personal'],
      );
      final restored = Task.fromMap('cat', original.toMap());
      expect(restored.categories, ['work', 'personal']);
    });
  });

  group('wasRejected and completedAt extensions', () {
    test('wasRejected defaults to false in constructor', () {
      final t = Task(
        id: '1', title: 'x', type: TaskType.daily,
        date: '2026-05-13', xp: 10, coins: 5, code: '123456',
      );
      expect(t.wasRejected, isFalse);
    });

    test('completedAt defaults to null in constructor', () {
      final t = Task(
        id: '1', title: 'x', type: TaskType.daily,
        date: '2026-05-13', xp: 10, coins: 5, code: '123456',
      );
      expect(t.completedAt, isNull);
    });

    test('fromMap reads wasRejected when present', () {
      final t = Task.fromMap('1', {
        'title': 'x', 'type': 'daily', 'date': '2026-05-13',
        'xp': 10, 'coins': 5, 'code': '123456',
        'wasRejected': true,
      });
      expect(t.wasRejected, isTrue);
    });

    test('fromMap defaults wasRejected to false for legacy doc', () {
      final t = Task.fromMap('1', {
        'title': 'x', 'type': 'daily', 'date': '2026-05-13',
        'xp': 10, 'coins': 5, 'code': '123456',
      });
      expect(t.wasRejected, isFalse);
    });

    test('fromMap reads completedAt (date-only legacy format)', () {
      final t = Task.fromMap('1', {
        'title': 'x', 'type': 'daily', 'date': '2026-05-13',
        'xp': 10, 'coins': 5, 'code': '123456',
        'completedAt': '2026-05-12',
      });
      expect(t.completedAt, '2026-05-12');
    });

    test('fromMap reads completedAt (new HH:mm format)', () {
      final t = Task.fromMap('1', {
        'title': 'x', 'type': 'daily', 'date': '2026-05-13',
        'xp': 10, 'coins': 5, 'code': '123456',
        'completedAt': '2026-05-12 23:45',
      });
      expect(t.completedAt, '2026-05-12 23:45');
    });

    test('toMap includes wasRejected and completedAt', () {
      final t = Task(
        id: '1', title: 'x', type: TaskType.daily,
        date: '2026-05-13', xp: 10, coins: 5, code: '123456',
        wasRejected: true,
        completedAt: '2026-05-13 14:30',
      );
      final map = t.toMap();
      expect(map['wasRejected'], isTrue);
      expect(map['completedAt'], '2026-05-13 14:30');
    });
  });

  group('typeLabel', () {
    test('daily returns Denní', () {
      final task = Task(
        id: 'x', title: 'T', type: TaskType.daily,
        date: '', xp: 0, coins: 0, code: '',
      );
      expect(task.typeLabel, 'Denní');
    });

    test('weekly returns Týdenní', () {
      final task = Task(
        id: 'x', title: 'T', type: TaskType.weekly,
        date: '', xp: 0, coins: 0, code: '',
      );
      expect(task.typeLabel, 'Týdenní');
    });

    test('monthly returns Měsíční', () {
      final task = Task(
        id: 'x', title: 'T', type: TaskType.monthly,
        date: '', xp: 0, coins: 0, code: '',
      );
      expect(task.typeLabel, 'Měsíční');
    });
  });

  group('Level calculation', () {
    test('0 XP = Level 1', () {
      expect((0 ~/ 100) + 1, 1);
    });

    test('99 XP = Level 1', () {
      expect((99 ~/ 100) + 1, 1);
    });

    test('100 XP = Level 2', () {
      expect((100 ~/ 100) + 1, 2);
    });

    test('250 XP = Level 3', () {
      expect((250 ~/ 100) + 1, 3);
    });

    test('999 XP = Level 10', () {
      expect((999 ~/ 100) + 1, 10);
    });

    test('1000 XP = Level 11', () {
      expect((1000 ~/ 100) + 1, 11);
    });
  });
}
