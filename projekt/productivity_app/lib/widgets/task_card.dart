import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../models/task.dart';
import '../services/task_service.dart';

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

  Color _getTypeColor(TaskType type) {
    switch (type) {
      case TaskType.daily:
        return Colors.blueAccent;
      case TaskType.weekly:
        return Colors.orangeAccent;
      case TaskType.monthly:
        return Colors.purpleAccent;
    }
  }

  Future<void> _savePhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 500,
      imageQuality: 40,
    );
    if (image == null) return;

    setState(() => _isProcessing = true);

    try {
      final bytes = await image.readAsBytes();
      if (bytes.lengthInBytes > 750000) {
        throw Exception('Obrazek je moc velky. Zkus jiny.');
      }

      String base64Image = base64Encode(bytes);
      await _taskService.savePhoto(widget.task.id, base64Image);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dukaz ulozen!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Chyba: ${e.toString().replaceAll("Exception:", "")}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _shareTask() {
    if (widget.task.imageBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Musis nejdriv vyfotit dukaz!'),
            backgroundColor: Colors.red),
      );
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
        title: const Text('Smazat ukol?'),
        content: Text('Opravdu chces smazat "${widget.task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrusit'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete?.call();
            },
            child: const Text('Smazat'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetRejected() async {
    setState(() => _isProcessing = true);
    try {
      await _taskService.resetRejected(widget.task.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ukol pripraven k novemu odeslani!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chyba pri resetu ukolu.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isFullyCompleted = widget.task.completed;
    bool isRejected = widget.task.rejected;
    bool isPending = widget.task.imageBase64 != null && !isFullyCompleted && !isRejected;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final subTextColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;

    return GestureDetector(
      onLongPress: isFullyCompleted
          ? null
          : () {
              showModalBottomSheet(
                context: context,
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Upravit ukol'),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onEdit?.call();
                        },
                      ),
                      ListTile(
                        leading:
                            const Icon(Icons.delete, color: Colors.red),
                        title: const Text('Smazat ukol',
                            style: TextStyle(color: Colors.red)),
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
      child: Card(
        color: isFullyCompleted
            ? Theme.of(context).cardColor.withValues(alpha:0.6)
            : Theme.of(context).cardColor,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        elevation: 4,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: isFullyCompleted
                    ? Colors.green
                    : isRejected
                        ? Colors.red
                        : _getTypeColor(widget.task.type),
                width: 5,
              ),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.task.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  decoration: isFullyCompleted
                      ? TextDecoration.lineThrough
                      : null,
                  color: isFullyCompleted ? Colors.grey : textColor,
                  decorationColor:
                      isFullyCompleted ? Colors.green : textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.task.typeLabel} | ${widget.task.xp} XP | ${widget.task.coins} Minci',
                style: TextStyle(
                  color: isFullyCompleted ? Colors.grey : subTextColor,
                  fontSize: 12,
                ),
              ),

              if (isFullyCompleted)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Row(children: [
                    Icon(Icons.verified, size: 20, color: Colors.green),
                    SizedBox(width: 4),
                    Text('Potvrzeno & Splneno',
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold)),
                  ]),
                )
              else if (isRejected)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.cancel, size: 20, color: Colors.red),
                        SizedBox(width: 4),
                        Text('Odmitnuto',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold)),
                      ]),
                      if (widget.task.rejectionReason != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 24),
                          child: Text(
                            'Duvod: ${widget.task.rejectionReason}',
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing ? null : _resetRejected,
                          icon: const Icon(Icons.refresh, color: Colors.orange),
                          label: const Text('Odeslat znovu',
                              style: TextStyle(color: Colors.orange)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.orange),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (isPending)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Row(children: [
                    Icon(Icons.hourglass_top,
                        size: 20, color: Colors.orange),
                    SizedBox(width: 4),
                    Text('Ceka na potvrzeni kamaradem',
                        style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),

              if (widget.task.imageBase64 != null) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Row(children: [
                    Icon(Icons.image, size: 20, color: Colors.green),
                    SizedBox(width: 4),
                    Text('Dukaz pripojen',
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(widget.task.imageBase64!),
                    height: 200,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ],

              // Ovladaci tlacitka
              if (!isFullyCompleted) ...[
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : TextButton.icon(
                            onPressed: _savePhoto,
                            icon: Icon(Icons.camera_alt,
                                color: textColor),
                            label: Text(
                              widget.task.imageBase64 == null
                                  ? 'Vyfotit dukaz'
                                  : 'Zmenit fotku',
                              style: TextStyle(color: textColor),
                            ),
                          ),
                    ElevatedButton.icon(
                      onPressed: widget.task.imageBase64 != null
                          ? _shareTask
                          : null,
                      icon: const Icon(Icons.send),
                      label: const Text('Potvrdit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _getTypeColor(widget.task.type),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            Colors.grey.withValues(alpha:0.3),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
