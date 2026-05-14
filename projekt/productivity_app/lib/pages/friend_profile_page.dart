import 'package:flutter/material.dart';
import '../constants/achievements.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../models/friend_profile.dart';
import '../services/friend_service.dart';
import '../utils/context_extensions.dart';
import '../widgets/friend_badges.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/title_chip.dart';

/// Read-only profile of another user. Reached by tapping a friend row on
/// `/profile` or a non-self leaderboard row on `/stats`. The friend cannot
/// be removed from here (long-press on the friend row in `/profile` still
/// handles that).
class FriendProfilePage extends StatefulWidget {
  final String uid;
  const FriendProfilePage({super.key, required this.uid});

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  final _service = FriendService();
  FriendProfile? _profile;
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _service.loadFriendProfile(widget.uid);
      if (!mounted) return;
      setState(() {
        _profile = p;
        _notFound = p == null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notFound = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.friendProfileTitle)),
      body: ResponsiveLayout(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _notFound || _profile == null
                ? Padding(
                    padding: const EdgeInsets.all(NeoTheme.spaceLg),
                    child: Center(
                      child: Text(
                        Strings.friendNotFound,
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: isDark
                              ? AppColors.textSecondary
                              : Colors.black54,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(NeoTheme.spaceMd),
                    children: [
                      _Header(profile: _profile!, isDark: isDark),
                      const SizedBox(height: NeoTheme.spaceLg),
                      Text(
                        Strings.friendStatsHeader,
                        style: NeoTheme.caption.copyWith(
                          color: isDark
                              ? AppColors.textSecondary
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: NeoTheme.spaceSm),
                      _StatsCard(profile: _profile!, isDark: isDark),
                    ],
                  ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final FriendProfile profile;
  final bool isDark;
  const _Header({required this.profile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final nick = profile.nickname;
    final letter = nick.isEmpty ? '?' : nick[0].toUpperCase();
    final titleAch = profile.activeTitleId == null
        ? null
        : Achievements.byId(profile.activeTitleId!);

    return Container(
      decoration: NeoTheme.cardDecoration(isDark: isDark),
      padding: const EdgeInsets.all(NeoTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: context.primaryColor,
            child: Text(
              letter,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: NeoTheme.spaceMd),
          Text(
            nick,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          if (titleAch != null) ...[
            const SizedBox(height: NeoTheme.spaceSm),
            TitleChip(achievement: titleAch),
          ],
          const SizedBox(height: NeoTheme.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${Strings.friendStatLevel} ${profile.level}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.primaryColor,
                ),
              ),
              const SizedBox(width: NeoTheme.spaceSm),
              Text(
                '·',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textSecondary : Colors.black54,
                ),
              ),
              const SizedBox(width: NeoTheme.spaceSm),
              StreakFlame(streak: profile.streak, size: 16),
              const SizedBox(width: 4),
              Text(
                Strings.dayPlural(profile.streak),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final FriendProfile profile;
  final bool isDark;
  const _StatsCard({required this.profile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: NeoTheme.cardDecoration(isDark: isDark),
      padding: const EdgeInsets.symmetric(
        horizontal: NeoTheme.spaceMd,
        vertical: NeoTheme.spaceSm,
      ),
      child: Column(
        children: [
          _StatRow(
            label: Strings.friendStatCompleted,
            value: '${profile.totalCompletedTasks}',
            isDark: isDark,
          ),
          _Divider(isDark: isDark),
          _StatRow(
            label: Strings.friendStatWeekly,
            value: '${profile.weeklyXp} XP',
            isDark: isDark,
          ),
          _Divider(isDark: isDark),
          _StatRow(
            label: Strings.friendStatCoins,
            value: '${profile.coins}',
            valueColor: AppColors.neonYellow,
            isDark: isDark,
          ),
          _Divider(isDark: isDark),
          _StatRow(
            label: Strings.friendStatAchievements,
            value:
                '${profile.achievementsUnlockedCount} / ${Achievements.all.length}',
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;
  const _StatRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NeoTheme.spaceSm + 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark
          ? AppColors.borderSubtle
          : AppColors.borderBold.withValues(alpha: 0.6),
    );
  }
}

