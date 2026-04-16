import '../constants/strings.dart';

enum TaskType { daily, weekly, monthly }

class Task {
  final String id;
  final String title;
  final TaskType type;
  final String date;
  final int xp;
  final int coins;
  final String code;
  final bool completed;
  final String? imageBase64;
  final bool rejected;
  final String? rejectionReason;
  final String? habitId;

  Task({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    required this.xp,
    required this.coins,
    required this.code,
    this.completed = false,
    this.imageBase64,
    this.rejected = false,
    this.rejectionReason,
    this.habitId,
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
      imageBase64: data['imageBase64'],
      rejected: data['rejected'] ?? false,
      rejectionReason: data['rejectionReason'],
      habitId: data['habitId'],
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
      'imageBase64': imageBase64,
      'rejected': rejected,
      'rejectionReason': rejectionReason,
      'habitId': habitId,
    };
  }

  String get typeLabel {
    switch (type) {
      case TaskType.daily:
        return Strings.typeDailyAccented;
      case TaskType.weekly:
        return Strings.typeWeeklyAccented;
      case TaskType.monthly:
        return Strings.typeMonthlyAccented;
    }
  }
}
