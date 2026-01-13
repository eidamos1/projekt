import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
      // 1. Konfigurace (zejména pro Web)
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb
            ? "863209070202-ugd71j1mrv9nohbht9puakbr7991ccvv.apps.googleusercontent.com"
            : null,
      );

      // 2. Spuštění přihlášení (ve verzi 6.x používáme signIn)
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        return; // Uživatel zavřel okno bez přihlášení
      }

      // 3. Získání tokenů
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 4. Vytvoření credential pro Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 5. Přihlášení do Firebase
      UserCredential userCred = await _auth.signInWithCredential(credential);

      await _firestore.collection('users').doc(userCred.user!.uid).set({
        'nickname': googleUser.displayName ?? 'Hráč',
        'photoUrl': googleUser.photoUrl, // Tady se ukládá odkaz na Google fotku
      }, SetOptions(merge: true));

      // 6. Kontrola/Vytvoření uživatele ve Firestore
      final userDoc = await _firestore.collection('users').doc(userCred.user!.uid).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(userCred.user!.uid).set({
          'xp': 0,
          'coins': 0,
          'level': 1,
        });
      }

      // 7. Přesměrování do aplikace
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/calendar');
      }

    } catch (e) {
      print("CHYBA Google Login: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Přihlášení selhalo: $e')),
        );
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
