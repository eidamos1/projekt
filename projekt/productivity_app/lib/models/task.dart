// models/task.dart
enum TaskType { daily, weekly, monthly }
class Task {
  final String id;
  final String title;
  final TaskType type;    // "Denní", "Týdenní" nebo "Měsíční"
  final String date;    // uložené jako 'yyyy-MM-dd'
  final int xp;
  final int coins;
  final String code;
  final bool completed;

  Task({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    required this.xp,
    required this.coins,
    required this.code,
    this.completed = false,
  });

  factory Task.fromMap(String id, Map<String, dynamic> data) {
    return Task(
      id: id,
      title: data['title'] ?? '',
      type: TaskType.values.firstWhere(
          (e) => e.toString().split('.').last == (data['type'] ?? 'daily'),
          orElse: () => TaskType.daily),
      date: data['date'] ?? '',
      xp: data['xp'] ?? 0,
      coins: data['coins'] ?? 0,
      code: data['code'] ?? '',
      completed: data['completed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type.toString().split('.').last,
      'date': date,
      'xp': xp,
      'coins': coins,
      'code': code,
      'completed': completed,
    };
  }

  String get typeLabel {
    switch (type) {
      case TaskType.daily:
        return 'Denní';
      case TaskType.weekly:
        return 'Týdenní';
      case TaskType.monthly:
        return 'Měsíční';
    }
  }
}
