import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../services/task_service.dart';
import '../utils/context_extensions.dart';

/// Bottom navigation shared across the 5 main tabs. Tapping a tab
/// pushReplacementNames to the target route — the global page-transition
/// builder handles the slide. Notification tab carries the unread badge.
class NeoBottomNav extends StatelessWidget {
  final int currentIndex;

  const NeoBottomNav({super.key, required this.currentIndex});

  static const _items = <_NavItemData>[
    _NavItemData(
      route: '/calendar',
      icon: Icons.today_rounded,
      label: Strings.today,
    ),
    _NavItemData(
      route: '/habits',
      icon: Icons.autorenew_rounded,
      label: Strings.habits,
    ),
    _NavItemData(
      route: '/stats',
      icon: Icons.bar_chart_rounded,
      label: Strings.stats,
    ),
    _NavItemData(
      route: '/notifications',
      icon: Icons.notifications_outlined,
      label: Strings.notifications,
      showUnreadBadge: true,
    ),
    _NavItemData(
      route: '/settings',
      icon: Icons.settings_outlined,
      label: Strings.settings,
    ),
  ];

  void _go(BuildContext context, int index) {
    if (index == currentIndex) return;
    Navigator.pushReplacementNamed(context, _items[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = context.primaryColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        border: Border(
          top: BorderSide(color: accent, width: NeoTheme.borderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_items.length, (i) {
              return Expanded(
                child: _NavButton(
                  data: _items[i],
                  isActive: i == currentIndex,
                  onTap: () => _go(context, i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final String route;
  final IconData icon;
  final String label;
  final bool showUnreadBadge;

  const _NavItemData({
    required this.route,
    required this.icon,
    required this.label,
    this.showUnreadBadge = false,
  });
}

class _NavButton extends StatelessWidget {
  final _NavItemData data;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({
    required this.data,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = context.primaryColor;
    final inactiveColor =
        isDark ? AppColors.textSecondary : Colors.black45;
    final color = isActive ? accent : inactiveColor;

    Widget icon = Icon(data.icon, color: color, size: 22);

    if (data.showUnreadBadge) {
      icon = StreamBuilder<int>(
        stream: TaskService().unreadNotificationCount(),
        builder: (context, snap) {
          final count = snap.data ?? 0;
          return Badge(
            isLabelVisible: count > 0,
            backgroundColor: AppColors.neonPink,
            label: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Icon(data.icon, color: color, size: 22),
          );
        },
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(height: 2),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
