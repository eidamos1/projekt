import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/achievement.dart';
import '../models/task.dart';
import '../services/achievement_service.dart';
import '../services/task_service.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../constants/task_categories.dart';
import '../utils/context_extensions.dart';
import '../utils/date_helpers.dart';
import '../utils/stats_helpers.dart';
import '../widgets/achievement_grid.dart';
import '../widgets/dialogs/achievement_detail_sheet.dart';
import '../widgets/dialogs/day_detail_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/neo_bottom_nav.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/year_heatmap.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final _taskService = TaskService();
  List<Task> _allTasks = [];
  Map<String, String> _unlockedAtMap = {};
  bool _isLoading = true;
  int _userStreak = 0;

  /// When set, the matching AchievementCard pulses a colored ring for ~3s.
  /// Populated from route arguments on first frame (notif tap / toast tap).
  String? _highlightId;

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Lazy eval: catch up any achievements that haven't been written yet
    // (offline sync, missed trigger). Fire-and-forget.
    AchievementService().evaluate().catchError((_) => <Achievement>[]);
    // ModalRoute.of() needs context up the tree — wait for first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['highlightId'] is String) {
        setState(() => _highlightId = args['highlightId'] as String);
        // Auto-clear after a brief pulse window so reload doesn't keep
        // highlighting indefinitely.
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _highlightId = null);
        });
      }
    });
  }

  Future<void> _loadStats() async {
    try {
      final tasks = await _taskService.allTasks();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final unlockedAtMap = await _loadUnlockedAchievements(uid);
      int streak = 0;
      if (uid != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          if (userDoc.exists) {
            final data = userDoc.data() ?? {};
            streak = (data['streak'] ?? 0) as int;
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _allTasks = tasks;
          _unlockedAtMap = unlockedAtMap;
          _userStreak = streak;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<String, String>> _loadUnlockedAchievements(String? uid) async {
    if (uid == null) return {};
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('achievements')
          .get();
      return {
        for (final d in snap.docs)
          d.id: (d.data()['unlockedAt'] as String?) ?? '',
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text(Strings.stats)),
        body: const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: const NeoBottomNav(currentIndex: 2),
      );
    }

    if (_allTasks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text(Strings.stats)),
        body: const EmptyState(
          icon: Icons.bar_chart_rounded,
          title: Strings.noStatsData,
        ),
        bottomNavigationBar: const NeoBottomNav(currentIndex: 2),
      );
    }

    final completed = _allTasks.where((t) => t.completed).toList();
    final total = _allTasks.length;
    final completedCount = completed.length;

    // Category counts — a task with multiple categories contributes to each.
    // Tasks with no category fall into the "Bez kategorie" bucket.
    final categoryCounts = <String, int>{};
    int uncategorizedCount = 0;
    for (final t in _allTasks) {
      if (t.categories.isEmpty) {
        uncategorizedCount++;
      } else {
        for (final key in t.categories) {
          categoryCounts[key] = (categoryCounts[key] ?? 0) + 1;
        }
      }
    }

    final dayCount = <int, int>{};
    for (final t in completed) {
      try {
        final d = parseDate(t.date);
        dayCount[d.weekday] = (dayCount[d.weekday] ?? 0) + 1;
      } catch (_) {}
    }
    String? bestDay;
    if (dayCount.isNotEmpty) {
      final best =
          dayCount.entries.reduce((a, b) => a.value > b.value ? a : b);
      bestDay = Strings.dayNames[best.key];
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
              if (_userStreak > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: NeoTheme.spaceMd,
                      vertical: NeoTheme.spaceSm),
                  decoration: BoxDecoration(
                    color: AppColors.neonPink.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
                    border: Border.all(
                      color: AppColors.neonPink,
                      width: NeoTheme.borderWidthThin,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: AppColors.neonPink, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        Strings.streakLine(_userStreak),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.neonPink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: NeoTheme.spaceMd),
              ],
              // Heatmap section
              const Text(Strings.lastYearHeader, style: NeoTheme.subhead),
              const SizedBox(height: NeoTheme.spaceSm),
              YearHeatmap(
                tasksPerDay: tasksPerDay(_allTasks),
                firstTaskDate: () {
                  final dates = _allTasks
                      .map((t) => t.date)
                      .where((d) => d.isNotEmpty);
                  return dates.isEmpty
                      ? null
                      : dates.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
                }(),
                onCellTap: (date) {
                  final dateStr =
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  final dayTasks = _allTasks
                      .where((t) => t.completed && t.date == dateStr)
                      .toList();
                  showDayDetailSheet(context, date, dayTasks);
                },
              ),
              const SizedBox(height: NeoTheme.spaceSm),
              Text(
                Strings.summaryLine(completedCount, total, bestDay),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textSecondary : Colors.black54,
                ),
              ),
              const SizedBox(height: NeoTheme.spaceLg),

              // Achievement grid (existing, unchanged)
              AchievementGrid(
                unlockedAtMap: _unlockedAtMap,
                totalCompletedTasks: completedCount,
                highlightId: _highlightId,
                onTapCard: (ach) {
                  final unlockedAt = _unlockedAtMap[ach.id];
                  showAchievementDetailSheet(context, ach, unlockedAt);
                },
              ),

              // Pomer kategorii pie (existing pie chart logic, unchanged styling)
              if (categoryCounts.isNotEmpty || uncategorizedCount > 0) ...[
                const SizedBox(height: NeoTheme.spaceLg),
                const Text(Strings.categoryRatio, style: NeoTheme.subhead),
                const SizedBox(height: NeoTheme.spaceSm),
                Container(
                  decoration: NeoTheme.cardDecoration(isDark: isDark),
                  padding: const EdgeInsets.all(NeoTheme.spaceMd),
                  child: SizedBox(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          ...categoryCounts.entries.map((e) {
                            final cat = Categories.byKey(e.key);
                            if (cat == null) return null;
                            return PieChartSectionData(
                              value: e.value.toDouble(),
                              title: '${cat.label}\n${e.value}',
                              color: cat.color,
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).whereType<PieChartSectionData>(),
                          if (uncategorizedCount > 0)
                            PieChartSectionData(
                              value: uncategorizedCount.toDouble(),
                              title: 'Bez kat.\n$uncategorizedCount',
                              color: const Color(0xFF8888AA),
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NeoBottomNav(currentIndex: 2),
    );
  }
}
