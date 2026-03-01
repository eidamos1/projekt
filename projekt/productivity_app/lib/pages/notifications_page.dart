import 'package:flutter/material.dart';
import '../services/task_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _taskService = TaskService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikace'),
        actions: [
          TextButton(
            onPressed: () => _taskService.markAllNotificationsRead(),
            child: const Text('Precist vse',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _taskService.notificationsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Zadne notifikace',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final isConfirmed = notif['type'] == 'confirmed';
              final isRead = notif['read'] == true;

              return ListTile(
                leading: Icon(
                  isConfirmed ? Icons.check_circle : Icons.cancel,
                  color: isConfirmed ? Colors.green : Colors.red,
                  size: 32,
                ),
                title: Text(
                  isConfirmed
                      ? '${notif['fromNickname']} potvrdil/a ukol'
                      : '${notif['fromNickname']} odmitl/a ukol',
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('"${notif['taskTitle']}"'),
                    if (!isConfirmed && notif['message'] != null)
                      Text('Duvod: ${notif['message']}',
                          style: const TextStyle(
                              color: Colors.red, fontSize: 12)),
                    Text(notif['createdAt'] ?? '',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11)),
                  ],
                ),
                tileColor: isRead ? null : Colors.indigo.withValues(alpha: 0.05),
                onTap: () {
                  if (!isRead) {
                    _taskService.markNotificationRead(notif['id']);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
