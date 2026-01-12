// pages/confirm_task.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConfirmTaskPage extends StatefulWidget {
  @override
  State<ConfirmTaskPage> createState() => _ConfirmTaskPageState();
}

class _ConfirmTaskPageState extends State<ConfirmTaskPage> {
  final _codeController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  bool _isInit = true; // Pomocná proměnná

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pokud se stránka otevřela a byl jí poslán argument (kód), načti ho
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _codeController.text = args;
      }
      _isInit = false;
    }
  }
  Future<void> _confirmCode() async {
    String code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zadejte prosím kód')));
      return;
    }
    bool found = false;
    // Projdeme všechny uživatele a jejich úkoly
    QuerySnapshot usersSnapshot = await _firestore.collection('users').get();
    for (var userDoc in usersSnapshot.docs) {
      final tasksRef = userDoc.reference.collection('tasks');
      QuerySnapshot tasks = await tasksRef.where('code', isEqualTo: code).get();
      if (tasks.docs.isNotEmpty) {
        found = true;
        var taskDoc = tasks.docs.first;
        Map<String, dynamic> data = taskDoc.data() as Map<String, dynamic>;
        // Zkontrolujeme, že úkol ještě nebyl potvrzen (nebyl smazán)
        if (!(data['completed'] ?? false)) {
          int xp = data['xp'] ?? 0;
          int coins = data['coins'] ?? 0;
          // Přičteme uživateli body a mince
          await userDoc.reference.update({
            'xp': FieldValue.increment(xp),
            'coins': FieldValue.increment(coins),
          });
          // Úkol smažeme
          await taskDoc.reference.delete();
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Úkol potvrzen! Uživateli bylo přidáno $xp XP a $coins coinů.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Tento kód již byl použit.')));
        }
        break;
      }
    }
    if (!found) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Kód nenalezen.')));
    }
    _codeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Potvrdit úkol podle kódu')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _codeController,
              decoration: InputDecoration(labelText: 'Potvrzovací kód'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _confirmCode,
              child: Text('Potvrdit kód'),
            ),
          ],
        ),
      ),
    );
  }
}
