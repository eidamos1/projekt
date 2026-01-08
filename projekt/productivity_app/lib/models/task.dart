// models/task.dart
class Task {
  final String id;
  final String title;
  final String type;    // "Denní", "Týdenní" nebo "Měsíční"
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
      type: data['type'] ?? 'Denní',
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
      'type': type,
      'date': date,
      'xp': xp,
      'coins': coins,
      'code': code,
      'completed': completed,
    };
  }
}
