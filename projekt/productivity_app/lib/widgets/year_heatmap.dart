import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';

class YearHeatmap extends StatefulWidget {
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

  /// Vrati 53 * 7 = 371 DateTime hodnot. Cells[0] je Monday at or before
  /// (today's Sunday - 53 weeks). Cells.last je Sunday of today's week (muze
  /// byt v budoucnosti). Render musi treat post-today cells jako prazdne.
  static List<DateTime> cellsFor(DateTime today) {
    final lastCell = DateTime(today.year, today.month, today.day);
    // weekday: 1=Mon..7=Sun. Find Sunday at or after today.
    final daysToSunday = 7 - lastCell.weekday;
    // Last cell of grid = end of today's week (Sunday).
    // First cell of grid = Monday 53*7 - 1 days before that.
    // Use DateTime constructor with negative day (Dart normalizes).
    return [
      for (int i = 0; i < 53 * 7; i++)
        DateTime(
          lastCell.year,
          lastCell.month,
          lastCell.day + daysToSunday - (53 * 7 - 1) + i,
        ),
    ];
  }

  @override
  State<YearHeatmap> createState() => _YearHeatmapState();
}

class _YearHeatmapState extends State<YearHeatmap> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-scroll to the most recent week (right edge) after first frame
    // so users see today's activity first, not 12-month-old empty cells.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) => _build(context, constraints));
  }

  Widget _build(BuildContext context, BoxConstraints constraints) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    const spacing = 2.0;
    // Available width = parent constraint minus container padding (2*spaceSm=16)
    // minus left weekday label column (~20) minus its spacing (4).
    final availableWidth = constraints.maxWidth - 16 - 24;
    // Cell size scales so all 53 columns fit horizontally when possible.
    // Min 12px so cells stay readable on mobile (horizontal scroll handles
    // the overflow when viewport is narrow).
    final cellSize = (availableWidth / 53 - spacing).clamp(12.0, 22.0);
    final gridWidth = 24 + 53 * (cellSize + spacing);
    final overflows = gridWidth > constraints.maxWidth - 16;

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final cells = YearHeatmap.cellsFor(now);
    final firstCellDate = widget.firstTaskDate != null
        ? DateTime.parse(widget.firstTaskDate!)
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
        final count = widget.tasksPerDay[dateStr] ?? 0;
        final bucket = YearHeatmap.intensityBucket(count);
        final preSignup = firstCellDate != null && date.isBefore(firstCellDate);
        final isFuture = date.isAfter(todayMidnight);

        Color color;
        if (preSignup || isFuture) {
          color = Colors.transparent;
        } else if (bucket == 0) {
          // Bucket-0 must contrast with the card background (cardDark
          // 0xFF1A1A24) so empty cells are visibly present, not invisible.
          color = isDark ? const Color(0xFF3A3A48) : const Color(0xFFE0E0E0);
        } else {
          final alpha = 0.20 + 0.20 * bucket;  // 0.40, 0.60, 0.80, 1.00
          color = primary.withValues(alpha: alpha);
        }

        rows.add(GestureDetector(
          onTap: count > 0 ? () => widget.onCellTap(date) : null,
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

    final grid = SingleChildScrollView(
      controller: _scrollController,
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
    );

    // When the grid overflows the container (mobile width), show a fade
    // indicator on the right edge so users see there's more to scroll.
    if (!overflows) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(NeoTheme.spaceSm),
        decoration: NeoTheme.cardDecoration(isDark: isDark),
        child: grid,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(NeoTheme.spaceSm),
      decoration: NeoTheme.cardDecoration(isDark: isDark),
      child: Stack(
        children: [
          grid,
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      isDark ? AppColors.cardDark : AppColors.cardLight,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _monthLabel(int m) {
    const labels = ['', 'led', 'uno', 'bre', 'dub', 'kve', 'cer',
        'cvc', 'srp', 'zar', 'rij', 'lis', 'pro'];
    return labels[m];
  }
}
