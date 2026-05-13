import 'package:flutter/material.dart';
import '../constants/neo_theme.dart';
import '../models/achievement.dart';

/// Floating SnackBar in neo style shown right after an achievement is unlocked.
///
/// Background is transparent so the inner Container can carry the neon color,
/// black 2px border and hard offset shadow consistent with the rest of the
/// design system. Tapping the chip routes to /stats with `highlightId` so the
/// stats page can pulse the matching card.
void showAchievementUnlockToast(BuildContext context, Achievement ach) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      content: GestureDetector(
        onTap: () {
          // Dismiss the toast before navigating so it doesn't linger on /stats.
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          Navigator.pushNamed(
            context,
            '/stats',
            arguments: {'highlightId': ach.id},
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: ach.color,
            border: Border.all(color: Colors.black, width: NeoTheme.borderWidth),
            borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                offset: NeoTheme.shadowOffsetSmall,
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ach.icon, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Odemknul jsi: ${ach.title}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
