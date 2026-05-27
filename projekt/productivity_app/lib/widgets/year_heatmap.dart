import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';

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

  /// Cells from [startMonday] (inclusive) through Sunday of [today]'s week.
  /// First cell is always a Monday; total length is a multiple of 7.
  /// Post-today cells in the final column are filled and must be rendered
  /// as empty/transparent by the caller.
  static List<DateTime> cellsFromMondayThroughWeekOf(
      DateTime startMonday, DateTime today) {
    final lastCell = DateTime(today.year, today.month, today.day);
    final daysToSunday = 7 - lastCell.weekday;
    final lastSunday = DateTime(
      lastCell.year,
      lastCell.month,
      lastCell.day + daysToSunday,
    );
    final totalDays = lastSunday.difference(startMonday).inDays + 1;
    return [
      for (int i = 0; i < totalDays; i++)
        DateTime(startMonday.year, startMonday.month, startMonday.day + i),
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
    // so users see today's activity first.
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
    return LayoutBuilder(
        builder: (context, constraints) => _build(context, constraints));
  }

  Widget _build(BuildContext context, BoxConstraints constraints) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    const spacing = 2.0;
    const labelColumnWidth = 22.0;

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    // Always render a full 365-day window — gives every user a year-wide
    // GitHub-style grid, with empty days as muted cells. Round down to the
    // Monday of the window so columns align.
    final startDate = todayMidnight.subtract(const Duration(days: 365));
    final startMonday = startDate.subtract(
      Duration(days: (startDate.weekday - 1) % 7),
    );
    // Days before the user's first task get a slightly more muted shade so
    // there's visual separation between "before you joined" and "blank day".
    DateTime? firstTaskParsed;
    if (widget.firstTaskDate != null && widget.firstTaskDate!.isNotEmpty) {
      try {
        firstTaskParsed = DateTime.parse(widget.firstTaskDate!);
      } catch (_) {}
    }

    final cells =
        YearHeatmap.cellsFromMondayThroughWeekOf(startMonday, todayMidnight);
    final weeks = cells.length ~/ 7;

    // Available width = parent minus card padding (2*spaceSm=16) minus left
    // weekday label column. Cell scales so all weeks fit when possible; below
    // 12px we let it overflow horizontally with a scroll fade.
    final availableWidth =
        constraints.maxWidth - (NeoTheme.spaceSm * 2) - labelColumnWidth;
    final cellSize = (availableWidth / weeks - spacing).clamp(12.0, 22.0);
    final gridWidth = labelColumnWidth + weeks * (cellSize + spacing);
    final overflows = gridWidth > constraints.maxWidth - 16;

    final columns = <Widget>[];
    for (int week = 0; week < weeks; week++) {
      final rows = <Widget>[];
      for (int day = 0; day < 7; day++) {
        final idx = week * 7 + day;
        final date = cells[idx];
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final count = widget.tasksPerDay[dateStr] ?? 0;
        final bucket = YearHeatmap.intensityBucket(count);
        final isFuture = date.isAfter(todayMidnight);
        final preFirstTask =
            firstTaskParsed != null && date.isBefore(firstTaskParsed);

        Color color;
        if (isFuture) {
          color = Colors.transparent;
        } else if (bucket == 0) {
          // Pre-first-task days are dimmer so "before you joined" reads
          // differently from "blank day since you joined".
          final empty = isDark
              ? const Color(0xFF2E2E3A)
              : const Color(0xFFE8E8E8);
          color = preFirstTask ? empty.withValues(alpha: 0.35) : empty;
        } else {
          final alpha = 0.30 + 0.175 * bucket; // 0.475, 0.65, 0.825, 1.00
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
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ));
      }
      columns.add(Padding(
        padding: const EdgeInsets.only(right: spacing),
        child: Column(children: rows),
      ));
    }

    // Month labels placed where each month starts. Use a Stack so labels can
    // overflow their column slot — no more wrapping "cv c" / "sr p".
    final monthLabels = <Widget>[];
    String? prevMonth;
    for (int week = 0; week < weeks; week++) {
      final firstDate = cells[week * 7];
      final month = _monthLabel(firstDate.month);
      // Show on a column's first-day-of-month or first week with new month.
      if (prevMonth != month && firstDate.day <= 7) {
        monthLabels.add(Positioned(
          left: week * (cellSize + spacing),
          child: Text(
            month,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ));
        prevMonth = month;
      }
    }

    const weekDayNames = ['Po', '', 'St', '', 'Pá', '', ''];
    final weekLabels = <Widget>[];
    for (int day = 0; day < 7; day++) {
      weekLabels.add(SizedBox(
        height: cellSize + spacing,
        child: Text(
          weekDayNames[day],
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ));
    }

    final gridWidthForLabels = weeks * (cellSize + spacing);

    final innerGrid = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: labelColumnWidth, bottom: 4),
          child: SizedBox(
            width: gridWidthForLabels,
            height: 14,
            child: Stack(
              clipBehavior: Clip.none,
              children: monthLabels,
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelColumnWidth,
              child: Column(children: weekLabels),
            ),
            Row(children: columns),
          ],
        ),
      ],
    );

    // When the grid fits, right-align it so today's column hugs the right
    // edge (latest = newest, like GitHub heatmap). When it overflows,
    // horizontal scroll handles the layout and auto-scrolls to today.
    final grid = overflows
        ? SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: innerGrid,
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [innerGrid],
          );

    final legend = Padding(
      padding: const EdgeInsets.only(top: 8, left: labelColumnWidth),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            Strings.heatmapLess,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(width: 6),
          for (int b = 0; b <= 4; b++) ...[
            Container(
              width: 11,
              height: 11,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: b == 0
                    ? (isDark
                        ? const Color(0xFF2E2E3A)
                        : const Color(0xFFE8E8E8))
                    : primary.withValues(alpha: 0.30 + 0.175 * b),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
          const SizedBox(width: 3),
          Text(
            Strings.heatmapMore,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        overflows
            ? Stack(
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
              )
            : grid,
        legend,
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(NeoTheme.spaceSm),
      decoration: NeoTheme.cardDecoration(isDark: isDark),
      child: body,
    );
  }

  static String _monthLabel(int m) {
    const labels = [
      '', 'led', 'úno', 'bře', 'dub', 'kvě', 'čer',
      'čvc', 'srp', 'zář', 'říj', 'lis', 'pro',
    ];
    return labels[m];
  }
}
