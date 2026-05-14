import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../models/friend_rank.dart';
import '../services/friend_service.dart';
import '../utils/context_extensions.dart';
import '../utils/ui_helpers.dart';
import '../widgets/responsive_layout.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _friendService = FriendService();
  String? _inviteCode;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInvite();
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

  Future<void> _shareInvite() async {
    if (_inviteCode == null) return;
    final url = 'https://calendar-mot.web.app/#/friend?code=$_inviteCode';
    await SharePlus.instance.share(
      ShareParams(text: '${Strings.inviteShareText}$url'),
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _shareInvite,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text(Strings.shareInvite),
                  ),
                ),
                const SizedBox(width: NeoTheme.spaceSm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _regenerate,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(Strings.regenerateInvite),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NeoTheme.spaceLg),
            Text(
              Strings.friendsHeader,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: isDark ? AppColors.textSecondary : Colors.black54,
              ),
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
            const SizedBox(width: NeoTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nickname,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          size: 12, color: AppColors.neonPink),
                      const SizedBox(width: 3),
                      Text('$streak',
                          style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 8),
                      Text(
                        '· $weeklyXp ${Strings.xpThisWeekShort}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textSecondary
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '$rank.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textSecondary : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
