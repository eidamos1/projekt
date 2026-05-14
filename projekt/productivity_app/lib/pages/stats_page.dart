import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/achievement.dart';
import '../models/friend_rank.dart';
import '../models/task.dart';
import '../services/achievement_service.dart';
import '../services/friend_service.dart';
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final results = await Future.wait([
        _taskService.allTasks(),
        _loadUnlockedAchievements(uid),
        uid == null
            ? Future.value(<String, dynamic>{})
            : FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get()
                .then((d) => d.data() ?? <String, dynamic>{}),
      ]);
      final tasks = results[0] as List<Task>;
      final unlockedAtMap = results[1] as Map<String, String>;
      final userData = results[2] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _allTasks = tasks;
          _unlockedAtMap = unlockedAtMap;
          _userStreak = (userData['streak'] ?? 0) as int;
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
      final isDark = context.isDark;
      return Scaffold(
        appBar: AppBar(title: const Text(Strings.stats)),
        body: ResponsiveLayout(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(NeoTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Leaderboard renders only if user has at least 1 friend.
                // Users with friends but no own tasks shouldn't be cut off
                // from the social view by the empty-stats early return.
                _LeaderboardWidget(isDark: isDark),
                const SizedBox(height: NeoTheme.spaceLg),
                const SizedBox(
                  height: 320,
                  child: EmptyState(
                    icon: Icons.bar_chart_rounded,
                    title: Strings.noStatsData,
                  ),
                ),
              ],
            ),
          ),
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
              _MetricRow(
                completed: completedCount,
                total: total,
                bestDay: bestDay,
                streak: _userStreak,
                isDark: isDark,
              ),
              const SizedBox(height: NeoTheme.spaceLg),
              _LeaderboardWidget(isDark: isDark),
              const SizedBox(height: NeoTheme.spaceLg),
              // Heatmap section
              const Text(Strings.lastYearHeader, style: NeoTheme.subhead),
              const SizedBox(height: NeoTheme.spaceSm),
              SizedBox(
                width: double.infinity,
                child: YearHeatmap(
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

              // Pomer kategorii — chart on left, legend on right (or stacked
              // on narrow viewports). Excludes "Bez kategorie" from the chart
              // itself; shown as a separate footer line so a single dominant
              // gray slice doesn't crowd out the real categories.
              if (categoryCounts.isNotEmpty || uncategorizedCount > 0) ...[
                const SizedBox(height: NeoTheme.spaceLg),
                const Text(Strings.categoryRatio, style: NeoTheme.subhead),
                const SizedBox(height: NeoTheme.spaceSm),
                _CategoryBreakdown(
                  categoryCounts: categoryCounts,
                  uncategorizedCount: uncategorizedCount,
                  isDark: isDark,
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

/// Compact metric strip shown above the heatmap. Streak first when active,
/// then completed / total / best weekday. Wraps on narrow viewports.
class _MetricRow extends StatelessWidget {
  final int completed;
  final int total;
  final String? bestDay;
  final int streak;
  final bool isDark;

  const _MetricRow({
    required this.completed,
    required this.total,
    required this.bestDay,
    required this.streak,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: NeoTheme.spaceSm,
      runSpacing: NeoTheme.spaceSm,
      children: [
        if (streak > 0)
          _MetricCard(
            label: Strings.streakLabel,
            value: '$streak',
            unit: streak == 1
                ? 'den'
                : (streak >= 2 && streak <= 4 ? 'dny' : 'dní'),
            icon: Icons.local_fire_department,
            accent: AppColors.neonPink,
            isDark: isDark,
          ),
        _MetricCard(
          label: Strings.completedTasks,
          value: '$completed',
          unit: total > 0 ? 'z $total' : null,
          icon: Icons.check_circle_outline_rounded,
          accent: primary,
          isDark: isDark,
        ),
        if (bestDay != null)
          _MetricCard(
            label: Strings.bestDay,
            value: bestDay!,
            icon: Icons.event_available_rounded,
            accent: AppColors.neonCyan,
            isDark: isDark,
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color accent;
  final bool isDark;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.isDark,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: NeoTheme.spaceMd, vertical: NeoTheme.spaceSm + 2),
      decoration: NeoTheme.cardDecoration(isDark: isDark).copyWith(
        border: Border.all(color: accent, width: NeoTheme.borderWidthThin),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: NeoTheme.spaceSm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: isDark ? AppColors.textSecondary : Colors.black54,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textSecondary
                            : Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Donut chart of categorized tasks + a side-by-side legend. "Bez kategorie"
/// is shown as a separate footer line, not a chart slice — otherwise it tends
/// to dominate and crowd out the real categories.
class _CategoryBreakdown extends StatelessWidget {
  final Map<String, int> categoryCounts;
  final int uncategorizedCount;
  final bool isDark;

  const _CategoryBreakdown({
    required this.categoryCounts,
    required this.uncategorizedCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final entries = categoryCounts.entries
        .map((e) {
          final cat = Categories.byKey(e.key);
          return cat == null ? null : (cat: cat, count: e.value);
        })
        .whereType<({TaskCategory cat, int count})>()
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final categorizedTotal =
        entries.fold<int>(0, (acc, e) => acc + e.count);

    return Container(
      decoration: NeoTheme.cardDecoration(isDark: isDark),
      padding: const EdgeInsets.all(NeoTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final stacked = constraints.maxWidth < 380;
            final chart = SizedBox(
              width: stacked ? double.infinity : 180,
              height: 180,
              child: entries.isEmpty
                  ? _ChartEmpty(isDark: isDark)
                  : PieChart(
                      PieChartData(
                        sections: entries.map((e) {
                          final pct =
                              (e.count / categorizedTotal * 100).round();
                          return PieChartSectionData(
                            value: e.count.toDouble(),
                            // Show in-slice % only for slices large enough to
                            // fit a label; smaller ones live in the legend.
                            title: pct >= 12 ? '$pct%' : '',
                            color: e.cat.color,
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          );
                        }).toList(),
                        sectionsSpace: 3,
                        centerSpaceRadius: 42,
                        startDegreeOffset: -90,
                      ),
                    ),
            );

            final legend = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: e.cat.color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          e.cat.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${e.count}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textSecondary
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );

            if (entries.isEmpty) {
              return chart;
            }

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: chart),
                  const SizedBox(height: NeoTheme.spaceMd),
                  legend,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                chart,
                const SizedBox(width: NeoTheme.spaceMd),
                Expanded(child: legend),
              ],
            );
          }),
          if (uncategorizedCount > 0) ...[
            const SizedBox(height: NeoTheme.spaceSm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: NeoTheme.spaceSm, vertical: 6),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(NeoTheme.radiusSmall),
              ),
              child: Row(
                children: [
                  Icon(Icons.label_off_outlined,
                      size: 14,
                      color: isDark
                          ? AppColors.textSecondary
                          : Colors.black54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${Strings.uncategorizedLine}: $uncategorizedCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textSecondary
                            : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  final bool isDark;
  const _ChartEmpty({required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        Strings.noCategorizedTasks,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: isDark ? AppColors.textSecondary : Colors.black54,
        ),
      ),
    );
  }
}

class _LeaderboardWidget extends StatelessWidget {
  final bool isDark;
  const _LeaderboardWidget({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendRank>>(
      stream: FriendService().leaderboardStream(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final ranks = snap.data!;
        // Hide if user has no friends (own entry only)
        if (ranks.length <= 1) return const SizedBox.shrink();

        final top = ranks.take(3).toList();
        final more = ranks.length - top.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Strings.leaderboardHeader, style: NeoTheme.subhead),
            const SizedBox(height: NeoTheme.spaceSm),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/profile'),
              child: Container(
                decoration: NeoTheme.cardDecoration(isDark: isDark),
                padding: const EdgeInsets.all(NeoTheme.spaceMd),
                child: Column(
                  children: [
                    for (final r in top)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text(
                                '${r.rank}.',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                r.nickname,
                                style: TextStyle(
                                  fontWeight: r.isMe
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: r.isMe
                                      ? context.primaryColor
                                      : null,
                                ),
                              ),
                            ),
                            Text(
                              '${r.weeklyXp} XP',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    if (more > 0) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '+ $more další',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondary
                                : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
