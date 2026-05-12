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
  /// Category keys (see Categories.byKey). Empty list = uncategorized.
  final List<String> categories;
  /// Persistent flag — true if this task was ever rejected, even after reset.
  /// Drives achievements like comeback_kid.
  final bool wasRejected;
  /// Completion timestamp. Either 'yyyy-MM-dd' (legacy) or 'yyyy-MM-dd HH:mm'.
  /// Null until task is confirmed.
  final String? completedAt;

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
    this.categories = const [],
    this.wasRejected = false,
    this.completedAt,
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
      categories: (data['categories'] as List?)?.cast<String>() ?? const [],
      wasRejected: data['wasRejected'] ?? false,
      completedAt: data['completedAt'] is String ? data['completedAt'] as String : null,
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
      'categories': categories,
      'wasRejected': wasRejected,
      'completedAt': completedAt,
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
