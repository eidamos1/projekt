import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/neo_theme.dart';
import '../../constants/strings.dart';
import '../../models/achievement.dart';
import '../../services/achievement_service.dart';
import '../../utils/context_extensions.dart';
import '../neo_bottom_sheet.dart';
import '../neo_pressable.dart';

void showAchievementDetailSheet(
  BuildContext context,
  Achievement achievement,
  String? unlockedAt,
) {
  showNeoBottomSheet<void>(
    context: context,
    children: [
      AchievementDetailSheet(
        achievement: achievement,
        unlockedAt: unlockedAt,
      ),
    ],
  );
}

class AchievementDetailSheet extends StatelessWidget {
  final Achievement achievement;
  final String? unlockedAt;

  const AchievementDetailSheet({
    super.key,
    required this.achievement,
    required this.unlockedAt,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final color = achievement.color;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NeoTheme.spaceLg, NeoTheme.spaceLg, NeoTheme.spaceLg, NeoTheme.spaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(achievement.icon, size: 56, color: color),
          const SizedBox(height: NeoTheme.spaceSm),
          Text(
            achievement.title.toUpperCase(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: NeoTheme.spaceSm),
          Text(
            achievement.description,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          if (unlockedAt != null && unlockedAt!.isNotEmpty) ...[
            const SizedBox(height: NeoTheme.spaceMd),
            Text(
              '${Strings.achievementUnlockedAt} $unlockedAt',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textSecondary : Colors.black54,
              ),
            ),
          ],
          if (achievement.isTitleEligible) ...[
            const SizedBox(height: NeoTheme.spaceLg),
            _TitleButton(achievement: achievement),
          ],
        ],
      ),
    );
  }
}

class _TitleButton extends StatelessWidget {
  final Achievement achievement;

  const _TitleButton({required this.achievement});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: AchievementService().activeTitleStream(),
      builder: (context, snapshot) {
        final isCurrent = snapshot.data == achievement.id;
        return NeoPressable(
          onTap: () async {
            await AchievementService()
                .setActiveTitle(isCurrent ? null : achievement.id);
          },
          child: Container(
            width: double.infinity,
            decoration: isCurrent
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
                    color: Colors.transparent,
                    border: Border.all(
                      color: context.isDark
                          ? AppColors.borderSubtle
                          : AppColors.borderBold,
                      width: NeoTheme.borderWidth,
                    ),
                  )
                : NeoTheme.buttonDecoration(
                    backgroundColor: achievement.color,
                    borderColor: Colors.white,
                  ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                isCurrent
                    ? Strings.achievementRemoveTitle
                    : Strings.achievementSetAsTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: isCurrent
                      ? (context.isDark
                          ? AppColors.textSecondary
                          : Colors.black54)
                      : Colors.black,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
