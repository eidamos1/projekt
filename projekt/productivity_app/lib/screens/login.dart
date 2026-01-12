// pages/login.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  bool isLogin = true; // Přepínač mezi přihlášením a registrací

  void _toggleForm() {
    setState(() {
      isLogin = !isLogin;
    });
  }

  Future<void> _submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zadejte prosím e-mail i heslo')));
      return;
    }

    try {
      if (isLogin) {
        // Přihlášení existujícího uživatele
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password
        );

      } 
      else
        {
        // Registrace nového uživatele
        UserCredential cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password
        );

        // Vytvoří dokument uživatele ve Firestore s hodnotami
        await _firestore.collection('users').doc(cred.user!.uid).set({
          'xp': 0,
          'coins': 0,
          'level': 1,
        });
      }
      
      // Po úspěšném přihlášení/registraci přejdeme na kalendářovou stránku
      Navigator.pushReplacementNamed(context, '/calendar');
    } on FirebaseAuthException catch (e) {
      // Zpracování chyb Firebase Auth
      String msg = 'Něco se pokazilo: ${e.message}';
      if (e.code == 'weak-password') {
        msg = 'Heslo je příliš slabé.';
      } else if (e.code == 'email-already-in-use') {
        msg = 'Uživatel s tímto e-mailem již existuje.';
      } else if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        msg = 'Špatný e-mail nebo heslo.';
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Přihlášení' : 'Registrace')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // E-mail
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'E-mail'),
            ),
            // Heslo
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Heslo'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            // Tlačítko přihlášení/registrace
            ElevatedButton(
              onPressed: _submit,
              child: Text(isLogin ? 'Přihlásit' : 'Registrovat'),
            ),
            TextButton(
              onPressed: _toggleForm,
              child: Text(isLogin
                  ? 'Nemáte účet? Zaregistrujte se'
                  : 'Máte účet? Přihlaste se'),
            ),
          ],
        ),
      ),
    );
  }
}

