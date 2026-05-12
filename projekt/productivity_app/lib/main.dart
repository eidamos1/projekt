import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'models/achievement.dart';
import 'services/task_service.dart';
import 'services/achievement_service.dart';
import 'pages/login.dart';
import 'pages/calendar_page.dart';
import 'pages/confirm_task.dart';
import 'pages/settings.dart';
import 'pages/stats_page.dart';
import 'pages/notifications_page.dart';
import 'pages/habits_page.dart';
import 'constants/app_colors.dart';
import 'constants/neo_theme.dart';
import 'constants/layout.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('cs');

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
  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<Map<String, dynamic>>>? _notifSub;
  int _lastNotifSeen = -1;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _hookAchievementTrigger();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _notifSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  /// Listen to the notif stream and fire AchievementService.evaluate() when
  /// the list grows (new notification arrived). Resubscribes on auth changes
  /// because notificationsStream() requires a logged-in user.
  void _hookAchievementTrigger() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _notifSub?.cancel();
      _notifSub = null;
      _lastNotifSeen = -1;
      if (user == null) return;
      try {
        _notifSub = TaskService().notificationsStream().listen((notifs) {
          if (_lastNotifSeen < 0) {
            _lastNotifSeen = notifs.length;
            return;
          }
          if (notifs.length > _lastNotifSeen) {
            _lastNotifSeen = notifs.length;
            AchievementService()
                .evaluate()
                .catchError((_) => <Achievement>[]);
          } else {
            _lastNotifSeen = notifs.length;
          }
        }, onError: (_) {});
      } catch (_) {
        // Stream construction failed (e.g. transient auth state) — silently
        // skip; we'll get another authStateChanges tick.
      }
    });
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.primaryColor,
          brightness: Brightness.light,
        ).copyWith(primary: themeProvider.primaryColor),
        scaffoldBackgroundColor: AppColors.scaffoldLight,
        cardColor: AppColors.cardLight,
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: _NeoPageTransitionsBuilder(),
          TargetPlatform.iOS: _NeoPageTransitionsBuilder(),
          TargetPlatform.linux: _NeoPageTransitionsBuilder(),
          TargetPlatform.macOS: _NeoPageTransitionsBuilder(),
          TargetPlatform.windows: _NeoPageTransitionsBuilder(),
        }),
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.primaryColor,
          brightness: Brightness.dark,
        ).copyWith(primary: themeProvider.primaryColor),
        scaffoldBackgroundColor: AppColors.scaffoldDark,
        cardColor: AppColors.cardDark,
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: _NeoPageTransitionsBuilder(),
          TargetPlatform.iOS: _NeoPageTransitionsBuilder(),
          TargetPlatform.linux: _NeoPageTransitionsBuilder(),
          TargetPlatform.macOS: _NeoPageTransitionsBuilder(),
          TargetPlatform.windows: _NeoPageTransitionsBuilder(),
        }),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.cardDark,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: Border(
            bottom: BorderSide(
              color: themeProvider.primaryColor,
              width: NeoTheme.borderWidth,
            ),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          elevation: 0,
          backgroundColor: themeProvider.primaryColor,
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
        '/habits': (context) => const HabitsPage(),
      },
    );
  }
}

/// Snappy slide-from-right transition (180ms, easeOutCubic) used on every
/// platform — Material's default fade-and-slide felt too soft for the neo
/// aesthetic, and Flutter web has no transition by default.
class _NeoPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NeoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.05, 0),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(opacity: curved, child: child),
    );
  }
}
