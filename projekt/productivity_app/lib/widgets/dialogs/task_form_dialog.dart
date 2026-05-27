import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../models/habit.dart';
import '../../constants/app_colors.dart';
import '../../constants/neo_theme.dart';
import '../../constants/strings.dart';
import '../../constants/task_categories.dart';
import '../../utils/context_extensions.dart';
import '../neo_pressable.dart';

class HabitConfig {
  final RecurrenceType recurrence;
  final List<int> customDays;
  const HabitConfig({required this.recurrence, this.customDays = const []});
}

class TaskFormDialog extends StatefulWidget {
  final Task? existingTask;
  final Habit? existingHabit;
  final bool initialAsHabit;
  final void Function(
    String title,
    TaskType type,
    HabitConfig? habitConfig,
    List<String> categories,
  ) onSubmit;

  const TaskFormDialog({
    super.key,
    this.existingTask,
    this.existingHabit,
    this.initialAsHabit = false,
    required this.onSubmit,
  });

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  late final TextEditingController _titleController;
  late TaskType _selectedType;

  bool _recurring = false;
  RecurrenceType _recurrence = RecurrenceType.everyday;
  final Set<int> _customDays = {};
  final Set<String> _selectedCategories = {};

  bool get _isEdit =>
      widget.existingTask != null || widget.existingHabit != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
        text: widget.existingTask?.title ?? widget.existingHabit?.title ?? '');
    _selectedType = widget.existingTask?.type ??
        widget.existingHabit?.type ??
        TaskType.daily;
    if (widget.existingHabit != null) {
      _recurring = true;
      _recurrence = widget.existingHabit!.recurrence;
      _customDays.addAll(widget.existingHabit!.customDays);
      _selectedCategories.addAll(widget.existingHabit!.categories);
    } else if (widget.existingTask != null) {
      _selectedCategories.addAll(widget.existingTask!.categories);
    } else if (widget.initialAsHabit) {
      _recurring = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
        side: BorderSide(
          color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
          width: NeoTheme.borderWidth,
        ),
      ),
      title: Text(
        widget.existingHabit != null
            ? Strings.editHabit
            : (_isEdit
                ? Strings.editTask
                : (widget.initialAsHabit
                    ? Strings.newHabit
                    : Strings.newTask)),
        style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: widget.existingHabit != null
                    ? Strings.habitTitleLabel
                    : (_isEdit
                        ? Strings.taskTitleLabel
                        : Strings.taskTitleHint),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(NeoTheme.radiusButton)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
                  borderSide: BorderSide(
                    color:
                        isDark ? AppColors.borderSubtle : AppColors.borderBold,
                    width: NeoTheme.borderWidth,
                  ),
                ),
                prefixIcon: const Icon(Icons.edit_rounded),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TaskType>(
              initialValue: _selectedType,
              decoration: InputDecoration(
                labelText: widget.existingHabit != null
                    ? Strings.habitTypeLabel
                    : Strings.taskTypeLabel,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(NeoTheme.radiusButton)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
                  borderSide: BorderSide(
                    color:
                        isDark ? AppColors.borderSubtle : AppColors.borderBold,
                    width: NeoTheme.borderWidth,
                  ),
                ),
              ),
              items: TaskType.values
                  // Monthly is excluded when the form is in habit mode —
                  // a recurring "Monthly" habit blew up the XP economy
                  // (200 XP/instance × 7-30 instances/month).
                  .where((t) => !(_recurring && t == TaskType.monthly))
                  .map((TaskType type) {
                String label;
                switch (type) {
                  case TaskType.daily:
                    label = Strings.typeDaily;
                  case TaskType.weekly:
                    label = Strings.typeWeekly;
                  case TaskType.monthly:
                    label = Strings.typeMonthly;
                }
                return DropdownMenuItem(value: type, child: Text(label));
              }).toList(),
              onChanged: (val) => setState(() {
                _selectedType = val!;
                // Weekly habit = exactly one weekday per week. Force the
                // recurrence to custom + pick today's weekday by default.
                if (_recurring && _selectedType == TaskType.weekly) {
                  _recurrence = RecurrenceType.custom;
                  if (_customDays.length != 1) {
                    _customDays
                      ..clear()
                      ..add(DateTime.now().weekday);
                  }
                }
              }),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _recurring,
              onChanged: widget.existingHabit != null
                  ? null
                  : (v) => setState(() {
                        _recurring = v;
                        if (v && _selectedType == TaskType.monthly) {
                          _selectedType = TaskType.daily;
                        }
                        if (v && _selectedType == TaskType.weekly) {
                          _recurrence = RecurrenceType.custom;
                          if (_customDays.length != 1) {
                            _customDays
                              ..clear()
                              ..add(DateTime.now().weekday);
                          }
                        }
                      }),
              title: const Text(Strings.repeatTask),
              contentPadding: EdgeInsets.zero,
            ),
            if (_recurring) ...[
              // Weekly habits are always "custom 1 day" — hide the
              // recurrence segment, only show the day-of-week picker.
              if (_selectedType != TaskType.weekly)
                SegmentedButton<RecurrenceType>(
                  segments: const [
                    ButtonSegment(
                        value: RecurrenceType.everyday,
                        label: Text(Strings.recurrenceEveryday)),
                    ButtonSegment(
                        value: RecurrenceType.weekdays,
                        label: Text(Strings.recurrenceWeekdays)),
                    ButtonSegment(
                        value: RecurrenceType.custom,
                        label: Text(Strings.recurrenceCustom)),
                  ],
                  selected: {_recurrence},
                  onSelectionChanged: (s) => setState(() {
                    _recurrence = s.first;
                    if (_recurrence == RecurrenceType.custom &&
                        _customDays.isEmpty) {
                      _customDays.add(DateTime.now().weekday);
                    }
                  }),
                ),
              if (_recurrence == RecurrenceType.custom) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: [1, 2, 3, 4, 5, 6, 7]
                      .map((d) => FilterChip(
                            label: Text(Strings.weekdayShort[d]!),
                            selected: _customDays.contains(d),
                            onSelected: (sel) => setState(() {
                              // Weekly = exactly 1 day; new selection
                              // replaces the previous.
                              if (_selectedType == TaskType.weekly) {
                                if (sel) {
                                  _customDays
                                    ..clear()
                                    ..add(d);
                                }
                                return;
                              }
                              if (sel) {
                                _customDays.add(d);
                              } else {
                                _customDays.remove(d);
                              }
                            }),
                          ))
                      .toList(),
                ),
                if (_selectedType == TaskType.weekly) ...[
                  const SizedBox(height: 6),
                  Text(
                    Strings.weeklyHabitDayHint,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textSecondary
                          : Colors.black54,
                    ),
                  ),
                ],
              ],
            ],
            const SizedBox(height: NeoTheme.spaceMd),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(Strings.categoriesLabel, style: NeoTheme.caption),
            ),
            const SizedBox(height: NeoTheme.spaceSm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: Categories.all.map((cat) {
                final selected = _selectedCategories.contains(cat.key);
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
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _selectedCategories.add(cat.key);
                    } else {
                      _selectedCategories.remove(cat.key);
                    }
                  }),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(Strings.cancel),
        ),
        NeoPressable(
          onTap: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) return;
            if (_recurring &&
                _recurrence == RecurrenceType.custom &&
                _customDays.isEmpty) {
              return; // custom needs at least one day
            }
            // Weekly habit invariant: exactly 1 chosen weekday.
            if (_recurring &&
                _selectedType == TaskType.weekly &&
                _customDays.length != 1) {
              return;
            }
            Navigator.pop(context);
            HabitConfig? cfg;
            if (_recurring) {
              cfg = HabitConfig(
                recurrence: _recurrence,
                customDays: _customDays.toList()..sort(),
              );
            }
            widget.onSubmit(
              title,
              _selectedType,
              cfg,
              _selectedCategories.toList()..sort(),
            );
          },
          child: Container(
            decoration: NeoTheme.buttonDecoration(
              backgroundColor: context.primaryColor,
              borderColor: Colors.white,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                _isEdit ? Strings.save : Strings.createTask,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
