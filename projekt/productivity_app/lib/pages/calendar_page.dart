// pages/calendar_page.dart
// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../constants/task_categories.dart';
import '../widgets/task_card.dart';
import '../widgets/xp_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/dialogs/task_form_dialog.dart';
import '../services/task_service.dart';
import '../services/habit_service.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../utils/context_extensions.dart';
import '../utils/date_helpers.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/stats_sidebar.dart';
import '../widgets/neo_bottom_sheet.dart';
import '../widgets/neo_bottom_nav.dart';
import '../widgets/neo_pressable.dart';
import '../widgets/neo_skeleton.dart';
import '../widgets/onboarding_tour.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _auth = FirebaseAuth.instance;
  final _taskService = TaskService();
  final _habitService = HabitService();

  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  /// Map from date string (yyyy-MM-dd) to list of task types for that day.
  Map<String, List<TaskType>> _tasksByDate = {};
  StreamSubscription<List<Task>>? _tasksSubscription;

  // Filter state — null type means "all types"; empty categories set means "all".
  TaskType? _filterType;
  final Set<String> _filterCategories = {};

  int get _activeFilterCount =>
      (_filterType != null ? 1 : 0) + _filterCategories.length;

  @override
  void initState() {
    super.initState();
    _taskService.checkAndResetStreak();
    _taskService.checkExpiringTasks();
    _habitService.extendWindows();
    _tasksSubscription = _taskService.allTasksStream().listen((tasks) {
      final map = <String, List<TaskType>>{};
      for (final t in tasks) {
        map.putIfAbsent(t.date, () => []).add(t.type);
      }
      if (mounted) setState(() => _tasksByDate = map);
    });
    _maybeShowOnboarding();
  }

  /// On the very first launch, open the guided tour once. It doubles as a
  /// welcome for new users and a talking-point cheat sheet during demos.
  Future<void> _maybeShowOnboarding() async {
    if (await onboardingSeen()) return;
    await markOnboardingSeen();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showOnboardingTour(context);
    });
  }

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    super.dispose();
  }

  List<Widget> _buildActions(BuildContext context, int streak) {
    final streakWidget = streak > 0
        ? Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    color: Colors.white, size: 18),
                const SizedBox(width: 2),
                Text('$streak',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ],
            ),
          )
        : null;

    return [
      if (streakWidget != null) streakWidget,
      IconButton(
        icon: const Icon(Icons.task_alt_rounded),
        tooltip: Strings.confirmCode,
        onPressed: () => Navigator.pushNamed(context, '/confirm'),
      ),
      IconButton(
        icon: const Icon(Icons.logout_rounded),
        tooltip: Strings.logout,
        onPressed: () async {
          await _auth.signOut();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/');
        },
      ),
    ];
  }

  bool _isDayInPast(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final checkDay = DateTime(day.year, day.month, day.day);
    return checkDay.isBefore(today);
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => TaskFormDialog(
        onSubmit: (title, type, cfg, categories) async {
          if (cfg != null) {
            await _habitService.createHabit(
              title: title,
              type: type,
              recurrence: cfg.recurrence,
              customDays: cfg.customDays,
              categories: categories,
            );
          } else {
            _taskService.createTask(
              title: title,
              type: type,
              date: formatDate(DateTime(
                  _selectedDay.year, _selectedDay.month, _selectedDay.day)),
              categories: categories,
            );
          }
        },
      ),
    );
  }

  void _showEditTaskDialog(Task task) {
    showDialog(
      context: context,
      builder: (context) => TaskFormDialog(
        existingTask: task,
        onSubmit: (title, type, cfg, categories) async {
          if (task.habitId != null) {
            final choice = await _askHabitEditChoice();
            if (choice == null) return;
            if (choice == 'whole') {
              await _habitService.updateHabitAndRegenerate(
                habitId: task.habitId!,
                title: title,
                type: type,
                categories: categories,
              );
            } else {
              _taskService.updateTask(task.id,
                  title: title, type: type, categories: categories);
            }
          } else {
            _taskService.updateTask(task.id,
                title: title, type: type, categories: categories);
          }
        },
      ),
    );
  }

  Future<void> _showFilterSheet() async {
    await showNeoBottomSheet<void>(
      context: context,
      children: [
        StatefulBuilder(builder: (context, setSheetState) {
          final isDark = context.isDark;
          void setBoth(VoidCallback fn) {
            setSheetState(fn);
            setState(fn);
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(
              NeoTheme.spaceMd,
              NeoTheme.spaceSm,
              NeoTheme.spaceMd,
              NeoTheme.spaceLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(Strings.filterByType, style: NeoTheme.caption),
                const SizedBox(height: NeoTheme.spaceSm),
                Wrap(
                  spacing: 6,
                  children: [
                    _typeFilterChip(null, Strings.filterAll, setBoth, isDark),
                    _typeFilterChip(
                        TaskType.daily, Strings.typeDaily, setBoth, isDark),
                    _typeFilterChip(
                        TaskType.weekly, Strings.typeWeekly, setBoth, isDark),
                    _typeFilterChip(
                        TaskType.monthly, Strings.typeMonthly, setBoth, isDark),
                  ],
                ),
                const SizedBox(height: NeoTheme.spaceMd),
                Text(Strings.filterByCategory, style: NeoTheme.caption),
                const SizedBox(height: NeoTheme.spaceSm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: Categories.all.map((cat) {
                    final selected = _filterCategories.contains(cat.key);
                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat.icon, size: 14, color: cat.color),
                          const SizedBox(width: 5),
                          Text(cat.label),
                        ],
                      ),
                      selected: selected,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      selectedColor: cat.color.withValues(alpha: 0.18),
                      side: BorderSide(
                        color: selected
                            ? cat.color
                            : (isDark
                                ? AppColors.borderSubtle
                                : AppColors.borderBold),
                        width: NeoTheme.borderWidthThin,
                      ),
                      onSelected: (sel) => setBoth(() {
                        if (sel) {
                          _filterCategories.add(cat.key);
                        } else {
                          _filterCategories.remove(cat.key);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: NeoTheme.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _activeFilterCount == 0
                            ? null
                            : () => setBoth(() {
                                  _filterType = null;
                                  _filterCategories.clear();
                                }),
                        child: const Text('Vymazat'),
                      ),
                    ),
                    const SizedBox(width: NeoTheme.spaceSm),
                    Expanded(
                      child: NeoPressable(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          decoration: NeoTheme.buttonDecoration(
                            backgroundColor: context.primaryColor,
                            borderColor: Colors.white,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text('Hotovo',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _typeFilterChip(
    TaskType? value,
    String label,
    void Function(VoidCallback) setBoth,
    bool isDark,
  ) {
    final selected = _filterType == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      selectedColor: context.primaryColor.withValues(alpha: 0.2),
      side: BorderSide(
        color: selected
            ? context.primaryColor
            : (isDark ? AppColors.borderSubtle : AppColors.borderBold),
        width: NeoTheme.borderWidthThin,
      ),
      onSelected: (_) => setBoth(() => _filterType = value),
    );
  }

  Future<String?> _askHabitEditChoice() async {
    return showNeoBottomSheet<String>(
      context: context,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(Strings.editHabitOrInstance,
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        ListTile(
          leading: const Icon(Icons.assignment_rounded),
          title: const Text(Strings.thisOnly),
          onTap: () => Navigator.pop(context, 'instance'),
        ),
        ListTile(
          leading: const Icon(Icons.autorenew_rounded),
          title: const Text(Strings.wholeHabit),
          onTap: () => Navigator.pop(context, 'whole'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return StreamBuilder<DocumentSnapshot>(
      stream: _taskService.userProfileStream(),
      builder: (context, snapshot) {
        int xp = 0, coins = 0, level = 1, streak = 0;
        String nickname = 'Hráč';
        String? photoUrl;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          xp = data['xp'] ?? 0;
          coins = data['coins'] ?? 0;
          level = data['level'] ?? 1;
          streak = data['streak'] ?? 0;
          nickname = data['nickname'] ?? 'Hráč';
          photoUrl = data['photoUrl'];
        }

        return Scaffold(
          appBar: AppBar(
            title: Semantics(
              button: true,
              label: Strings.openProfileSemantic,
              child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/profile'),
              borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
              child: Row(
                children: [
                  if (photoUrl != null && photoUrl.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.primaryColor,
                          width: NeoTheme.borderWidth,
                        ),
                      ),
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(photoUrl),
                        radius: 18,
                        backgroundColor: Colors.transparent,
                      ),
                    )
                  else
                    CircleAvatar(
                      backgroundColor: context.primaryColor,
                      radius: 18,
                      child: Text(
                        nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 16),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nickname,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            ),
            actions: _buildActions(context, streak),
          ),
          body: ResponsiveLayout(
            sidebar: const StatsSidebar(),
            child: Column(
            children: [
              // Stats bar: XP + Coins
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.all(14),
                decoration: NeoTheme.cardDecoration(isDark: isDark),
                child: Row(
                  children: [
                    Expanded(child: XPBar(xp: xp % 100, level: level)),
                    const SizedBox(width: 16),
                    // Coins box with neon yellow border
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(NeoTheme.radiusButton),
                        color: Colors.transparent,
                        border: Border.all(
                          color: AppColors.neonYellow,
                          width: NeoTheme.borderWidthThin,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on_rounded,
                              color: AppColors.neonYellow, size: 22),
                          const SizedBox(width: 6),
                          Text(
                            '$coins',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neonYellow,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Calendar
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                decoration: NeoTheme.cardDecoration(isDark: isDark),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
                  child: TableCalendar(
                    locale: 'cs',
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    firstDay: DateTime(2000),
                    lastDay: DateTime(2100),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) =>
                        isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    eventLoader: (day) {
                      final key = formatDate(day);
                      return _tasksByDate[key] ?? [];
                    },
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) {
                        if (events.isEmpty) return null;
                        final types = events.cast<TaskType>();
                        final seen = <TaskType>{};
                        final unique = <TaskType>[];
                        for (final t in types) {
                          if (seen.add(t)) unique.add(t);
                        }
                        return Positioned(
                          bottom: 2,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: unique.map((type) {
                              return Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: AppColors.colorForTaskType(type),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                    calendarFormat: CalendarFormat.month,
                    rowHeight: 42,
                    daysOfWeekHeight: 32,
                    calendarStyle: CalendarStyle(
                      cellMargin: const EdgeInsets.all(3),
                      defaultTextStyle: TextStyle(
                        color: isDark ? AppColors.textPrimary : Colors.black87,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      weekendTextStyle: TextStyle(
                        color: isDark
                            ? AppColors.weekendDark
                            : AppColors.weekendLight,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      outsideTextStyle: TextStyle(
                        color: isDark ? Colors.white24 : Colors.black26,
                        fontSize: 14,
                      ),
                      todayDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.primaryColor,
                          width: NeoTheme.borderWidth,
                        ),
                      ),
                      todayTextStyle: TextStyle(
                        color: isDark ? AppColors.textPrimary : context.primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      selectedDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.primaryColor,
                        border: Border.all(
                          color: Colors.white,
                          width: NeoTheme.borderWidthThin,
                        ),
                      ),
                      selectedTextStyle: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: TextStyle(
                        color: isDark ? AppColors.textSecondary : Colors.black38,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      weekendStyle: TextStyle(
                        color: isDark
                            ? AppColors.weekendDark.withValues(alpha: 0.5)
                            : AppColors.weekendLight.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    headerStyle: HeaderStyle(
                      titleTextStyle: TextStyle(
                        color: isDark ? AppColors.textPrimary : Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      formatButtonVisible: false,
                      titleCentered: true,
                      headerPadding: const EdgeInsets.symmetric(vertical: 8),
                      leftChevronIcon: Icon(
                        Icons.chevron_left_rounded,
                        color: isDark ? AppColors.textSecondary : Colors.black45,
                        size: 28,
                      ),
                      rightChevronIcon: Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? AppColors.textSecondary : Colors.black45,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              // Date label + filter button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: context.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isToday(_selectedDay)
                          ? Strings.today
                          : DateFormat('d. M. yyyy').format(_selectedDay),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textSecondary : Colors.black54,
                      ),
                    ),
                    const Spacer(),
                    NeoPressable(
                      onTap: _showFilterSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(NeoTheme.radiusButton),
                          color: _activeFilterCount > 0
                              ? context.primaryColor.withValues(alpha: 0.15)
                              : Colors.transparent,
                          border: Border.all(
                            color: _activeFilterCount > 0
                                ? context.primaryColor
                                : (isDark
                                    ? AppColors.borderSubtle
                                    : AppColors.borderBold),
                            width: NeoTheme.borderWidthThin,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.filter_list_rounded,
                              size: 16,
                              color: _activeFilterCount > 0
                                  ? context.primaryColor
                                  : (isDark
                                      ? AppColors.textPrimary
                                      : Colors.black87),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Filtr',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: _activeFilterCount > 0
                                    ? context.primaryColor
                                    : (isDark
                                        ? AppColors.textPrimary
                                        : Colors.black87),
                              ),
                            ),
                            if (_activeFilterCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: context.primaryColor,
                                  borderRadius: BorderRadius.circular(
                                      NeoTheme.radiusSmall),
                                ),
                                child: Text(
                                  '$_activeFilterCount',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
              // Tasks list
              Expanded(
                child: StreamBuilder<List<Task>>(
                  stream:
                      _taskService.tasksForDate(formatDate(_selectedDay)),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const NeoSkeletonList(count: 3, itemHeight: 110);
                    }
                    final allTasks = snapshot.data!;
                    final tasks = allTasks.where((t) {
                      if (_filterType != null && t.type != _filterType) {
                        return false;
                      }
                      if (_filterCategories.isNotEmpty &&
                          !t.categories
                              .any(_filterCategories.contains)) {
                        return false;
                      }
                      return true;
                    }).toList();

                    if (allTasks.isEmpty) {
                      return const EmptyState(
                        icon: Icons.assignment_outlined,
                        title: Strings.noTasksTitle,
                        subtitle: Strings.noTasksSubtitle,
                      );
                    }
                    if (tasks.isEmpty) {
                      return const EmptyState(
                        icon: Icons.filter_list_off_rounded,
                        title: 'Filtr nic nepustí.',
                        subtitle: 'Zkus jiné kategorie nebo typ.',
                      );
                    }

                    return ListView.builder(
                      // itemCount + 1: last "item" is a SizedBox spacer that
                      // pushes the last real task above the FAB. Padding
                      // alone doesn't work when content fits the viewport —
                      // an actual child reserves layout space.
                      itemCount: tasks.length + 1,
                      itemBuilder: (context, index) {
                        if (index == tasks.length) {
                          return const SizedBox(height: 96);
                        }
                        return TaskCard(
                          task: tasks[index],
                          onDelete: () =>
                              _taskService.deleteTask(tasks[index].id),
                          onEdit: () => _showEditTaskDialog(tasks[index]),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          ),
          floatingActionButton: _isDayInPast(_selectedDay)
              ? null
              : NeoPressable(
                  onTap: _showAddTaskDialog,
                  pressOffset: NeoTheme.shadowOffset,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: context.primaryColor,
                      borderRadius:
                          BorderRadius.circular(NeoTheme.radiusButton),
                      border: Border.all(
                        color: Colors.white,
                        width: NeoTheme.borderWidth,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          offset: NeoTheme.shadowOffset,
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.black, size: 30),
                  ),
                ),
          bottomNavigationBar: const NeoBottomNav(currentIndex: 0),
        );
      },
    );
  }
}
