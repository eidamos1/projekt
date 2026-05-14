import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/image_service.dart';
import '../services/friend_service.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../constants/task_categories.dart';
import '../utils/context_extensions.dart';
import '../utils/ui_helpers.dart';
import 'neo_bottom_sheet.dart';
import 'neo_pressable.dart';
import 'status_badge.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  const TaskCard({super.key, required this.task, this.onDelete, this.onEdit});

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard>
    with SingleTickerProviderStateMixin {
  final _taskService = TaskService();
  bool _isProcessing = false;
  Uint8List? _decodedImage;
  String? _decodedFor;

  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _flashAnim;

  @override
  void initState() {
    super.initState();
    _refreshDecodedImage();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1.0, // start at rest (no flash, scale 1.0)
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.04)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.04, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
    ]).animate(_pulseController);
    _flashAnim = Tween<double>(begin: 0.3, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Defensive cleanup: if we mount with an already-resolved task that had
    // a photo uploaded, the friend_pending notif may still linger in friend
    // inboxes from a session where we weren't online to catch the transition
    // (so didUpdateWidget's cleanup never fired). The cleanup is idempotent —
    // deleting a missing doc is a no-op.
    final hasPhoto = widget.task.imageBase64 != null &&
        widget.task.imageBase64!.isNotEmpty;
    final isResolved = widget.task.completed || widget.task.rejected;
    if (hasPhoto && isResolved) {
      FriendService().cleanupFriendPendingNotifs(widget.task.id).ignore();
    }
  }

  @override
  void didUpdateWidget(covariant TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.imageBase64 != widget.task.imageBase64) {
      _refreshDecodedImage();
    }
    // Pulse on transition false -> true (skip on mount-with-completed).
    if (!oldWidget.task.completed && widget.task.completed) {
      _pulseController.forward(from: 0);
    }
    // Owner-side cleanup of the friend-feed. The confirm/reject paths run as
    // the *confirmer*, who can't iterate the owner's /friends collection, so
    // the cleanup must run here — on the owner's device — once the realtime
    // stream surfaces the resolved state.
    final wasUnresolved =
        !oldWidget.task.completed && !oldWidget.task.rejected;
    final nowResolved = widget.task.completed || widget.task.rejected;
    if (wasUnresolved && nowResolved) {
      FriendService().cleanupFriendPendingNotifs(widget.task.id).ignore();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _refreshDecodedImage() {
    final src = widget.task.imageBase64;
    if (src == null) {
      _decodedImage = null;
      _decodedFor = null;
      return;
    }
    if (_decodedFor == src) return;
    _decodedImage = base64Decode(src);
    _decodedFor = src;
  }

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

      // Fire-and-forget: tell every friend the task is awaiting confirmation
      // so they can confirm directly from their notifications inbox without
      // copying the share code. A notif failure must not block the photo save.
      FriendService().notifyFriendsOfPendingTask(
        taskId: widget.task.id,
        taskTitle: widget.task.title,
        code: widget.task.code,
      ).ignore();

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

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: GestureDetector(
      onLongPress: isFullyCompleted
          ? null
          : () {
              showNeoBottomSheet<void>(
                context: context,
                children: [
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
        child: Stack(
          children: [
            Column(
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.task.habitId != null) ...[
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    NeoTheme.radiusSmall),
                                border: Border.all(
                                  color: typeColor,
                                  width: NeoTheme.borderWidthThin,
                                ),
                              ),
                              child: Icon(Icons.autorenew_rounded,
                                  size: 12, color: typeColor),
                            ),
                            const SizedBox(width: 4),
                          ],
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

                  // Category chips
                  if (widget.task.categories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: widget.task.categories
                          .map((key) => Categories.byKey(key))
                          .whereType<TaskCategory>()
                          .map((cat) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                NeoTheme.radiusSmall),
                            border: Border.all(
                              color: cat.color,
                              width: NeoTheme.borderWidthThin,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cat.icon, size: 11, color: cat.color),
                              const SizedBox(width: 3),
                              Text(
                                cat.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: cat.color,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

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

                  // Photo proof — uniform 4:3 with cover-fit so portrait
                  // photos don't leave letterbox bars on the sides.
                  if (_decodedImage != null) ...[
                    const SizedBox(height: NeoTheme.spaceSm),
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(NeoTheme.radiusButton),
                      child: AspectRatio(
                        aspectRatio: NeoTheme.photoAspectRatio,
                        child: Image.memory(
                          _decodedImage!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ],

                  // Action buttons
                  if (!isFullyCompleted) ...[
                    const SizedBox(height: 10),
                    IntrinsicHeight(
                      child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        NeoPressable(
                          onTap: widget.task.imageBase64 != null
                              ? _shareTask
                              : null,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                  NeoTheme.radiusButton),
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
                                        color:
                                            typeColor.withValues(alpha: 0.3),
                                        offset: NeoTheme.shadowOffsetSmall,
                                        blurRadius: 0,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.send_rounded,
                                      size: 16,
                                      color: widget.task.imageBase64 != null
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
                      ],
                    ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _flashAnim,
                  builder: (_, _) {
                    final v = _flashAnim.value;
                    if (v <= 0) return const SizedBox.shrink();
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(NeoTheme.radiusCard),
                        color: AppColors.neonGreen.withValues(alpha: v),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
