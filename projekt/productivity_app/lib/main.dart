import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'pages/login.dart';
import 'pages/calendar_page.dart';
import 'pages/confirm_task.dart';
import 'pages/settings.dart';
import 'pages/stats_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final themeProvider = ThemeProvider();
  await themeProvider.loadPreference();

  runApp(
    ChangeNotifierProvider.value(
      value: themeProvider,
      child: const MyApp(),
    ),
  );
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;

  bool get isDarkMode => themeMode == ThemeMode.dark;

  Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('themeMode');
    if (saved == 'dark') {
      themeMode = ThemeMode.dark;
    } else if (saved == 'light') {
      themeMode = ThemeMode.light;
    }
  }

  void toggleTheme(bool isOn) async {
    themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', isOn ? 'dark' : 'light');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final Uri? initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleLink(initialLink);
      }
    } catch (_) {}

    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) _handleLink(uri);
    });
  }

  void _handleLink(Uri uri) {
    String? code = uri.queryParameters['code'];

    // Zkontrolujeme, jestli je to nas odkaz pro potvrzeni
    if (uri.host == 'confirm' && code != null) {
      Future.delayed(const Duration(seconds: 1), () {
        navigatorKey.currentState?.pushNamed('/confirm', arguments: code);
      });
      return;
    }

    // Web s fragment (#)
    if (code == null && uri.fragment.isNotEmpty) {
      try {
        final fragmentUri = Uri.parse('dummy://dummy/${uri.fragment}');
        code = fragmentUri.queryParameters['code'];
      } catch (_) {}
    }

    bool isConfirmPage = uri.host == 'confirm' ||
        uri.path.contains('confirm') ||
        uri.fragment.contains('confirm');

    if (isConfirmPage && code != null) {
      Future.delayed(const Duration(seconds: 1), () {
        navigatorKey.currentState?.pushNamed('/confirm', arguments: code);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Motivator',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[50],
        cardColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black87),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/calendar': (context) => const CalendarPage(),
        '/confirm': (context) => const ConfirmTaskPage(),
        '/settings': (context) => const SettingsPage(),
        '/stats': (context) => const StatsPage(),
      },
    );
  }
}
