import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/auth_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _deleteAccount(BuildContext context) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Smazat ucet?'),
            content: const Text(
                'Tato akce je nevratna. Prijdete o vsechny ukoly, XP a mince.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Zrusit'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('SMAZAT NAVZDY'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ucet byl uspesne smazan.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Chyba mazani. Zkuste se odhlasit a znovu prihlasit.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nastaveni')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Tmavy rezim'),
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) => themeProvider.toggleTheme(value),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Smazat ucet',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
            subtitle: const Text('Kompletne odstrani vsechna data'),
            onTap: () => _deleteAccount(context),
          ),
        ],
      ),
    );
  }
}
