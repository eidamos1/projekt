import 'task.dart';
import '../utils/date_helpers.dart';

enum RecurrenceType { everyday, weekdays, custom }

class Habit {
  final String id;
  final String title;
  final TaskType type;
  final RecurrenceType recurrence;
  final List<int> customDays; // 1..7, 1=Mon, empty unless custom
  final String startDate;     // yyyy-MM-dd
  final bool active;
  final int streak;
  final int longestStreak;
  final String? lastCompletedDate;
  /// Category keys inherited by every generated task instance.
  final List<String> categories;

  Habit({
    required this.id,
    required this.title,
    required this.type,
    required this.recurrence,
    this.customDays = const [],
    required this.startDate,
    this.active = true,
    this.streak = 0,
    this.longestStreak = 0,
    this.lastCompletedDate,
    this.categories = const [],
  });

  factory Habit.fromMap(String id, Map<String, dynamic> data) {
    return Habit(
      id: id,
      title: data['title'] ?? '',
      type: TaskType.values.firstWhere(
          (e) => e.toString().split('.').last == (data['type'] ?? 'daily'),
          orElse: () => TaskType.daily),
      recurrence: RecurrenceType.values.firstWhere(
          (e) => e.toString().split('.').last ==
              (data['recurrence'] ?? 'everyday'),
          orElse: () => RecurrenceType.everyday),
      customDays: (data['customDays'] as List?)?.cast<int>() ?? const [],
      startDate: data['startDate'] ?? '',
      active: data['active'] ?? true,
      streak: data['streak'] ?? 0,
      longestStreak: data['longestStreak'] ?? 0,
      lastCompletedDate: data['lastCompletedDate'],
      categories: (data['categories'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type.toString().split('.').last,
      'recurrence': recurrence.toString().split('.').last,
      'customDays': customDays,
      'startDate': startDate,
      'active': active,
      'streak': streak,
      'longestStreak': longestStreak,
      'lastCompletedDate': lastCompletedDate,
      'categories': categories,
    };
  }

  bool expectedOn(DateTime date) {
    if (!active) return false;
    final dateStr = formatDate(date);
    if (dateStr.compareTo(startDate) < 0) return false;
    switch (recurrence) {
      case RecurrenceType.everyday:
        return true;
      case RecurrenceType.weekdays:
        return date.weekday >= 1 && date.weekday <= 5;
      case RecurrenceType.custom:
        return customDays.contains(date.weekday);
    }
  }

  /// Max gap between expected days for any supported recurrence is 7
  /// (e.g. custom with a single weekday). 14 gives 2x safety; beyond
  /// that the streak is definitionally broken.
  static const _maxLookbackDays = 14;

  DateTime? previousExpectedDay(DateTime day) {
    for (int i = 1; i <= _maxLookbackDays; i++) {
      final candidate = day.subtract(Duration(days: i));
      if (expectedOn(candidate)) return candidate;
    }
    return null;
  }

  Habit copyWith({
    String? title,
    TaskType? type,
    RecurrenceType? recurrence,
    List<int>? customDays,
    String? startDate,
    bool? active,
    int? streak,
    int? longestStreak,
    String? lastCompletedDate,
    List<String>? categories,
  }) {
    return Habit(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      recurrence: recurrence ?? this.recurrence,
      customDays: customDays ?? this.customDays,
      startDate: startDate ?? this.startDate,
      active: active ?? this.active,
      streak: streak ?? this.streak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      categories: categories ?? this.categories,
    );
  }
}
