import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../models/achievement.dart';
import '../utils/context_extensions.dart';
import 'neo_pressable.dart';

/// Achievement card — locked or unlocked. ~140x160 px.
///
/// Locked = dark bg, gray `?` icon, `???` title, teaser body. Not tappable.
/// Unlocked = neon icon in [Achievement.color], CAPS title, description body. Tappable.
/// Locked milestone = thin progress bar at the bottom showing
/// [progressCurrent] / [progressTarget].
class AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final bool isUnlocked;
  final int? progressCurrent;
  final int? progressTarget;
  final VoidCallback? onTap;

  /// When true, the card briefly pulses a colored ring to draw attention —
  /// used when arriving here from an unlock notif tap or toast tap.
  final bool highlighted;

  const AchievementCard({
    super.key,
    required this.achievement,
    required this.isUnlocked,
    this.progressCurrent,
    this.progressTarget,
    this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final color = achievement.color;

    final showProgress = !isUnlocked &&
        progressCurrent != null &&
        progressTarget != null &&
        progressTarget! > 0;

    // Locked cards have a slightly different look: muted bg, no border tint.
    final borderColor = isUnlocked
        ? color
        : (isDark ? AppColors.borderSubtle : AppColors.borderBold);

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
      color: isUnlocked
          ? (isDark ? AppColors.cardDark : AppColors.cardLight)
          : (isDark
              ? AppColors.scaffoldDark
              : const Color(0xFFE8E8E8)),
      border: Border.all(
        color: borderColor,
        width: NeoTheme.borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: isUnlocked
              ? color.withValues(alpha: isDark ? 0.35 : 0.18)
              : (isDark
                  ? Colors.black.withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.10)),
          offset: NeoTheme.shadowOffset,
          blurRadius: 0,
        ),
      ],
    );

    final lockedIconColor = isDark
        ? AppColors.textSecondary
        : Colors.black38;
    final lockedTextColor = isDark
        ? AppColors.textSecondary
        : Colors.black54;

    final title = isUnlocked ? achievement.title.toUpperCase() : '???';
    final body = isUnlocked ? achievement.description : achievement.teaser;
    final iconData =
        isUnlocked ? achievement.icon : Icons.help_outline_rounded;
    final iconColor = isUnlocked ? color : lockedIconColor;

    final card = Container(
      width: 140,
      height: 160,
      decoration: decoration,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, size: 28, color: iconColor),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isUnlocked
                  ? color
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w500,
                color: isUnlocked
                    ? (isDark ? AppColors.textPrimary : Colors.black87)
                    : lockedTextColor,
              ),
            ),
          ),
          if (showProgress) ...[
            const SizedBox(height: 4),
            _ProgressBar(
              current: progressCurrent!,
              target: progressTarget!,
              color: color,
              isDark: isDark,
            ),
            const SizedBox(height: 2),
            Text(
              '${progressCurrent!} / ${progressTarget!}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );

    // onTap is null for locked cards — NeoPressable detects this and disables
    // the press animation as well.
    final pressable = NeoPressable(
      onTap: isUnlocked ? onTap : null,
      child: card,
    );

    if (!highlighted) return pressable;

    // Pulse a colored outer glow that ramps in fast and fades out over ~2s.
    // The triangle wave (0 -> 1 -> 0) gives a single full pulse; StatsPage
    // clears the highlight flag after 3s so the card returns to baseline.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2000),
      curve: Curves.easeInOut,
      builder: (context, t, child) {
        // Triangle wave 0->1->0 across the tween.
        final pulse = t < 0.5 ? t * 2 : (1 - t) * 2;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NeoTheme.radiusCard + 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.55 * pulse),
                blurRadius: 18 * pulse,
                spreadRadius: 4 * pulse,
              ),
            ],
          ),
          child: child,
        );
      },
      child: pressable,
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int current;
  final int target;
  final Color color;
  final bool isDark;

  const _ProgressBar({
    required this.current,
    required this.target,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (current / target).clamp(0.0, 1.0);
    return Container(
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
          width: 1,
        ),
        color: isDark ? Colors.black26 : Colors.white,
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: ratio,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
