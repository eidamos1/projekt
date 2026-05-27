import 'package:flutter/material.dart';
import '../services/task_service.dart';
import '../constants/achievements.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../models/achievement.dart';
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

            // Group by section (Dnes / Včera / Tento týden / Starší).
            // Stream is sorted by createdAt DESC, so we walk in order
            // and inject a header when the section changes.
            final now = DateTime.now();
            final children = <Widget>[];
            String? lastSection;
            for (final notif in notifications) {
              final section = _sectionFor(notif['createdAt'] as String?, now);
              if (section != lastSection) {
                if (children.isNotEmpty) {
                  children.add(const SizedBox(height: NeoTheme.spaceMd));
                }
                children.add(_SectionHeader(label: section, isDark: isDark));
                children.add(const SizedBox(height: NeoTheme.spaceSm));
                lastSection = section;
              }
              children.add(_buildNotifCard(notif, isDark));
            }

            return ListView(
              padding: const EdgeInsets.all(NeoTheme.spaceMd),
              children: children,
            );
          },
        ),
      ),
      bottomNavigationBar: const NeoBottomNav(currentIndex: 3),
    );
  }

  /// Bucket a notification's createdAt timestamp into a UI section label.
  /// createdAt format: 'yyyy-MM-dd HH:mm'.
  String _sectionFor(String? createdAt, DateTime now) {
    if (createdAt == null || createdAt.isEmpty) {
      return Strings.notifSectionOlder;
    }
    final date = DateTime.tryParse(createdAt.replaceFirst(' ', 'T'));
    if (date == null) return Strings.notifSectionOlder;
    final today = DateTime(now.year, now.month, now.day);
    final notifDay = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(notifDay).inDays;
    if (diffDays == 0) return Strings.notifSectionToday;
    if (diffDays == 1) return Strings.notifSectionYesterday;
    if (diffDays < 7) return Strings.notifSectionThisWeek;
    return Strings.notifSectionOlder;
  }

  Widget _buildNotifCard(Map<String, dynamic> notif, bool isDark) {
    final type = notif['type'];
    final isRead = notif['read'] == true;

    IconData icon;
    Color accentColor;
    String titleText;
    Achievement? achievement;
    final achievementId = notif['achievementId'] as String?;

    if (type == 'confirmed') {
      icon = Icons.check_circle_rounded;
      accentColor = AppColors.neonGreen;
      titleText = '${notif['fromNickname']} — úkol potvrzen';
    } else if (type == 'expiring') {
      icon = Icons.schedule_rounded;
      accentColor = AppColors.neonOrange;
      titleText = Strings.expiringNotification;
    } else if (type == 'achievement') {
      achievement = achievementId != null
          ? Achievements.byId(achievementId)
          : null;
      icon = Icons.emoji_events_rounded;
      accentColor = achievement?.color ?? AppColors.neonYellow;
      titleText = Strings.achievementNotifTitle;
    } else if (type == 'friend_pending') {
      icon = Icons.hourglass_top_rounded;
      accentColor = AppColors.neonGreen;
      titleText =
          '${notif['fromNickname'] ?? '—'}${Strings.friendPendingTitlePrefix}';
    } else if (type == 'friend_added') {
      icon = Icons.person_add_rounded;
      accentColor = AppColors.neonCyan;
      titleText =
          '${notif['fromNickname'] ?? '—'}${Strings.friendAddedTitleSuffix}';
    } else {
      icon = Icons.cancel_rounded;
      accentColor = AppColors.neonPink;
      titleText = '${notif['fromNickname']} — úkol zamítnut';
    }

    // For achievement notifs, show achievement title in the subtitle
    // instead of taskTitle (taskTitle is a fallback set by the
    // service, but achievement.title is the canonical name).
    // friend_added has no task context — leave subText empty.
    final String subText;
    if (type == 'achievement') {
      subText = achievement?.title ?? notif['taskTitle'] ?? '';
    } else if (type == 'friend_added') {
      subText = '';
    } else {
      subText = notif['taskTitle'] ?? '';
    }

    return GestureDetector(
      onTap: () {
        if (!isRead) {
          _taskService.markNotificationRead(notif['id']);
        }
        if (type == 'achievement' && achievementId != null) {
          Navigator.pushNamed(
            context,
            '/stats',
            arguments: {'highlightId': achievementId},
          );
        } else if (type == 'friend_pending') {
          final code = notif['code'] as String?;
          if (code != null && code.isNotEmpty) {
            Navigator.pushNamed(
              context,
              '/confirm',
              arguments: code,
            );
          }
        } else if (type == 'friend_added') {
          Navigator.pushNamed(context, '/profile');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: NeoTheme.spaceSm),
        decoration: NeoTheme.cardDecoration(
          isDark: isDark,
          borderColor: isRead ? null : accentColor,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        if (subText.isNotEmpty) ...[
                          const SizedBox(height: NeoTheme.spaceXs),
                          Text(
                            '"$subText"',
                            style: NeoTheme.body,
                          ),
                        ],
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
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionHeader({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: isDark ? AppColors.textSecondary : Colors.black54,
      ),
    );
  }
}
