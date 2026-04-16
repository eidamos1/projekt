import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/image_service.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../utils/context_extensions.dart';
import '../utils/ui_helpers.dart';
import 'status_badge.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  const TaskCard({super.key, required this.task, this.onDelete, this.onEdit});

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  final _taskService = TaskService();
  bool _isProcessing = false;

  IconData _getTypeIcon(TaskType type) {
    switch (type) {
      case TaskType.daily:
        return Icons.today_rounded;
      case TaskType.weekly:
        return Icons.date_range_rounded;
      case TaskType.monthly:
        return Icons.calendar_month_rounded;
    }
  }

  Future<void> _savePhoto() async {
    setState(() => _isProcessing = true);

    try {
      final base64Image = await ImageService.pickAndCompressPhoto();
      await _taskService.savePhoto(widget.task.id, base64Image);

      if (mounted) showSuccessSnack(context, Strings.photoSaved);
    } catch (e) {
      if (e.runtimeType.toString() == '_UserCancelledException') {
        // User cancelled — do nothing
      } else if (mounted) {
        showErrorSnack(
            context, 'Chyba: ${e.toString().replaceAll("Exception:", "")}');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _shareTask() {
    if (widget.task.imageBase64 == null) {
      showErrorSnack(context, Strings.photoRequired);
      return;
    }

    String mobileLink = 'adamapp://confirm?code=${widget.task.code}';
    String webLink =
        'https://calendar-mot.web.app/#/confirm?code=${widget.task.code}';

    SharePlus.instance.share(
      ShareParams(
        text: 'Cau! Mam hotovo: "${widget.task.title}".\n'
            'Koukni na fotku v appce a potvrd mi to!\n\n'
            'V aplikaci: $mobileLink\n'
            'Na webu: $webLink',
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
          side: BorderSide(
            color: context.isDark ? AppColors.borderSubtle : AppColors.borderBold,
            width: NeoTheme.borderWidth,
          ),
        ),
        title: const Text(Strings.deleteTask),
        content: Text('${Strings.deleteTaskConfirm} "${widget.task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(Strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonPink,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete?.call();
            },
            child: const Text(Strings.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _resetRejected() async {
    setState(() => _isProcessing = true);
    try {
      await _taskService.resetRejected(widget.task.id);
      if (mounted) showSuccessSnack(context, Strings.taskResetOk);
    } catch (e) {
      if (mounted) showErrorSnack(context, Strings.taskResetError);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isFullyCompleted = widget.task.completed;
    bool isRejected = widget.task.rejected;
    bool isPending =
        widget.task.imageBase64 != null && !isFullyCompleted && !isRejected;
    final isDark = context.isDark;
    final typeColor = AppColors.colorForTaskType(widget.task.type);

    return GestureDetector(
      onLongPress: isFullyCompleted
          ? null
          : () {
              showModalBottomSheet(
                context: context,
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(NeoTheme.radiusCard)),
                  side: BorderSide(
                    color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
                    width: NeoTheme.borderWidth,
                  ),
                ),
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.borderSubtle : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.edit_rounded),
                        title: const Text(Strings.editTaskAction),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onEdit?.call();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_rounded,
                            color: AppColors.neonPink),
                        title: const Text(Strings.deleteTaskAction,
                            style: TextStyle(color: AppColors.neonPink)),
                        onTap: () {
                          Navigator.pop(context);
                          _showDeleteConfirmation();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
          color: isDark
              ? AppColors.cardDark.withValues(alpha: isFullyCompleted ? 0.6 : 1.0)
              : isFullyCompleted
                  ? Colors.grey.shade50
                  : Colors.white,
          border: Border.all(
            color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
            width: NeoTheme.borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? typeColor.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.12),
              offset: NeoTheme.shadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored top accent — taller
            Container(
              height: NeoTheme.accentBarHeight,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(NeoTheme.radiusCard - 2)),
                color: isFullyCompleted
                    ? AppColors.neonGreen
                    : isRejected
                        ? AppColors.neonPink
                        : typeColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row with type chip
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.task.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration: isFullyCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: isFullyCompleted
                                ? (isDark ? Colors.white30 : Colors.grey)
                                : (isDark ? AppColors.textPrimary : Colors.black87),
                            decorationColor: AppColors.neonGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Type chip — border instead of opacity bg
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(NeoTheme.radiusSmall),
                          color: Colors.transparent,
                          border: Border.all(
                            color: typeColor,
                            width: NeoTheme.borderWidthThin,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getTypeIcon(widget.task.type),
                                size: 14, color: typeColor),
                            const SizedBox(width: 4),
                            Text(
                              widget.task.typeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: typeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Rewards row
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded,
                          size: 14, color: AppColors.neonCyan),
                      const SizedBox(width: 2),
                      Text(
                        '${widget.task.xp} XP',
                        style: TextStyle(
                          color: isFullyCompleted
                              ? (isDark ? Colors.white24 : Colors.grey)
                              : AppColors.neonCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.monetization_on_rounded,
                          size: 14, color: AppColors.neonYellow),
                      const SizedBox(width: 2),
                      Text(
                        '${widget.task.coins}',
                        style: TextStyle(
                          color: isFullyCompleted
                              ? (isDark ? Colors.white24 : Colors.grey)
                              : AppColors.neonYellow,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  // Status badges
                  if (isFullyCompleted)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: StatusBadge(status: StatusType.completed),
                    )
                  else if (isRejected)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: StatusBadge(
                        status: StatusType.rejected,
                        rejectionReason: widget.task.rejectionReason,
                        onRetry: _resetRejected,
                        isProcessing: _isProcessing,
                      ),
                    )
                  else if (isPending)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: StatusBadge(status: StatusType.pending),
                    ),

                  // Photo proof
                  if (widget.task.imageBase64 != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(NeoTheme.radiusButton),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: Image.memory(
                          base64Decode(widget.task.imageBase64!),
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],

                  // Action buttons
                  if (!isFullyCompleted) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _isProcessing
                              ? Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.neonCyan,
                                    ),
                                  ),
                                )
                              : TextButton.icon(
                                  onPressed: _savePhoto,
                                  icon: Icon(Icons.camera_alt_rounded,
                                      color: isDark
                                          ? AppColors.textSecondary
                                          : Colors.black45,
                                      size: 18),
                                  label: Text(
                                    widget.task.imageBase64 == null
                                        ? Strings.takePhoto
                                        : Strings.changePhoto,
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.textSecondary
                                          : Colors.black45,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                  ),
                                ),
                        ),
                        // Share/confirm button with neo style
                        Container(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(NeoTheme.radiusButton),
                            color: widget.task.imageBase64 != null
                                ? typeColor
                                : (isDark
                                    ? Colors.white10
                                    : Colors.grey.shade200),
                            border: widget.task.imageBase64 != null
                                ? Border.all(
                                    color: Colors.white,
                                    width: NeoTheme.borderWidthThin,
                                  )
                                : null,
                            boxShadow: widget.task.imageBase64 != null
                                ? [
                                    BoxShadow(
                                      color: typeColor.withValues(alpha: 0.3),
                                      offset: NeoTheme.shadowOffsetSmall,
                                      blurRadius: 0,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(NeoTheme.radiusButton),
                              onTap: widget.task.imageBase64 != null
                                  ? _shareTask
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.send_rounded,
                                        size: 16,
                                        color:
                                            widget.task.imageBase64 != null
                                                ? Colors.white
                                                : (isDark
                                                    ? Colors.white24
                                                    : Colors.grey)),
                                    const SizedBox(width: 6),
                                    Text(
                                      Strings.confirm,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color:
                                            widget.task.imageBase64 != null
                                                ? Colors.white
                                                : (isDark
                                                    ? Colors.white24
                                                    : Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
