import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/task_service.dart';
import '../models/task.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../utils/context_extensions.dart';
import 'xp_bar.dart';

class StatsSidebar extends StatefulWidget {
  const StatsSidebar({super.key});

  @override
  State<StatsSidebar> createState() => _StatsSidebarState();
}

class _StatsSidebarState extends State<StatsSidebar> {
  final _taskService = TaskService();
  List<Task>? _allTasks;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final tasks = await _taskService.allTasks();
      if (mounted) setState(() => _allTasks = tasks);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
            width: NeoTheme.borderWidth,
          ),
        ),
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: _taskService.userProfileStream(),
        builder: (context, snapshot) {
          int xp = 0, coins = 0, level = 1, streak = 0;

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            xp = data['xp'] ?? 0;
            coins = data['coins'] ?? 0;
            level = data['level'] ?? 1;
            streak = data['streak'] ?? 0;
          }

          final totalTasks = _allTasks?.length ?? 0;
          final completedTasks = _allTasks?.where((t) => t.completed).length ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Strings.stats,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isDark ? AppColors.textSecondary : Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                // Level & XP
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: NeoTheme.cardDecoration(isDark: isDark),
                  child: XPBar(xp: xp % 100, level: level),
                ),
                const SizedBox(height: 12),
                // Coins
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: NeoTheme.cardDecoration(isDark: isDark),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on_rounded,
                          color: AppColors.neonYellow, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        '$coins',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neonYellow,
                        ),
                      ),
                      const Spacer(),
                      if (streak > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.neonPink,
                            borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
                            border: Border.all(
                              color: Colors.white,
                              width: NeoTheme.borderWidthThin,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonPink.withValues(alpha: 0.3),
                                offset: NeoTheme.shadowOffsetSmall,
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 2),
                              Text('$streak',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Task counts
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: NeoTheme.cardDecoration(isDark: isDark),
                  child: Column(
                    children: [
                      _SidebarStat(
                        label: Strings.totalTasks,
                        value: '$totalTasks',
                        icon: Icons.assignment_outlined,
                        color: context.primaryColor,
                      ),
                      const SizedBox(height: 8),
                      _SidebarStat(
                        label: Strings.completedTasks,
                        value: '$completedTasks',
                        icon: Icons.check_circle_outline,
                        color: AppColors.neonGreen,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SidebarStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SidebarStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
