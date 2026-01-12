// widgets/task_card.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  const TaskCard({super.key, required this.task});

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

void _shareTask() {
String mobileLink = 'adamapp://confirm?code=${task.code}';
    // Pokud víš, kde ti web běží (např. na Firebase), dej sem tu adresu
    // Pro testování stačí localhost, ale kamarádovi localhost fungovat nebude (musel bys to nahrát na internet)
    String webLink = 'https://calendar-mot.web.app/#/confirm?code=${task.code}';

    SharePlus.instance.share(ShareParams(text: 
      'Ahoj! Potvrď mi splnění úkolu "${task.title}".\n\n'
      '📱 V aplikaci klikni sem:\n$mobileLink\n\n'
      '💻 Na webu klikni sem:\n$webLink'
    ));
}

@override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              _getTypeColor(task.type).withOpacity(0.1)
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  // "Badge" pro typ úkolu
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTypeColor(task.type),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task.typeLabel.toUpperCase(),
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 20),
                  SizedBox(width: 4),
                  Text('${task.xp} XP', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(width: 16),
                  Icon(Icons.monetization_on, color: Colors.amber[700], size: 20),
                  SizedBox(width: 4),
                  Text('${task.coins}', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kód:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text(
                        task.code,
                        style: TextStyle(fontSize: 20, letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                  // Tlačítko pro sdílení
                  ElevatedButton.icon(
                    onPressed: _shareTask,
                    icon: Icon(Icons.share, size: 18),
                    label: Text("Požádat o potvrzení"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
