import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/task_service.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../utils/context_extensions.dart';
import '../utils/ui_helpers.dart';
import '../widgets/responsive_layout.dart';

class ConfirmTaskPage extends StatefulWidget {
  const ConfirmTaskPage({super.key});

  @override
  State<ConfirmTaskPage> createState() => _ConfirmTaskPageState();
}

class _ConfirmTaskPageState extends State<ConfirmTaskPage> {
  final _codeController = TextEditingController();
  final _taskService = TaskService();
  bool _isInit = true;
  bool _isLoading = false;

  TaskLookupResult? _lookup;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _codeController.text = args;
        WidgetsBinding.instance.addPostFrameCallback((_) => _findTask());
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _findTask() async {
    String code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _isLoading = true;
      _lookup = null;
    });

    try {
      final result = await _taskService.findTaskByCode(code);
      if (result != null) {
        setState(() => _lookup = result);
      } else {
        if (mounted) showErrorSnack(context, Strings.taskNotFound);
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, Strings.taskSearchError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirm() async {
    if (_isLoading || _lookup == null) return;
    setState(() => _isLoading = true);

    try {
      await _taskService.confirmTask(_lookup!);
      if (mounted) {
        showSuccessSnack(context, Strings.taskConfirmed);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, Strings.taskConfirmError);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showRejectDialog() async {
    final isDark = context.isDark;
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
          side: BorderSide(
            color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
            width: NeoTheme.borderWidth,
          ),
        ),
        title: const Text(Strings.rejectTask),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(Strings.rejectReason),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: Strings.rejectReasonLabel,
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(NeoTheme.radiusButton)),
                hintText: Strings.rejectReasonHint,
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(Strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonPink,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final text = reasonController.text.trim();
              if (text.isEmpty) {
                showErrorSnack(context, Strings.rejectReasonRequired);
                return;
              }
              Navigator.pop(context, text);
            },
            child: const Text(Strings.statusRejected),
          ),
        ],
      ),
    );

    reasonController.dispose();

    if (reason == null || reason.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _taskService.rejectTask(_lookup!, reason);
      if (mounted) {
        showSuccessSnack(context, Strings.taskRejected);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, Strings.taskRejectError);
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskData = _lookup?.taskData;
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.confirmTask)),
      body: ResponsiveLayout(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: Strings.taskCodeLabel,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _findTask,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator(color: AppColors.neonCyan),
            if (taskData != null && !_isLoading) ...[
              Container(
                decoration: NeoTheme.cardDecoration(isDark: isDark),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(Strings.confirmingTask,
                          style: TextStyle(color: AppColors.textSecondary)),
                      Text(taskData['title'],
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      if (taskData['imageBase64'] != null)
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(NeoTheme.radiusCard),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 400),
                            child: Image.memory(
                              base64Decode(taskData['imageBase64']),
                              width: double.infinity,
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.cardDark,
                            borderRadius:
                                BorderRadius.circular(NeoTheme.radiusCard),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderSubtle
                                  : AppColors.borderBold,
                              width: NeoTheme.borderWidth,
                            ),
                          ),
                          child: Center(
                              child: Text(Strings.noPhoto,
                                  style: TextStyle(
                                      color: AppColors.textSecondary))),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        Strings.rewardText(
                            taskData['xp'] ?? 0, taskData['coins'] ?? 0),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          // Reject button — neon pink
                          Expanded(
                            child: Container(
                              decoration: NeoTheme.buttonDecoration(
                                backgroundColor: AppColors.neonPink,
                                borderColor: Colors.white,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(
                                      NeoTheme.radiusButton),
                                  onTap: _showRejectDialog,
                                  child: const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: Center(
                                      child: Text(Strings.reject,
                                          style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Confirm button — neon green
                          Expanded(
                            child: Container(
                              decoration: NeoTheme.buttonDecoration(
                                backgroundColor: AppColors.neonGreen,
                                borderColor: Colors.white,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(
                                      NeoTheme.radiusButton),
                                  onTap: _confirm,
                                  child: const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: Center(
                                      child: Text(Strings.confirmUpper,
                                          style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
          ),
        ),
    );
  }
}
