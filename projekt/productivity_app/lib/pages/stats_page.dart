import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../utils/context_extensions.dart';
import '../utils/date_helpers.dart';
import '../widgets/responsive_layout.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final _taskService = TaskService();
  List<Task> _allTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final tasks = await _taskService.allTasks();
      if (mounted) {
        setState(() {
          _allTasks = tasks;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text(Strings.stats)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final completed = _allTasks.where((t) => t.completed).toList();
    final total = _allTasks.length;
    final completedCount = completed.length;

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisWeekCompleted = completed.where((t) {
      try {
        final d = parseDate(t.date);
        return d.isAfter(weekStart.subtract(const Duration(days: 1)));
      } catch (_) {
        return false;
      }
    }).length;

    final thisMonthCompleted = completed.where((t) {
      try {
        final d = parseDate(t.date);
        return d.month == now.month && d.year == now.year;
      } catch (_) {
        return false;
      }
    }).length;

    final dailyCount =
        _allTasks.where((t) => t.type == TaskType.daily).length;
    final weeklyCount =
        _allTasks.where((t) => t.type == TaskType.weekly).length;
    final monthlyCount =
        _allTasks.where((t) => t.type == TaskType.monthly).length;

    final dayCount = <int, int>{};
    for (final t in completed) {
      try {
        final d = parseDate(t.date);
        dayCount[d.weekday] = (dayCount[d.weekday] ?? 0) + 1;
      } catch (_) {}
    }
    String bestDay = '-';
    if (dayCount.isNotEmpty) {
      final best =
          dayCount.entries.reduce((a, b) => a.value > b.value ? a : b);
      bestDay = Strings.dayNames[best.key] ?? '-';
    }

    final xpPerDay = <String, int>{};
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = formatDate(day);
      xpPerDay[key] = 0;
    }
    for (final t in completed) {
      if (xpPerDay.containsKey(t.date)) {
        xpPerDay[t.date] = xpPerDay[t.date]! + t.xp;
      }
    }

    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.stats)),
      body: ResponsiveLayout(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(NeoTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatCard(
                    label: Strings.totalTasks,
                    value: '$total',
                    color: context.primaryColor),
                const SizedBox(width: NeoTheme.spaceSm),
                _StatCard(
                    label: Strings.completedTasks,
                    value: '$completedCount',
                    color: AppColors.neonGreen),
              ],
            ),
            const SizedBox(height: NeoTheme.spaceSm),
            Row(
              children: [
                _StatCard(
                    label: Strings.thisWeek,
                    value: '$thisWeekCompleted',
                    color: AppColors.taskDaily),
                const SizedBox(width: NeoTheme.spaceSm),
                _StatCard(
                    label: Strings.thisMonth,
                    value: '$thisMonthCompleted',
                    color: AppColors.taskWeekly),
              ],
            ),
            const SizedBox(height: NeoTheme.spaceMd),

            Container(
              decoration: NeoTheme.cardDecoration(isDark: isDark),
              child: ListTile(
                leading: const Icon(Icons.star_rounded,
                    color: AppColors.neonYellow, size: 28),
                title: const Text(Strings.bestDay,
                    style: NeoTheme.subhead),
                trailing: Text(bestDay,
                    style: NeoTheme.headline.copyWith(
                      color: AppColors.neonYellow,
                      fontSize: 18,
                    )),
              ),
            ),
            const SizedBox(height: NeoTheme.spaceLg),

            Text(Strings.xpLast7Days, style: NeoTheme.subhead),
            const SizedBox(height: NeoTheme.spaceSm),
            Container(
              decoration: NeoTheme.cardDecoration(isDark: isDark),
              padding: const EdgeInsets.fromLTRB(
                  NeoTheme.spaceSm, NeoTheme.spaceMd, NeoTheme.spaceSm, NeoTheme.spaceSm),
              child: SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (xpPerDay.values.isEmpty
                              ? 10
                              : xpPerDay.values
                                  .reduce((a, b) => a > b ? a : b))
                          .toDouble() *
                      1.2 +
                      10,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final keys = xpPerDay.keys.toList();
                          if (value.toInt() < keys.length) {
                            final date = parseDate(keys[value.toInt()]);
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                DateFormat('E', 'cs').format(date),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups:
                      xpPerDay.entries.toList().asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value.toDouble(),
                          color: context.primaryColor,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              ),
            ),
            const SizedBox(height: NeoTheme.spaceLg),

            Text(Strings.taskTypeRatio, style: NeoTheme.subhead),
            const SizedBox(height: NeoTheme.spaceSm),
            if (total > 0)
              Container(
                decoration: NeoTheme.cardDecoration(isDark: isDark),
                padding: const EdgeInsets.all(NeoTheme.spaceMd),
                child: SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: [
                      if (dailyCount > 0)
                        PieChartSectionData(
                          value: dailyCount.toDouble(),
                          title: '${Strings.typeDaily}\n$dailyCount',
                          color: AppColors.taskDaily,
                          radius: 60,
                          titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      if (weeklyCount > 0)
                        PieChartSectionData(
                          value: weeklyCount.toDouble(),
                          title: '${Strings.typeWeekly}\n$weeklyCount',
                          color: AppColors.taskWeekly,
                          radius: 60,
                          titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      if (monthlyCount > 0)
                        PieChartSectionData(
                          value: monthlyCount.toDouble(),
                          title: '${Strings.typeMonthly}\n$monthlyCount',
                          color: AppColors.taskMonthly,
                          radius: 60,
                          titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                    ],
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                  ),
                ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(NeoTheme.spaceLg),
                child: Center(
                  child: Text(Strings.noStatsData,
                      style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondary
                              : Colors.black38)),
                ),
              ),
          ],
        ),
          ),
        ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Expanded(
      child: Container(
        decoration: NeoTheme.cardDecoration(isDark: isDark),
        padding: const EdgeInsets.all(NeoTheme.spaceMd),
        child: Column(
          children: [
            Text(value,
                style: NeoTheme.display.copyWith(
                  fontSize: 28,
                  color: color,
                )),
            const SizedBox(height: NeoTheme.spaceXs),
            Text(label,
                style: NeoTheme.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}
