import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../utils/context_extensions.dart';
import '../utils/ui_helpers.dart';
import '../widgets/responsive_layout.dart';

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
        showErrorSnack(context, '${Strings.loginError}: $e');
      }
    }
  }

  Future<void> _submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final nickname = nicknameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!isLogin && nickname.isEmpty)) {
      showErrorSnack(context, Strings.fillAllFields);
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
        showErrorSnack(context, e.message ?? Strings.loginError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(
          title: Text(isLogin ? Strings.login : Strings.register)),
      body: ResponsiveLayout(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!isLogin) ...[
              TextField(
                controller: nicknameController,
                decoration:
                    const InputDecoration(labelText: Strings.nicknameLabel),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: emailController,
              decoration:
                  const InputDecoration(labelText: Strings.emailLabel),
            ),
            TextField(
              controller: passwordController,
              decoration:
                  const InputDecoration(labelText: Strings.passwordLabel),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            // Main login/register button — neon green
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: NeoTheme.buttonDecoration(
                  backgroundColor: context.primaryColor,
                  borderColor: Colors.white,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
                    onTap: _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          isLogin ? Strings.loginButton : Strings.registerButton,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Google sign-in — outlined with border
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text(Strings.googleLogin),
                onPressed: _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
                    width: NeoTheme.borderWidth,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            TextButton(
              onPressed: _toggleForm,
              child: Text(
                isLogin ? Strings.noAccountPrompt : Strings.hasAccountPrompt,
                style: const TextStyle(color: AppColors.neonCyan),
              ),
            ),
          ],
        ),
          ),
        ),
    );
  }
}
