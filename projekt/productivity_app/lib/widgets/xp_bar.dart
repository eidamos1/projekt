import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/game_config.dart';
import '../utils/context_extensions.dart';

class XPBar extends StatelessWidget {
  final int xp;
  final int level;
  const XPBar({super.key, required this.xp, required this.level});

  @override
  Widget build(BuildContext context) {
    const xpForNext = GameConfig.xpPerLevel;
    double progress = (xp % xpForNext) / xpForNext;
    final isDark = context.isDark;

    return Row(
      children: [
        // Level badge — neon cyan border, transparent bg
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.neonCyan.withValues(alpha: 0.15),
            border: Border.all(
              color: AppColors.neonCyan,
              width: NeoTheme.borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonCyan.withValues(alpha: 0.3),
                offset: NeoTheme.shadowOffsetSmall,
                blurRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$level',
              style: const TextStyle(
                color: AppColors.neonCyan,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // XP progress
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'LEVEL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: AppColors.neonCyan,
                    ),
                  ),
                  Text(
                    '$xp / $xpForNext XP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondary : Colors.black45,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(NeoTheme.radiusSmall),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  border: Border.all(
                    color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
                    width: NeoTheme.borderWidthThin,
                  ),
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress.clamp(0.02, 1.0)),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(NeoTheme.radiusSmall),
                            color: AppColors.neonCyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
