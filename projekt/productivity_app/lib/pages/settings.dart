import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../services/auth_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> _toggleNotifications(bool value) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).update({
      'notificationsEnabled': value,
    });
  }

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
    final uid = _auth.currentUser?.uid;

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
          if (uid != null)
            StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('users').doc(uid).snapshots(),
              builder: (context, snapshot) {
                bool notifEnabled = true;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  notifEnabled = data['notificationsEnabled'] ?? true;
                }
                return ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notifikace'),
                  subtitle: const Text('Prijmat notifikace pri potvrzeni/odmiteni ukolu'),
                  trailing: Switch(
                    value: notifEnabled,
                    onChanged: (value) => _toggleNotifications(value),
                  ),
                );
              },
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
