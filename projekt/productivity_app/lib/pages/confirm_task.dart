import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/task_service.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../utils/context_extensions.dart';
import '../utils/ui_helpers.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/neo_pressable.dart';

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
  bool _justConfirmed = false;

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
      _justConfirmed = false;
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
        _codeController.clear();
        setState(() {
          _isLoading = false;
          _lookup = null;
          _justConfirmed = true;
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, Strings.taskConfirmError);
        setState(() => _isLoading = false);
      }
    }
  }

  void _confirmAnother() {
    setState(() => _justConfirmed = false);
  }

  Widget _buildSuccessCard(bool isDark) {
    return Container(
      decoration: NeoTheme.cardDecoration(isDark: isDark),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.neonGreen,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white, width: NeoTheme.borderWidth),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonGreen.withValues(alpha: 0.4),
                    offset: NeoTheme.shadowOffset,
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.black, size: 42),
            ),
            const SizedBox(height: 18),
            const Text(
              Strings.confirmedHeadline,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              Strings.taskConfirmed,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppColors.textSecondary : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _confirmAnother,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark
                            ? AppColors.borderSubtle
                            : AppColors.borderBold,
                        width: NeoTheme.borderWidth,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(NeoTheme.radiusButton),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(Strings.confirmAnother),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeoPressable(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: NeoTheme.buttonDecoration(
                        backgroundColor: context.primaryColor,
                        borderColor: Colors.white,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text(
                            Strings.goBack,
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                            ),
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
    );
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
            if (!_justConfirmed) ...[
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
            ],
            if (_isLoading)
              const CircularProgressIndicator(color: AppColors.neonCyan),
            if (_justConfirmed && !_isLoading) _buildSuccessCard(isDark),
            if (taskData != null && !_isLoading && !_justConfirmed) ...[
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
                          child: AspectRatio(
                            aspectRatio: NeoTheme.photoAspectRatio,
                            child: Image.memory(
                              base64Decode(taskData['imageBase64']),
                              fit: BoxFit.cover,
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
                            child: NeoPressable(
                              onTap: _showRejectDialog,
                              child: Container(
                                decoration: NeoTheme.buttonDecoration(
                                  backgroundColor: AppColors.neonPink,
                                  borderColor: Colors.white,
                                ),
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
                          const SizedBox(width: NeoTheme.spaceSm),
                          // Confirm button — primary theme color
                          Expanded(
                            child: NeoPressable(
                              onTap: _confirm,
                              child: Container(
                                decoration: NeoTheme.buttonDecoration(
                                  backgroundColor: context.primaryColor,
                                  borderColor: Colors.white,
                                ),
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
