import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/achievements.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../models/activity_feed_item.dart';
import '../models/friend_profile.dart';
import '../models/friend_rank.dart';
import '../models/weekly_winner.dart';
import '../services/friend_service.dart';
import '../utils/context_extensions.dart';
import '../utils/date_helpers.dart';
import '../utils/ui_helpers.dart';
import '../widgets/friend_badges.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/title_chip.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _friendService = FriendService();
  String? _inviteCode;
  bool _loading = true;
  FriendProfile? _ownProfile;

  @override
  void initState() {
    super.initState();
    _loadInvite();
    _loadOwnProfile();
  }

  Future<void> _loadInvite() async {
    try {
      final code = await _friendService.myInviteCode();
      if (mounted) {
        setState(() {
          _inviteCode = code;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOwnProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final p = await _friendService.loadFriendProfile(uid);
      if (mounted) setState(() => _ownProfile = p);
    } catch (_) {/* silent — header just won't render */}
  }

  Future<void> _shareInvite() async {
    if (_inviteCode == null) return;
    final url = 'https://calendar-mot.web.app/#/friend?code=$_inviteCode';
    await SharePlus.instance.share(
      ShareParams(text: '${Strings.inviteShareText}$url'),
    );
  }

  Future<void> _showQrDialog() async {
    if (_inviteCode == null) return;
    final url = 'https://calendar-mot.web.app/#/friend?code=$_inviteCode';
    final isDark = context.isDark;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
          side: BorderSide(
            color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
            width: NeoTheme.borderWidth,
          ),
        ),
        title: const Text(Strings.qrDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // QR is always rendered on a white background so darkmode
            // scanners (and most camera apps) get the contrast they
            // expect. Border keeps it on-brand.
            Container(
              padding: const EdgeInsets.all(NeoTheme.spaceMd),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
                border: Border.all(
                  color: AppColors.borderBold,
                  width: NeoTheme.borderWidth,
                ),
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: NeoTheme.spaceMd),
            Text(
              Strings.qrDialogHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondary : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(Strings.close),
          ),
        ],
      ),
    );
  }

  Future<void> _regenerate() async {
    setState(() => _loading = true);
    try {
      await _friendService.regenerateInviteCode();
      final code = await _friendService.myInviteCode();
      if (mounted) {
        setState(() {
          _inviteCode = code;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.profileTitle)),
      body: ResponsiveLayout(
        child: ListView(
          padding: const EdgeInsets.all(NeoTheme.spaceMd),
          children: [
            if (_ownProfile != null) ...[
              _OwnHeader(profile: _ownProfile!, isDark: isDark),
              const SizedBox(height: NeoTheme.spaceLg),
            ],
            Text(
              Strings.inviteHeader,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: isDark ? AppColors.textSecondary : Colors.black54,
              ),
            ),
            const SizedBox(height: NeoTheme.spaceSm),
            Container(
              decoration: NeoTheme.cardDecoration(isDark: isDark),
              padding: const EdgeInsets.symmetric(
                horizontal: NeoTheme.spaceMd,
                vertical: NeoTheme.spaceMd,
              ),
              alignment: Alignment.center,
              child: _loading
                  ? const SizedBox(
                      height: 24,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : SelectableText(
                      _inviteCode ?? '—',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
            ),
            const SizedBox(height: NeoTheme.spaceSm),
            LayoutBuilder(builder: (context, c) {
              // 3 labeled buttons need ~480px to read comfortably. Below
              // that fall back to a stacked layout so the "Sdílet pozvánku"
              // label doesn't break mid-word.
              final stacked = c.maxWidth < 480;
              final share = OutlinedButton.icon(
                onPressed: _loading ? null : _shareInvite,
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text(Strings.shareInvite),
              );
              final qr = OutlinedButton.icon(
                onPressed:
                    _loading || _inviteCode == null ? null : _showQrDialog,
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: const Text(Strings.qrInvite),
              );
              final regen = OutlinedButton.icon(
                onPressed: _loading ? null : _regenerate,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(Strings.regenerateInvite),
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    share,
                    const SizedBox(height: NeoTheme.spaceXs),
                    qr,
                    const SizedBox(height: NeoTheme.spaceXs),
                    regen,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: share),
                  const SizedBox(width: NeoTheme.spaceSm),
                  Expanded(child: qr),
                  const SizedBox(width: NeoTheme.spaceSm),
                  Expanded(child: regen),
                ],
              );
            }),
            const SizedBox(height: NeoTheme.spaceLg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    Strings.friendsHeader,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: isDark ? AppColors.textSecondary : Colors.black54,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/find-friends'),
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: const Text(Strings.findFriendsTitle),
                ),
              ],
            ),
            const SizedBox(height: NeoTheme.spaceSm),
            StreamBuilder<List<FriendRank>>(
              stream: _friendService.leaderboardStream(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: NeoTheme.spaceMd),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final others = snap.data!.where((r) => !r.isMe).toList();
                if (others.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: NeoTheme.spaceMd),
                    child: Text(
                      Strings.noFriendsYet,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: isDark ? AppColors.textSecondary : Colors.black54,
                      ),
                    ),
                  );
                }
                return Column(
                  children: others
                      .map((e) => _FriendCard(
                            rank: e.rank,
                            uid: e.uid,
                            nickname: e.nickname,
                            weeklyXp: e.weeklyXp,
                            streak: e.streak,
                            isDark: isDark,
                            onRemove: () => _confirmRemove(e.uid, e.nickname),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: NeoTheme.spaceLg),
            _LastWeekWinnerSection(
              service: _friendService,
              isDark: isDark,
            ),
            const SizedBox(height: NeoTheme.spaceLg),
            _ActivityFeedSection(
              service: _friendService,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(String uid, String nick) async {
    final isDark = context.isDark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
          side: BorderSide(
            color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
            width: NeoTheme.borderWidth,
          ),
        ),
        title: const Text(Strings.removeFriendConfirm),
        content: Text(nick),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(Strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonPink,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(Strings.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _friendService.removeFriend(uid);
    } catch (_) {
      if (mounted) showErrorSnack(context, 'Chyba při odstraňování.');
    }
  }
}

class _FriendCard extends StatelessWidget {
  final int rank;
  final String uid;
  final String nickname;
  final int weeklyXp;
  final int streak;
  final bool isDark;
  final VoidCallback onRemove;

  const _FriendCard({
    required this.rank,
    required this.uid,
    required this.nickname,
    required this.weeklyXp,
    required this.streak,
    required this.isDark,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/friend-profile?uid=$uid'),
      onLongPress: onRemove,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(
            horizontal: NeoTheme.spaceMd, vertical: NeoTheme.spaceSm + 2),
        decoration: NeoTheme.cardDecoration(isDark: isDark),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: context.primaryColor,
              child: Text(
                nickname.isEmpty ? '?' : nickname[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: NeoTheme.spaceSm),
            // Level badge — falls back to "1" while the per-friend user doc
            // is loading. Stream is cheap (single-doc snapshot) and updates
            // live so a friend levelling up while you watch is visible.
            _FriendLevelBadge(uid: uid),
            const SizedBox(width: NeoTheme.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nickname,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      StreakFlame(streak: streak, size: 12),
                      const SizedBox(width: 3),
                      Text('$streak',
                          style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '· $weeklyXp ${Strings.xpThisWeekShort}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textSecondary
                                : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Rank-1 trophy instead of the plain "1." text.
            rank == 1
                ? const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.neonYellow,
                    size: 18,
                  )
                : Text(
                    '$rank.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.textSecondary
                          : Colors.black54,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Single-doc stream of `users/{uid}.level`, rendered as a [LevelBadge].
/// While loading we show a "1" badge so the row layout doesn't jump when
/// the snapshot arrives.
class _FriendLevelBadge extends StatelessWidget {
  final String uid;
  const _FriendLevelBadge({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        int level = 1;
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data();
          if (data != null) {
            // Prefer the stored level field, fall back to xp-derived value
            // for any historical docs that never got a level write.
            final stored = data['level'] as int?;
            if (stored != null) {
              level = stored;
            } else {
              final xp = (data['xp'] as int?) ?? 0;
              level = (xp ~/ 100) + 1;
            }
          }
        }
        return LevelBadge(level: level);
      },
    );
  }
}

class _OwnHeader extends StatelessWidget {
  final FriendProfile profile;
  final bool isDark;
  const _OwnHeader({required this.profile, required this.isDark});

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
              const SizedBox(width: NeoTheme.spaceMd),
              const Icon(Icons.monetization_on_rounded,
                  color: AppColors.neonYellow, size: 16),
              const SizedBox(width: 4),
              Text(
                '${profile.coins}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neonYellow,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityFeedSection extends StatelessWidget {
  final FriendService service;
  final bool isDark;
  const _ActivityFeedSection({required this.service, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ActivityFeedItem>>(
      stream: service.activityFeedStream(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final items = snap.data!;
        // Hide the whole section if user has no friends (parent already
        // shows "noFriendsYet" hint above).
        // We can't know that from here directly, but an empty feed AND no
        // friends share the same emission shape; surface a friendly empty
        // state when items is empty so the section still renders for
        // friends-with-no-achievements case.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Strings.friendActivityHeader,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: isDark ? AppColors.textSecondary : Colors.black54,
              ),
            ),
            const SizedBox(height: NeoTheme.spaceSm),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: NeoTheme.spaceMd),
                child: Text(
                  Strings.friendActivityEmpty,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AppColors.textSecondary : Colors.black54,
                  ),
                ),
              )
            else
              ...items.map((it) => _ActivityFeedRow(item: it, isDark: isDark)),
          ],
        );
      },
    );
  }
}

class _ActivityFeedRow extends StatelessWidget {
  final ActivityFeedItem item;
  final bool isDark;
  const _ActivityFeedRow({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final ach = Achievements.byId(item.achievementId);
    final color = ach?.color ?? AppColors.neonYellow;
    final iconData = ach?.icon ?? Icons.emoji_events_rounded;
    final achTitle = ach?.title ?? item.achievementId;
    final nick = item.friendNickname.isEmpty ? '—' : item.friendNickname;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/friend-profile?uid=${item.friendUid}',
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(
            horizontal: NeoTheme.spaceMd, vertical: NeoTheme.spaceSm + 2),
        decoration: NeoTheme.cardDecoration(isDark: isDark),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                border: Border.all(color: color, width: NeoTheme.borderWidthThin),
              ),
              child: Icon(iconData, color: color, size: 18),
            ),
            const SizedBox(width: NeoTheme.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style.copyWith(
                            fontSize: 14,
                          ),
                      children: [
                        TextSpan(
                          text: nick,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(text: ' ${Strings.friendActivityUnlocked(achTitle)}'),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    relativeTimeCs(item.unlockedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textSecondary : Colors.black45,
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

class _LastWeekWinnerSection extends StatefulWidget {
  final FriendService service;
  final bool isDark;
  const _LastWeekWinnerSection({required this.service, required this.isDark});

  @override
  State<_LastWeekWinnerSection> createState() =>
      _LastWeekWinnerSectionState();
}

class _LastWeekWinnerSectionState extends State<_LastWeekWinnerSection> {
  WeeklyWinner? _winner;
  bool _loaded = false;
  String? _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _load();
  }

  Future<void> _load() async {
    try {
      final w = await widget.service.fetchOrCreateLastWeekSnapshot();
      if (!mounted) return;
      setState(() {
        _winner = w;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final w = _winner;
    if (w == null) return const SizedBox.shrink();
    final isDark = widget.isDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Strings.lastWeekHeader,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: isDark ? AppColors.textSecondary : Colors.black54,
          ),
        ),
        const SizedBox(height: NeoTheme.spaceSm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: NeoTheme.spaceMd,
            vertical: NeoTheme.spaceMd,
          ),
          decoration: NeoTheme.cardDecoration(isDark: isDark),
          child: w.nobodyWon
              ? Text(
                  Strings.lastWeekNobody,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AppColors.textSecondary : Colors.black54,
                  ),
                )
              : Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.neonYellow,
                      size: 22,
                    ),
                    const SizedBox(width: NeoTheme.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Strings.lastWeekWinnerLine(
                                w.winnerNickname.isEmpty ? '—' : w.winnerNickname,
                                w.winnerXp),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: w.winnerUid == _myUid
                                  ? context.primaryColor
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Strings.lastWeekYourScore(w.myXp),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondary
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
