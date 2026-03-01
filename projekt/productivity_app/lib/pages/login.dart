import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authService = AuthService();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nicknameController = TextEditingController();
  bool isLogin = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nicknameController.dispose();
    super.dispose();
  }

  void _toggleForm() => setState(() => isLogin = !isLogin);

  Future<void> _signInWithGoogle() async {
    try {
      await _authService.signInWithGoogle();
      if (mounted) Navigator.pushReplacementNamed(context, '/calendar');
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Prihlaseni selhalo: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final nickname = nicknameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!isLogin && nickname.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vyplnte vsechna pole')),
      );
      return;
    }

    try {
      if (isLogin) {
        await _authService.signInWithEmail(email, password);
      } else {
        await _authService.registerWithEmail(email, password, nickname);
      }
      if (mounted) Navigator.pushReplacementNamed(context, '/calendar');
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Chyba prihlaseni')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Prihlaseni' : 'Registrace')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!isLogin) ...[
              TextField(
                controller: nicknameController,
                decoration: const InputDecoration(labelText: 'Tvoje prezdivka'),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Heslo'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              child: Text(isLogin ? 'Prihlasit' : 'Registrovat'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Google Prihlaseni'),
              onPressed: _signInWithGoogle,
            ),
            TextButton(
              onPressed: _toggleForm,
              child: Text(isLogin
                  ? 'Nemas ucet? Registrace'
                  : 'Mas ucet? Prihlaseni'),
            ),
          ],
        ),
      ),
    );
  }
}
