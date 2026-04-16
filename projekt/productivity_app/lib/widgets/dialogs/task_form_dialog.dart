import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../models/habit.dart';
import '../../constants/app_colors.dart';
import '../../constants/neo_theme.dart';
import '../../constants/strings.dart';
import '../../utils/context_extensions.dart';

class HabitConfig {
  final RecurrenceType recurrence;
  final List<int> customDays;
  const HabitConfig({required this.recurrence, this.customDays = const []});
}

class TaskFormDialog extends StatefulWidget {
  final Task? existingTask;
  final void Function(String title, TaskType type, HabitConfig? habitConfig)
      onSubmit;

  const TaskFormDialog({
    super.key,
    this.existingTask,
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

  bool get _isEdit => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existingTask?.title ?? '');
    _selectedType = widget.existingTask?.type ?? TaskType.daily;
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
        _isEdit ? Strings.editTask : Strings.newTask,
        style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText:
                    _isEdit ? Strings.taskTitleLabel : Strings.taskTitleHint,
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
                labelText: Strings.taskTypeLabel,
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
              items: TaskType.values.map((TaskType type) {
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
              onChanged: (val) => setState(() => _selectedType = val!),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _recurring,
              onChanged: (v) => setState(() {
                _recurring = v;
                if (v &&
                    _selectedType == TaskType.monthly &&
                    _recurrence != RecurrenceType.custom) {
                  _selectedType = TaskType.daily;
                }
              }),
              title: const Text(Strings.repeatTask),
              contentPadding: EdgeInsets.zero,
            ),
            if (_recurring) ...[
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
                              if (sel) {
                                _customDays.add(d);
                              } else {
                                _customDays.remove(d);
                              }
                            }),
                          ))
                      .toList(),
                ),
              ],
              if (_recurrence == RecurrenceType.everyday &&
                  _selectedType == TaskType.monthly) ...[
                const SizedBox(height: 8),
                const Text(Strings.rewardTierWarning,
                    style:
                        TextStyle(color: AppColors.neonPink, fontSize: 12)),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(Strings.cancel),
        ),
        Container(
          decoration: NeoTheme.buttonDecoration(
            backgroundColor: AppColors.neonGreen,
            borderColor: Colors.white,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
              onTap: () {
                final title = _titleController.text.trim();
                if (title.isEmpty) return;
                if (_recurring &&
                    _recurrence == RecurrenceType.custom &&
                    _customDays.isEmpty) {
                  return; // custom needs at least one day
                }
                Navigator.pop(context);
                HabitConfig? cfg;
                if (_recurring) {
                  cfg = HabitConfig(
                    recurrence: _recurrence,
                    customDays: _customDays.toList()..sort(),
                  );
                }
                widget.onSubmit(title, _selectedType, cfg);
              },
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
        ),
      ],
    );
  }
}
