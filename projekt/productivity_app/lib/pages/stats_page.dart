import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/task_service.dart';

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
        appBar: AppBar(title: const Text('Statistiky')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final completed = _allTasks.where((t) => t.completed).toList();
    final total = _allTasks.length;
    final completedCount = completed.length;

    // Ukoly tento tyden
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisWeekCompleted = completed.where((t) {
      try {
        final d = DateFormat('yyyy-MM-dd').parse(t.date);
        return d.isAfter(weekStart.subtract(const Duration(days: 1)));
      } catch (_) {
        return false;
      }
    }).length;

    // Ukoly tento mesic
    final thisMonthCompleted = completed.where((t) {
      try {
        final d = DateFormat('yyyy-MM-dd').parse(t.date);
        return d.month == now.month && d.year == now.year;
      } catch (_) {
        return false;
      }
    }).length;

    // Pomer typu
    final dailyCount =
        _allTasks.where((t) => t.type == TaskType.daily).length;
    final weeklyCount =
        _allTasks.where((t) => t.type == TaskType.weekly).length;
    final monthlyCount =
        _allTasks.where((t) => t.type == TaskType.monthly).length;

    // Nejproduktivnejsi den
    final dayCount = <int, int>{};
    for (final t in completed) {
      try {
        final d = DateFormat('yyyy-MM-dd').parse(t.date);
        dayCount[d.weekday] = (dayCount[d.weekday] ?? 0) + 1;
      } catch (_) {}
    }
    String bestDay = '-';
    if (dayCount.isNotEmpty) {
      final best =
          dayCount.entries.reduce((a, b) => a.value > b.value ? a : b);
      const dayNames = {
        1: 'Pondeli',
        2: 'Utery',
        3: 'Streda',
        4: 'Ctvrtek',
        5: 'Patek',
        6: 'Sobota',
        7: 'Nedele'
      };
      bestDay = dayNames[best.key] ?? '-';
    }

    // XP za poslednich 7 dni
    final xpPerDay = <String, int>{};
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(day);
      xpPerDay[key] = 0;
    }
    for (final t in completed) {
      if (xpPerDay.containsKey(t.date)) {
        xpPerDay[t.date] = xpPerDay[t.date]! + t.xp;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiky')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prehledove karty
            Row(
              children: [
                _StatCard(
                    label: 'Celkem ukolu', value: '$total', color: Colors.indigo),
                const SizedBox(width: 8),
                _StatCard(
                    label: 'Splneno',
                    value: '$completedCount',
                    color: Colors.green),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatCard(
                    label: 'Tento tyden',
                    value: '$thisWeekCompleted',
                    color: Colors.blue),
                const SizedBox(width: 8),
                _StatCard(
                    label: 'Tento mesic',
                    value: '$thisMonthCompleted',
                    color: Colors.orange),
              ],
            ),
            const SizedBox(height: 16),

            // Nejproduktivnejsi den
            Card(
              child: ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text('Nejproduktivnejsi den'),
                trailing: Text(bestDay,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),

            // XP graf za 7 dni
            const Text('XP za poslednich 7 dni',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (xpPerDay.values.isEmpty
                          ? 10
                          : xpPerDay.values
                              .reduce((a, b) => a > b ? a : b))
                      .toDouble() *
                      1.2 + 10,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final keys = xpPerDay.keys.toList();
                          if (value.toInt() < keys.length) {
                            final date = DateFormat('yyyy-MM-dd')
                                .parse(keys[value.toInt()]);
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
                  barGroups: xpPerDay.entries.toList().asMap().entries.map(
                    (entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.value.toDouble(),
                            color: Colors.indigo,
                            width: 20,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ],
                      );
                    },
                  ).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Pomer typu
            const Text('Pomer typu ukolu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (total > 0)
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: [
                      if (dailyCount > 0)
                        PieChartSectionData(
                          value: dailyCount.toDouble(),
                          title: 'Denni\n$dailyCount',
                          color: Colors.blueAccent,
                          radius: 60,
                          titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      if (weeklyCount > 0)
                        PieChartSectionData(
                          value: weeklyCount.toDouble(),
                          title: 'Tydenni\n$weeklyCount',
                          color: Colors.orangeAccent,
                          radius: 60,
                          titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      if (monthlyCount > 0)
                        PieChartSectionData(
                          value: monthlyCount.toDouble(),
                          title: 'Mesicni\n$monthlyCount',
                          color: Colors.purpleAccent,
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
              )
            else
              const Center(
                child: Text('Zadna data k zobrazeni',
                    style: TextStyle(color: Colors.grey)),
              ),
          ],
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
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
