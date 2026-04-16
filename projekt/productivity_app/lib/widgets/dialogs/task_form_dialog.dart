import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../constants/app_colors.dart';
import '../../constants/neo_theme.dart';
import '../../constants/strings.dart';
import '../../utils/context_extensions.dart';

class TaskFormDialog extends StatefulWidget {
  final Task? existingTask;
  final void Function(String title, TaskType type) onSubmit;

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
      content: Column(
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
                  color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
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
                  color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
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
        ],
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
                Navigator.pop(context);
                widget.onSubmit(title, _selectedType);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
