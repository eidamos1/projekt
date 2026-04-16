import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'pages/login.dart';
import 'pages/calendar_page.dart';
import 'pages/confirm_task.dart';
import 'pages/settings.dart';
import 'pages/stats_page.dart';
import 'pages/notifications_page.dart';
import 'constants/app_colors.dart';
import 'constants/neo_theme.dart';
import 'constants/layout.dart';

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
  LayoutMode layoutMode = LayoutMode.compact;
  Color primaryColor = AppColors.neonGreen;

  bool get isDarkMode => themeMode == ThemeMode.dark;
  bool get isCompactMode => layoutMode == LayoutMode.compact;

  Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('themeMode');
    if (saved == 'dark') {
      themeMode = ThemeMode.dark;
    } else if (saved == 'light') {
      themeMode = ThemeMode.light;
    }

    final savedLayout = prefs.getString('layoutMode');
    if (savedLayout == 'spread') {
      layoutMode = LayoutMode.spread;
    }

    final savedColor = prefs.getInt('primaryColor');
    if (savedColor != null) {
      primaryColor = Color(savedColor);
    }
  }

  void toggleTheme(bool isOn) async {
    themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', isOn ? 'dark' : 'light');
  }

  void setLayoutMode(LayoutMode mode) async {
    layoutMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('layoutMode', mode == LayoutMode.spread ? 'spread' : 'compact');
  }

  void setPrimaryColor(Color color) async {
    primaryColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primaryColor', color.toARGB32());
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

    if (uri.host == 'confirm' && code != null) {
      Future.delayed(const Duration(seconds: 1), () {
        navigatorKey.currentState?.pushNamed('/confirm', arguments: code);
      });
      return;
    }

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
        colorSchemeSeed: themeProvider.primaryColor,
        scaffoldBackgroundColor: AppColors.scaffoldLight,
        cardColor: AppColors.cardLight,
        appBarTheme: AppBarTheme(
          backgroundColor: themeProvider.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          elevation: 0,
          backgroundColor: themeProvider.primaryColor,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
            side: const BorderSide(color: AppColors.borderBold, width: NeoTheme.borderWidth),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
            borderSide: const BorderSide(color: AppColors.borderBold, width: NeoTheme.borderWidth),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
            borderSide: const BorderSide(color: AppColors.borderBold, width: NeoTheme.borderWidth),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
            borderSide: BorderSide(color: themeProvider.primaryColor, width: NeoTheme.borderWidth),
          ),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
            side: const BorderSide(color: AppColors.borderBold, width: NeoTheme.borderWidth),
          ),
        ),
        textTheme: GoogleFonts.spaceGroteskTextTheme(
          const TextTheme(
            bodyLarge: TextStyle(color: Colors.black87),
            bodyMedium: TextStyle(color: Colors.black54),
          ),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: themeProvider.primaryColor,
        scaffoldBackgroundColor: AppColors.scaffoldDark,
        cardColor: AppColors.cardDark,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.cardDark,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: const Border(
            bottom: BorderSide(color: AppColors.borderSubtle, width: NeoTheme.borderWidth),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          elevation: 0,
          backgroundColor: AppColors.neonGreen,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
            side: const BorderSide(color: Colors.white, width: NeoTheme.borderWidth),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.scaffoldDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
            borderSide: const BorderSide(color: AppColors.borderSubtle, width: NeoTheme.borderWidth),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
            borderSide: const BorderSide(color: AppColors.borderSubtle, width: NeoTheme.borderWidth),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
            borderSide: BorderSide(color: themeProvider.primaryColor, width: NeoTheme.borderWidth),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
            side: const BorderSide(color: AppColors.borderSubtle, width: NeoTheme.borderWidth),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
            side: const BorderSide(color: AppColors.borderSubtle, width: NeoTheme.borderWidth),
          ),
        ),
        textTheme: GoogleFonts.spaceGroteskTextTheme(
          const TextTheme(
            bodyLarge: TextStyle(color: AppColors.textPrimary),
            bodyMedium: TextStyle(color: AppColors.textSecondary),
            headlineMedium: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
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
        '/notifications': (context) => const NotificationsPage(),
      },
    );
  }
}
