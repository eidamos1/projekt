import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../main.dart'; // Import pro ThemeProvider

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // Logika pro smazání účtu
  Future<void> _deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Varování před smazáním
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Smazat účet?'),
        content: Text('Tato akce je nevratná. Přijdete o všechny úkoly, XP a mince.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Zrušit')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text('SMAZAT NAVŽDY'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      // 1. Smazat data z Firestore (úkoly)
      final tasks = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .get();
      
      for (var doc in tasks.docs) {
        await doc.reference.delete();
      }

      // 2. Smazat uživatele z Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();

      // 3. Smazat Authentication účet
      await user.delete();

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Účet byl úspěšně smazán.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba mazání: $e. Zkuste se odhlásit a znovu přihlásit.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Nastavení')),
      body: ListView(
        children: [
          // Sekce Vzhled
          ListTile(
            leading: Icon(Icons.dark_mode),
            title: Text('Tmavý režim'),
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme(value);
              },
            ),
          ),
          Divider(),
          
          // Sekce Účet
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red),
            title: Text('Smazat účet', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            subtitle: Text('Kompletně odstraní všechna data'),
            onTap: () => _deleteAccount(context),
          ),
        ],
      ),
    );
  }
}