import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  final bool isDark;
  final void Function(bool) onToggle;
  const SettingsPage({super.key, required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              value: isDark,
              onChanged: onToggle,
              title: const Text('Dark mode'),
            ),
            const SizedBox(height: 8),
            const Text('Share/confirm via code or full link (copy to clipboard).'),
          ],
        ),
      ),
    );
  }
}
