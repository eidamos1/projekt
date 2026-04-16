import 'package:flutter/material.dart';
import '../services/task_service.dart';
import '../constants/app_colors.dart';
import '../constants/strings.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive_layout.dart';

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
        title: const Text(Strings.notifications),
        actions: [
          TextButton(
            onPressed: () => _taskService.markAllNotificationsRead(),
            child: const Text(Strings.readAll,
                style: TextStyle(
                    color: AppColors.neonGreen, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ResponsiveLayout(
        child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _taskService.notificationsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.neonCyan));
          }
          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: Strings.noNotifications,
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final type = notif['type'];
              final isRead = notif['read'] == true;

              IconData icon;
              Color iconColor;
              String titleText;

              if (type == 'confirmed') {
                icon = Icons.check_circle;
                iconColor = AppColors.neonGreen;
                titleText = '${notif['fromNickname']} potvrdil/a ukol';
              } else if (type == 'expiring') {
                icon = Icons.schedule;
                iconColor = AppColors.neonOrange;
                titleText = Strings.expiringNotification;
              } else {
                icon = Icons.cancel;
                iconColor = AppColors.neonPink;
                titleText = '${notif['fromNickname']} odmitl/a ukol';
              }

              return ListTile(
                leading: Icon(
                  icon,
                  color: iconColor,
                  size: 32,
                ),
                title: Text(
                  titleText,
                  style: TextStyle(
                    fontWeight:
                        isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('"${notif['taskTitle']}"'),
                    if (type == 'rejected' && notif['message'] != null)
                      Text('${Strings.reasonPrefix}${notif['message']}',
                          style: const TextStyle(
                              color: AppColors.neonPink, fontSize: 12)),
                    Text(notif['createdAt'] ?? '',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
                tileColor: isRead
                    ? null
                    : AppColors.neonGreen.withValues(alpha: 0.06),
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
      ),
    );
  }
}
