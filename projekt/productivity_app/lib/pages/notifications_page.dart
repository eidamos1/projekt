import 'package:flutter/material.dart';
import '../services/task_service.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../utils/context_extensions.dart';
import '../widgets/empty_state.dart';
import '../widgets/neo_bottom_nav.dart';
import '../widgets/neo_skeleton.dart';
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
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.notifications),
        actions: [
          TextButton(
            onPressed: () => _taskService.markAllNotificationsRead(),
            child: Text(Strings.readAll,
                style: TextStyle(
                    color: context.primaryColor,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ResponsiveLayout(
        child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _taskService.notificationsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const NeoSkeletonList(count: 4, itemHeight: 80);
          }
          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: Strings.noNotifications,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(NeoTheme.spaceMd),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final type = notif['type'];
              final isRead = notif['read'] == true;

              IconData icon;
              Color accentColor;
              String titleText;

              if (type == 'confirmed') {
                icon = Icons.check_circle_rounded;
                accentColor = AppColors.neonGreen;
                titleText = '${notif['fromNickname']} potvrdil/a ukol';
              } else if (type == 'expiring') {
                icon = Icons.schedule_rounded;
                accentColor = AppColors.neonOrange;
                titleText = Strings.expiringNotification;
              } else {
                icon = Icons.cancel_rounded;
                accentColor = AppColors.neonPink;
                titleText = '${notif['fromNickname']} odmitl/a ukol';
              }

              return GestureDetector(
                onTap: () {
                  if (!isRead) {
                    _taskService.markNotificationRead(notif['id']);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: NeoTheme.spaceSm),
                  decoration: NeoTheme.cardDecoration(
                    isDark: isDark,
                    borderColor:
                        isRead ? null : accentColor,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top accent bar (only for unread)
                      if (!isRead)
                        Container(
                          height: NeoTheme.accentBarHeight,
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(NeoTheme.radiusCard - 2),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(NeoTheme.spaceMd),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, color: accentColor, size: 28),
                            const SizedBox(width: NeoTheme.spaceMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titleText,
                                    style: NeoTheme.subhead.copyWith(
                                      color: isRead
                                          ? (isDark
                                              ? AppColors.textSecondary
                                              : Colors.black54)
                                          : null,
                                      fontWeight: isRead
                                          ? FontWeight.w600
                                          : FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: NeoTheme.spaceXs),
                                  Text(
                                    '"${notif['taskTitle']}"',
                                    style: NeoTheme.body,
                                  ),
                                  if (type == 'rejected' &&
                                      notif['message'] != null) ...[
                                    const SizedBox(height: NeoTheme.spaceXs),
                                    Text(
                                      '${Strings.reasonPrefix}${notif['message']}',
                                      style: NeoTheme.body.copyWith(
                                        color: AppColors.neonPink,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: NeoTheme.spaceXs),
                                  Text(
                                    notif['createdAt'] ?? '',
                                    style: NeoTheme.caption.copyWith(
                                      color: isDark
                                          ? AppColors.textSecondary
                                          : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        ),
      ),
      bottomNavigationBar: const NeoBottomNav(currentIndex: 3),
    );
  }
}
