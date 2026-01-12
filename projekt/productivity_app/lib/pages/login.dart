import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart' as google_lib;
// 2. Import pro detekci Webu
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nicknameController = TextEditingController(); // Pro přezdívku
  bool isLogin = true;

  void _toggleForm() => setState(() => isLogin = !isLogin);

  // Google Přihlášení
Future<void> _signInWithGoogle() async {
    try {
      // 1. Konfigurace pro Web (clientId je nutné pro verzi 7.x)
      // Na Androidu/iOS se clientId ignoruje (bere se z google-services.json)
      final google_lib.GoogleSignIn googleSignIn = google_lib.GoogleSignIn(
        clientId: kIsWeb 
            ? "TVOJE-WEB-CLIENT-ID.apps.googleusercontent.com" // ZDE VLOŽ ID Z FIREBASE
            : null,
      );

      // 2. Spuštění přihlašovacího procesu
      // Ve verzi 7.x je metoda stále .signIn()
      final google_lib.GoogleSignInAccount? googleUser = await googleSignIn.authenticate();

      if (googleUser == null) {
        return; // Uživatel zavřel okno
      }

      // 3. Získání tokenů (Authentication)
      final google_lib.GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 4. Vytvoření přihlašovacích údajů pro Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.idToken,
        idToken: googleAuth.idToken,
      );

      // 5. Přihlášení do Firebase
      UserCredential userCred = await _auth.signInWithCredential(credential);

      // 6. Kontrola/Vytvoření uživatele v databázi (tvůj původní kód)
      final userDoc = await _firestore.collection('users').doc(userCred.user!.uid).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(userCred.user!.uid).set({
          'nickname': googleUser.displayName ?? 'Hráč',
          'xp': 0,
          'coins': 0,
          'level': 1,
        });
      }

      if (mounted) Navigator.pushReplacementNamed(context, '/calendar');

    } catch (e) {
      print("CHYBA Google Login: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: $e')));
      }
    }
  }

  // Email/Heslo Přihlášení
  Future<void> _submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final nickname = nicknameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!isLogin && nickname.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vyplňte všechna pole')));
      return;
    }

    try {
      if (isLogin) {
        await _auth.signInWithEmailAndPassword(email: email, password: password);
      } else {
        UserCredential cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
        // Uložení přezdívky při registraci
        await _firestore.collection('users').doc(cred.user!.uid).set({
          'nickname': nickname,
          'xp': 0, 'coins': 0, 'level': 1,
        });
      }
      if (mounted) Navigator.pushReplacementNamed(context, '/calendar');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Chyba')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Přihlášení' : 'Registrace')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            if (!isLogin) ...[
              TextField(
                controller: nicknameController,
                decoration: InputDecoration(labelText: 'Tvoje přezdívka'),
              ),
              SizedBox(height: 10),
            ],
            TextField(controller: emailController, decoration: InputDecoration(labelText: 'E-mail')),
            TextField(controller: passwordController, decoration: InputDecoration(labelText: 'Heslo'), obscureText: true),
            SizedBox(height: 20),
            ElevatedButton(onPressed: _submit, child: Text(isLogin ? 'Přihlásit' : 'Registrovat')),
            SizedBox(height: 10),
            OutlinedButton.icon(
              icon: Icon(Icons.login),
              label: Text('Google Přihlášení'),
              onPressed: _signInWithGoogle,
            ),
            TextButton(
              onPressed: _toggleForm,
              child: Text(isLogin ? 'Nemáš účet? Registrace' : 'Máš účet? Přihlášení'),
            ),
          ],
        ),
      ),
    );
  }
}
