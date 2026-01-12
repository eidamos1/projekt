// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Page to add a new task for a specific date
class AddTaskPage extends StatefulWidget {
  const AddTaskPage({super.key});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _xpController = TextEditingController();
  final TextEditingController _coinsController = TextEditingController();

  // Save the task to Firestore
  Future<void> _saveTask(DateTime date) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    // Format date as YYYY-MM-DD
    String dateStr =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // Get values from input
    String title = _titleController.text.trim();
    int xp = int.tryParse(_xpController.text.trim()) ?? 0;
    int coins = int.tryParse(_coinsController.text.trim()) ?? 0;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task title cannot be empty')),
      );
      return;
    }

    // Create task data
    Map<String, dynamic> taskData = {
      'title': title,
      'xp': xp,
      'coins': coins,
      'date': dateStr,
    };

    // Save to Firestore under user's tasks subcollection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .add(taskData);

    // Go back to calendar page after saving
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Retrieve the selected date passed from calendar page
    final DateTime selectedDate =
        ModalRoute.of(context)!.settings.arguments as DateTime;

    return Scaffold(
      appBar: AppBar(
        title: Text('Add Task'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Date: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
            ),
            SizedBox(height: 16.0),
            // Title input
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Task Title',
              ),
            ),
            SizedBox(height: 16.0),
            // XP input
            TextField(
              controller: _xpController,
              decoration: InputDecoration(
                labelText: 'XP Value',
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16.0),
            // Coins input
            TextField(
              controller: _coinsController,
              decoration: InputDecoration(
                labelText: 'Coin Value',
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 32.0),
            // Button to save the task
            ElevatedButton(
              onPressed: () => _saveTask(selectedDate),
              child: Text('Add Task'),
            ),
          ],
        ),
      ),
    );
  }
}
