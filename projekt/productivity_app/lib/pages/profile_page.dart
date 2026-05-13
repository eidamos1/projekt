import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../services/friend_service.dart';
import '../utils/context_extensions.dart';
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
            // Phase 3 will add: friend list below
          ],
        ),
      ),
    );
  }
}
