import 'package:flutter/material.dart';
import '../constants/neo_theme.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final mediaWidth = MediaQuery.of(context).size.width;
    final isWide = mediaWidth >= 1080;
    final cellSize = isWide ? 18.0 : 12.0;
    const spacing = 2.0;

    final cells = cellsFor(DateTime.now());
    final firstCellDate = firstTaskDate != null
        ? DateTime.parse(firstTaskDate!)
        : null;

    final columns = <Widget>[];
    for (int week = 0; week < 53; week++) {
      final rows = <Widget>[];
      for (int day = 0; day < 7; day++) {
        final idx = week * 7 + day;
        if (idx >= cells.length) {
          rows.add(SizedBox(width: cellSize, height: cellSize));
          continue;
        }
        final date = cells[idx];
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final count = tasksPerDay[dateStr] ?? 0;
        final bucket = intensityBucket(count);
        final preSignup = firstCellDate != null && date.isBefore(firstCellDate);

        Color color;
        if (preSignup) {
          color = Colors.transparent;
        } else if (bucket == 0) {
          color = isDark ? const Color(0xFF1A1A24) : const Color(0xFFE8E8E8);
        } else {
          final alpha = 0.25 * bucket;
          color = primary.withValues(alpha: alpha);
        }

        rows.add(GestureDetector(
          onTap: count > 0 ? () => onCellTap(date) : null,
          child: Container(
            width: cellSize,
            height: cellSize,
            margin: const EdgeInsets.symmetric(vertical: spacing / 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ));
      }
      columns.add(Padding(
        padding: const EdgeInsets.only(right: spacing),
        child: Column(children: rows),
      ));
    }

    // Mesicni labely nad sloupcem kde dany mesic zacina.
    final monthLabels = <Widget>[];
    String? prevMonth;
    for (int week = 0; week < 53; week++) {
      final firstDayIdx = week * 7;
      if (firstDayIdx >= cells.length) {
        monthLabels.add(SizedBox(width: cellSize + spacing));
        continue;
      }
      final firstDate = cells[firstDayIdx];
      final month = _monthLabel(firstDate.month);
      final showLabel = prevMonth != month && firstDate.day <= 7;
      monthLabels.add(SizedBox(
        width: cellSize + spacing,
        child: Text(
          showLabel ? month : '',
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ));
      if (showLabel) prevMonth = month;
    }

    const weekDayNames = ['Po', '', 'St', '', 'Pa', '', ''];
    final weekLabels = <Widget>[];
    for (int day = 0; day < 7; day++) {
      weekLabels.add(SizedBox(
        height: cellSize + spacing,
        child: Text(
          weekDayNames[day],
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(NeoTheme.spaceSm),
      decoration: NeoTheme.cardDecoration(isDark: isDark),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Row(children: monthLabels),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(children: weekLabels),
                const SizedBox(width: 4),
                Row(children: columns),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _monthLabel(int m) {
    const labels = ['', 'led', 'uno', 'bre', 'dub', 'kve', 'cer',
        'cvc', 'srp', 'zar', 'rij', 'lis', 'pro'];
    return labels[m];
  }
}
