import 'package:flutter/material.dart';
import '../constants/achievements.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../models/achievement.dart';
import '../utils/context_extensions.dart';
import 'achievement_card.dart';

enum _Filter { all, situational, loreTitle, antiAchievement, milestone }

/// Achievements section for the stats page.
///
/// Header + counter + filter chips + Wrap grid of cards.
/// Unlocked cards come first (most recent first); locked cards in registry order.
class AchievementGrid extends StatefulWidget {
  final Map<String, String> unlockedAtMap;
  final int totalCompletedTasks;
  final void Function(Achievement) onTapCard;

  /// When non-null, the card with this id renders a pulsing ring to draw the
  /// eye after navigating from a notif tap or unlock toast.
  final String? highlightId;

  const AchievementGrid({
    super.key,
    required this.unlockedAtMap,
    required this.totalCompletedTasks,
    required this.onTapCard,
    this.highlightId,
  });

  @override
  State<AchievementGrid> createState() => _AchievementGridState();
}

class _AchievementGridState extends State<AchievementGrid> {
  _Filter _filter = _Filter.all;

  bool _matchesFilter(Achievement a) {
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.situational:
        return a.type == AchType.situational;
      case _Filter.loreTitle:
        return a.type == AchType.loreTitle;
      case _Filter.antiAchievement:
        return a.type == AchType.antiAchievement;
      case _Filter.milestone:
        return a.type == AchType.milestone;
    }
  }

  int? _progressCurrentFor(Achievement a) {
    if (a.id == 'stovkar') return widget.totalCompletedTasks;
    return null;
  }

  int? _progressTargetFor(Achievement a) {
    if (a.id == 'stovkar') return 100;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final unlockedCount = widget.unlockedAtMap.length;
    final totalCount = Achievements.all.length;

    final all = Achievements.all.where(_matchesFilter).toList();
    final unlocked = all.where((a) => widget.unlockedAtMap.containsKey(a.id)).toList()
      ..sort((a, b) {
        final tsA = widget.unlockedAtMap[a.id] ?? '';
        final tsB = widget.unlockedAtMap[b.id] ?? '';
        return tsB.compareTo(tsA);
      });
    final locked = all.where((a) => !widget.unlockedAtMap.containsKey(a.id)).toList();
    final showEmptyState = unlockedCount == 0 && _filter == _Filter.all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                Strings.achievementsHeader,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Text(
              Strings.achievementCounter(unlockedCount, totalCount),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textSecondary : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: NeoTheme.spaceSm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _filterChip(Strings.achievementFilterAll, _Filter.all, isDark),
            _filterChip(Strings.achievementFilterSituational, _Filter.situational, isDark),
            _filterChip(Strings.achievementFilterLore, _Filter.loreTitle, isDark),
            _filterChip(Strings.achievementFilterAnti, _Filter.antiAchievement, isDark),
            _filterChip(Strings.achievementFilterMilestone, _Filter.milestone, isDark),
          ],
        ),
        const SizedBox(height: NeoTheme.spaceMd),
        if (showEmptyState)
          _EmptyState(isDark: isDark)
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...unlocked.map((a) => AchievementCard(
                    achievement: a,
                    isUnlocked: true,
                    highlighted: widget.highlightId == a.id,
                    onTap: () => widget.onTapCard(a),
                  )),
              ...locked.map((a) => AchievementCard(
                    achievement: a,
                    isUnlocked: false,
                    highlighted: widget.highlightId == a.id,
                    progressCurrent: _progressCurrentFor(a),
                    progressTarget: _progressTargetFor(a),
                  )),
            ],
          ),
      ],
    );
  }

  Widget _filterChip(String label, _Filter value, bool isDark) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      selectedColor: context.primaryColor.withValues(alpha: 0.2),
      side: BorderSide(
        color: selected
            ? context.primaryColor
            : (isDark ? AppColors.borderSubtle : AppColors.borderBold),
        width: NeoTheme.borderWidthThin,
      ),
      onSelected: (_) => setState(() => _filter = value),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;

  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final sample = Achievements.all.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: NeoTheme.spaceSm),
          child: Text(
            Strings.achievementEmptyHint,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: isDark ? AppColors.textSecondary : Colors.black54,
            ),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: sample
              .map((a) => AchievementCard(achievement: a, isUnlocked: false))
              .toList(),
        ),
      ],
    );
  }
}
