import 'package:flutter/material.dart';
import '../constants/neo_theme.dart';
import '../models/achievement.dart';
import 'neo_pressable.dart';

/// Small chip-style widget that displays an Achievement title.
///
/// Border in achievement.color, subtle tinted background, icon + uppercase
/// title text. Wrap-friendly (no Expanded). If [onTap] is non-null, the
/// chip is wrapped in [NeoPressable] for the same press feel as buttons.
class TitleChip extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback? onTap;

  const TitleChip({
    super.key,
    required this.achievement,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = achievement.color;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
        border: Border.all(
          color: color,
          width: NeoTheme.borderWidthThin,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(achievement.icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            achievement.title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return NeoPressable(onTap: onTap, child: chip);
  }
}
