import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/task_service.dart';

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
        if (mounted) _showSnack('Ukol s timto kodem nenalezen nebo uz byl potvrzen.');
      }
    } catch (e) {
      if (mounted) _showSnack('Chyba pri hledani: Zkuste to znovu.');
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Potvrzeno! Odmena pripsana.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chyba pri potvrzovani. Zkuste to znovu.')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showRejectDialog() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odmitnout ukol'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Proc odmitas tento ukol?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Duvod odmiteni',
                border: OutlineInputBorder(),
                hintText: 'Napr. Fotka neodpovida ukolu...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrusit'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final text = reasonController.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Zadej duvod odmiteni')),
                );
                return;
              }
              Navigator.pop(context, text);
            },
            child: const Text('Odmitnout'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ukol byl odmitnut.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chyba pri odmitani. Zkuste to znovu.')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final taskData = _lookup?.taskData;

    return Scaffold(
      appBar: AppBar(title: const Text('Potvrzeni ukolu')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Kod ukolu',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _findTask,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const CircularProgressIndicator(),
            if (taskData != null && !_isLoading) ...[
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Potvrzujes ukol:',
                          style: TextStyle(color: Colors.grey)),
                      Text(taskData['title'],
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      if (taskData['imageBase64'] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(taskData['imageBase64']),
                            height: 250,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          height: 100,
                          color: Colors.grey[200],
                          child: const Center(child: Text('Bez fotky')),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        'Odmena: ${taskData['xp']} XP | ${taskData['coins']} Minci',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _showRejectDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.all(16),
                              ),
                              child: const Text('ODMITNOUT',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _confirm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.all(16),
                              ),
                              child: const Text('POTVRDIT',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white)),
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
    );
  }
}
