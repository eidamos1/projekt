import 'package:flutter/material.dart';

class YearHeatmap extends StatelessWidget {
  final Map<String, int> tasksPerDay;
  final String? firstTaskDate;
  final void Function(DateTime date) onCellTap;

  const YearHeatmap({
    super.key,
    required this.tasksPerDay,
    required this.onCellTap,
    this.firstTaskDate,
  });

  static int intensityBucket(int count) {
    if (count <= 0) return 0;
    if (count >= 4) return 4;
    return count;
  }

  /// Vrati 53 * 7 = 371 DateTime hodnot. Posledni napravo = today, predchozi
  /// rolling-back po dnech. Nejlevejsi sloupec = pred ~52 tydny.
  static List<DateTime> cellsFor(DateTime today) {
    final lastCell = DateTime(today.year, today.month, today.day);
    final cells = <DateTime>[];
    for (int i = 53 * 7 - 1; i >= 0; i--) {
      cells.add(lastCell.subtract(Duration(days: i)));
    }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // skeleton, real render comes later
  }
}
