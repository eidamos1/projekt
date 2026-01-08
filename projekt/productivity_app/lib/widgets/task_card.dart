// widgets/task_card.dart
import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Název úkolu
            Text(
              task.title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            // Typ a odměna
            Text('Typ: ${task.type}    XP: ${task.xp}    Coiny: ${task.coins}'),
            SizedBox(height: 4),
            // Potvrzovací kód
            Text('Potvrzovací kód: ${task.code}',
                style: TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}
