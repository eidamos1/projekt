import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/layout.dart';
import '../constants/strings.dart';
import '../utils/context_extensions.dart';
import '../utils/ui_helpers.dart';
import '../widgets/responsive_layout.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _userService = UserService();

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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.settings)),
      body: ResponsiveLayout(
        child: ListView(
          children: [
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
            ListTile(
              leading: const Icon(Icons.view_compact_outlined),
              title: const Text(Strings.layoutMode),
              trailing: SegmentedButton<LayoutMode>(
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
            // Delete account
            ListTile(
              leading: const Icon(Icons.delete_forever, color: AppColors.neonPink),
              title: const Text(Strings.deleteAccountAction,
                  style: TextStyle(
                      color: AppColors.neonPink, fontWeight: FontWeight.bold)),
              subtitle: const Text(Strings.deleteAccountSubtitle),
              onTap: () => _deleteAccount(context),
            ),
          ],
        ),
      ),
    );
  }
}
