import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../services/achievement_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/web_notification_service.dart';
import '../constants/achievements.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/layout.dart';
import '../constants/strings.dart';
import '../utils/context_extensions.dart';
import '../utils/ui_helpers.dart';
import '../widgets/neo_bottom_nav.dart';
import '../widgets/neo_bottom_sheet.dart';
import '../widgets/onboarding_tour.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/title_chip.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _userService = UserService();

  Future<void> _editNickname(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final isDark = context.isDark;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
          side: BorderSide(
            color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
            width: NeoTheme.borderWidth,
          ),
        ),
        title: const Text(Strings.changeNicknameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: InputDecoration(
            labelText: Strings.nicknameSetting,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(Strings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text(Strings.save),
          ),
        ],
      ),
    );
    if (result == null || result == current) return;
    if (result.length < 2) {
      if (context.mounted) showErrorSnack(context, Strings.nicknameTooShort);
      return;
    }
    try {
      await _userService.updateNickname(result);
      if (context.mounted) showSuccessSnack(context, Strings.nicknameUpdated);
    } catch (_) {
      if (context.mounted) {
        showErrorSnack(context, Strings.nicknameUpdateError);
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
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
        title: const Text(Strings.logoutAction),
        content: const Text(Strings.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(Strings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(Strings.logoutAction),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AuthService().signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  void _showAbout(BuildContext context) {
    final isDark = context.isDark;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
          side: BorderSide(
            color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
            width: NeoTheme.borderWidth,
          ),
        ),
        title: const Text(Strings.aboutAppTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Strings.appName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: context.primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${Strings.aboutAppVersion} 1.0.0',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: isDark ? AppColors.textSecondary : Colors.black54,
              ),
            ),
            const SizedBox(height: NeoTheme.spaceMd),
            const Text(Strings.aboutAppCopy),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(Strings.confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final isDark = context.isDark;
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
              side: BorderSide(
                color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
                width: NeoTheme.borderWidth,
              ),
            ),
            title: const Text(Strings.deleteAccount),
            content: const Text(Strings.deleteAccountWarning),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(Strings.cancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonPink,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(Strings.deleteAccountButton),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await AuthService().deleteAccount();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        showSuccessSnack(context, Strings.accountDeleted);
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnack(context, Strings.accountDeleteError);
      }
    }
  }

  void _openTitleSheet(BuildContext context) {
    showNeoBottomSheet<void>(
      context: context,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NeoTheme.spaceLg,
            NeoTheme.spaceMd,
            NeoTheme.spaceLg,
            NeoTheme.spaceLg,
          ),
          child: ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: const Text(
              Strings.achievementOpenStats,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/stats');
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.settings)),
      body: ResponsiveLayout(
        child: ListView(
          children: [
            // Active title chip
            StreamBuilder<String?>(
              stream: AchievementService().activeTitleStream(),
              builder: (context, snapshot) {
                final id = snapshot.data;
                if (id == null) return const SizedBox.shrink();
                final ach = Achievements.byId(id);
                if (ach == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Strings.achievementYourTitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: context.isDark
                              ? AppColors.textSecondary
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TitleChip(
                        achievement: ach,
                        onTap: () => _openTitleSheet(context),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Nickname (live from user doc)
            StreamBuilder<DocumentSnapshot>(
              stream: _userService.profileStream(),
              builder: (context, snap) {
                String nickname = '...';
                if (snap.hasData && snap.data!.exists) {
                  final data = snap.data!.data() as Map<String, dynamic>?;
                  nickname = (data?['nickname'] as String?) ?? '';
                }
                return ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text(Strings.nicknameSetting),
                  subtitle: Text(nickname.isEmpty ? '—' : nickname),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: nickname.isEmpty
                      ? null
                      : () => _editNickname(context, nickname),
                );
              },
            ),
            const Divider(),
            // Dark mode
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text(Strings.darkMode),
              trailing: Switch(
                value: themeProvider.isDarkMode,
                onChanged: (value) => themeProvider.toggleTheme(value),
              ),
            ),
            const Divider(),
            // Layout mode
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.view_compact_outlined),
                      const SizedBox(width: 16),
                      const Text(Strings.layoutMode,
                          style: TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<LayoutMode>(
                      segments: const [
                        ButtonSegment(
                          value: LayoutMode.compact,
                          label: Text(Strings.layoutCompact),
                          icon: Icon(Icons.view_compact_outlined),
                        ),
                        ButtonSegment(
                          value: LayoutMode.spread,
                          label: Text(Strings.layoutSpread),
                          icon: Icon(Icons.width_full_outlined),
                        ),
                      ],
                      selected: {themeProvider.layoutMode},
                      onSelectionChanged: (selection) {
                        themeProvider.setLayoutMode(selection.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Color theme
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.palette_outlined),
                      const SizedBox(width: 16),
                      const Text(
                        Strings.colorTheme,
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: AppColors.themeOptions.map((option) {
                      final isSelected =
                          themeProvider.primaryColor.toARGB32() ==
                              option.color.toARGB32();
                      return GestureDetector(
                        onTap: () => themeProvider.setPrimaryColor(option.color),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: option.color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? AppColors.borderSubtle
                                          : AppColors.borderBold),
                                  width: isSelected ? 3 : NeoTheme.borderWidth,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: option.color.withValues(alpha: 0.4),
                                    offset: NeoTheme.shadowOffsetSmall,
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 22)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              option.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Notifications
            StreamBuilder<DocumentSnapshot>(
              stream: _userService.notificationsSettingStream(),
              builder: (context, snapshot) {
                bool notifEnabled = true;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  notifEnabled = data['notificationsEnabled'] ?? true;
                }
                return ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text(Strings.notificationsTitle),
                  subtitle: const Text(Strings.notificationsSubtitle),
                  trailing: Switch(
                    value: notifEnabled,
                    onChanged: (value) =>
                        _userService.toggleNotifications(value),
                  ),
                );
              },
            ),
            const Divider(),
            // Browser web notifications (foreground-only)
            const _BrowserNotifTile(),
            const Divider(),
            // Discoverable (search-by-nickname opt-in)
            StreamBuilder<DocumentSnapshot>(
              stream: _userService.notificationsSettingStream(),
              builder: (context, snapshot) {
                bool discoverable = false;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  discoverable = data['discoverable'] ?? false;
                }
                return ListTile(
                  leading: const Icon(Icons.search_rounded),
                  title: const Text(Strings.discoverableTitle),
                  subtitle: const Text(Strings.discoverableSubtitle),
                  trailing: Switch(
                    value: discoverable,
                    onChanged: (value) => _userService.setDiscoverable(value),
                  ),
                );
              },
            ),
            const Divider(),
            // Habits
            ListTile(
              leading: const Icon(Icons.autorenew_rounded),
              title: const Text(Strings.habitsMine),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/habits'),
            ),
            const Divider(),
            // How it works — replay the first-run guide
            ListTile(
              leading: const Icon(Icons.explore_outlined),
              title: const Text(Strings.onboardingGuide),
              subtitle: const Text(Strings.onboardingGuideSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showOnboardingTour(context),
            ),
            const Divider(),
            // About app
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text(Strings.aboutAppTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAbout(context),
            ),
            const Divider(),
            // Logout
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text(Strings.logoutAction),
              subtitle: const Text(Strings.logoutSubtitle),
              onTap: () => _confirmLogout(context),
            ),
            const Divider(),
            // Delete account
            ListTile(
              leading: const Icon(Icons.delete_forever, color: AppColors.neonPink),
              title: const Text(Strings.deleteAccountAction,
                  style: TextStyle(
                      color: AppColors.neonPink, fontWeight: FontWeight.bold)),
              subtitle: const Text(Strings.deleteAccountSubtitle),
              onTap: () => _deleteAccount(context),
            ),
            const SizedBox(height: NeoTheme.spaceLg),
          ],
        ),
      ),
      bottomNavigationBar: const NeoBottomNav(currentIndex: 4),
    );
  }
}

class _BrowserNotifTile extends StatefulWidget {
  const _BrowserNotifTile();

  @override
  State<_BrowserNotifTile> createState() => _BrowserNotifTileState();
}

class _BrowserNotifTileState extends State<_BrowserNotifTile> {
  WebNotifPermission _state = WebNotifPermission.unsupported;

  @override
  void initState() {
    super.initState();
    _state = WebNotificationService().permission;
  }

  Future<void> _request() async {
    final next = await WebNotificationService().requestPermission();
    if (!mounted) return;
    setState(() => _state = next);
    if (next == WebNotifPermission.granted) {
      WebNotificationService().show(
        title: Strings.browserNotifTestTitle,
        body: Strings.browserNotifTestBody,
        tag: 'test-${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }

  String _subtitleFor(WebNotifPermission s) {
    switch (s) {
      case WebNotifPermission.granted:
        return Strings.browserNotifGranted;
      case WebNotifPermission.denied:
        return Strings.browserNotifDenied;
      case WebNotifPermission.defaultState:
        return Strings.browserNotifSubtitle;
      case WebNotifPermission.unsupported:
        return Strings.browserNotifUnsupported;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tappable = _state == WebNotifPermission.defaultState;
    return ListTile(
      leading: const Icon(Icons.web_asset_rounded),
      title: const Text(Strings.browserNotifTitle),
      subtitle: Text(_subtitleFor(_state)),
      trailing: tappable
          ? TextButton(
              onPressed: _request,
              child: const Text(Strings.browserNotifEnable),
            )
          : null,
      onTap: tappable ? _request : null,
    );
  }
}
