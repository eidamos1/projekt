import '../models/task.dart';

/// Vrati Map<yyyy-MM-dd → pocet splnenych ukolu>.
Map<String, int> tasksPerDay(List<Task> tasks) {
  final counts = <String, int>{};
  for (final t in tasks) {
    if (!t.completed) continue;
    counts.update(t.date, (v) => v + 1, ifAbsent: () => 1);
  }
  return counts;
}
