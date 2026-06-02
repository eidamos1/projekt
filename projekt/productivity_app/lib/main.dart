import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'services/web_notification_service.dart';
import 'pages/login.dart';
import 'pages/calendar_page.dart';
import 'pages/confirm_task.dart';
import 'pages/settings.dart';
import 'pages/stats_page.dart';
import 'pages/notifications_page.dart';
import 'pages/find_friends_page.dart';
import 'pages/habits_page.dart';
import 'pages/profile_page.dart';
import 'pages/friend_invite_screen.dart';
import 'pages/friend_profile_page.dart';
import 'widgets/achievement_unlock_toast.dart';
import 'constants/app_colors.dart';
import 'constants/neo_theme.dart';
import 'constants/layout.dart';
import 'utils/pending_deep_link.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Pushes a deep-link route once the root navigator is mounted. Replaces the
/// old fixed `Future.delayed(1s)` gamble — which silently dropped the link if
/// the navigator wasn't ready yet on a cold start — with a short bounded retry.
void pushDeepLinkWhenReady(String route, Object? args, [int attempt = 0]) {
  final nav = navigatorKey.currentState;
  if (nav != null) {
    nav.pushNamed(route, arguments: args);
  } else if (attempt < 20) {
    Future.delayed(const Duration(milliseconds: 150),
        () => pushDeepLinkWhenReady(route, args, attempt + 1));
  }
}

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
    AchievementService().newlyUnlocked.addListener(_handleUnlock);
  }

  @override
  void dispose() {
    AchievementService().newlyUnlocked.removeListener(_handleUnlock);
    _linkSubscription?.cancel();
    _notifSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  /// Shows the unlock toast for the most recent achievement in the batch and
  /// resets the ValueNotifier so a hot rebuild doesn't replay it. Earlier
  /// items in the same batch are still surfaced in the notifications feed —
  /// showing N back-to-back SnackBars would be noisy.
  void _handleUnlock() {
    final list = AchievementService().newlyUnlocked.value;
    if (list.isEmpty) return;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    showAchievementUnlockToast(ctx, list.last);
    AchievementService().newlyUnlocked.value = [];
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
      // Auto-login from cached creds doesn't go through login.dart's eval
      // trigger, so fire one here. Catches up missed unlocks (e.g. friend
      // confirmed a rejected→resubmitted task while we were offline).
      AchievementService().evaluate().catchError((e, s) {
        debugPrint('[ach-eval/auth-restore] $e\n$s');
        return <Achievement>[];
      });
      try {
        _notifSub = TaskService().notificationsStream().listen((notifs) {
          if (_lastNotifSeen < 0) {
            _lastNotifSeen = notifs.length;
            return;
          }
          if (notifs.length > _lastNotifSeen) {
            _lastNotifSeen = notifs.length;
            AchievementService().evaluate().catchError((e, s) {
              debugPrint('[ach-eval/notif-tick] $e\n$s');
              return <Achievement>[];
            });
            // Fire a browser-level Web Notification for the freshest item.
            // Foreground-only: no-op when permission isn't granted, when
            // running outside web, or when the user has muted the tab.
            if (notifs.isNotEmpty) {
              final latest = notifs.first;
              WebNotificationService().show(
                title: _browserNotifTitle(latest),
                body: _browserNotifBody(latest),
                tag: latest['id'] as String?,
                onClick: () => _routeFromNotif(latest),
              );
            }
          } else {
            _lastNotifSeen = notifs.length;
          }
        }, onError: (e, s) {
          debugPrint('[notif-stream] $e\n$s');
        });
      } catch (e, s) {
        // Stream construction failed (e.g. transient auth state) — silently
        // skip; we'll get another authStateChanges tick.
        debugPrint('[notif-stream-ctor] $e\n$s');
      }
    });
  }

  String _browserNotifTitle(Map<String, dynamic> n) {
    final type = n['type'];
    final nick = n['fromNickname'] as String? ?? '—';
    if (type == 'confirmed') return '$nick — úkol potvrzen';
    if (type == 'rejected') return '$nick — úkol zamítnut';
    if (type == 'achievement') return 'NOVÝ ÚSPĚCH';
    if (type == 'expiring') return 'Úkol vyprší zítra';
    if (type == 'friend_pending') return '$nick čeká na potvrzení';
    if (type == 'friend_added') return '$nick — nový kamarád';
    return 'MOTIVATOR';
  }

  String? _browserNotifBody(Map<String, dynamic> n) {
    final task = n['taskTitle'] as String?;
    if (task != null && task.isNotEmpty) return '"$task"';
    return null;
  }

  void _routeFromNotif(Map<String, dynamic> n) {
    final type = n['type'];
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    if (type == 'friend_pending') {
      final code = n['code'] as String?;
      if (code != null && code.isNotEmpty) {
        nav.pushNamed('/confirm', arguments: code);
        return;
      }
    }
    if (type == 'achievement') {
      final id = n['achievementId'] as String?;
      nav.pushNamed('/stats',
          arguments: id != null ? {'highlightId': id} : null);
      return;
    }
    if (type == 'friend_added') {
      nav.pushNamed('/profile');
      return;
    }
    // Default: take user to inbox.
    nav.pushNamed('/notifications');
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

    // Web fragment URLs (https://.../#/confirm?code=X) carry the real route +
    // query after the '#', so parse the fragment too.
    if (code == null && uri.fragment.isNotEmpty) {
      try {
        code =
            Uri.parse('dummy://dummy/${uri.fragment}').queryParameters['code'];
      } catch (_) {}
    }
    if (code == null) return;

    final blob = '${uri.host}/${uri.path}/${uri.fragment}';
    // `/friend-profile` contains 'friend' but is a read-only profile view, not
    // an invite — exclude it so a friend-profile URL that happens to carry a
    // `code` isn't misrouted into the add-friend screen.
    final isFriendProfile = blob.contains('friend-profile');
    final isConfirm = blob.contains('confirm');
    final isFriendInvite = !isFriendProfile && blob.contains('friend');

    String? route;
    Object? args;
    if (isConfirm) {
      route = '/confirm';
      args = code;
    } else if (isFriendInvite) {
      route = '/friend?code=$code';
    }
    if (route == null) return;

    // Act now if signed in; otherwise stash and let login.dart replay it once
    // the user authenticates — so a link opened from a cold, logged-out start
    // isn't silently dropped.
    if (FirebaseAuth.instance.currentUser != null) {
      pushDeepLinkWhenReady(route, args);
    } else {
      PendingDeepLink.stash(route, args);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Motivator',
      debugShowCheckedModeBanner: false,
      // Force Czech for all Material widget strings (OK/Cancel/picker/etc).
      // Without this, the framework falls back to system locale which may
      // render Slovak / English on user's OS.
      locale: const Locale('cs'),
      supportedLocales: const [Locale('cs')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
          backgroundColor: AppColors.cardLight,
          foregroundColor: Colors.black87,
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
        '/profile': (context) => const ProfilePage(),
        '/find-friends': (context) => const FindFriendsPage(),
      },
      // Handle parameterised routes (e.g. /friend?code=XXX) that the static
      // `routes` map cannot express. The static map takes priority; this only
      // fires for unmatched names.
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        // Order matters: /friend-profile must be checked before /friend
        // because '/friend-profile' also startsWith('/friend').
        if (name.startsWith('/friend-profile')) {
          final uri = Uri.parse(name);
          final uid = uri.queryParameters['uid'] ?? '';
          return MaterialPageRoute(
            builder: (_) => FriendProfilePage(uid: uid),
            settings: settings,
          );
        }
        if (name.startsWith('/friend')) {
          final code = Uri.parse(name).queryParameters['code'] ?? '';
          // Deep link opened while logged out: the router resolves the boot URL
          // before app_links can read it, so stash the link here and fall back
          // to the login screen (return null → initialRoute '/'). login.dart
          // replays it once the user authenticates.
          if (FirebaseAuth.instance.currentUser == null) {
            PendingDeepLink.stash('/friend?code=$code', null);
            return null;
          }
          return MaterialPageRoute(
            builder: (_) => FriendInviteScreen(code: code),
            settings: settings,
          );
        }
        // '/confirm?code=X' web deep link. The bare '/confirm' is served by the
        // static routes map (in-app navigation); only the query-carrying form
        // reaches here, so this is always an external link.
        if (name.startsWith('/confirm')) {
          final code = Uri.parse(name).queryParameters['code'];
          if (code == null || code.isEmpty) return null;
          if (FirebaseAuth.instance.currentUser == null) {
            PendingDeepLink.stash('/confirm', code);
            return null;
          }
          return MaterialPageRoute(
            builder: (_) => const ConfirmTaskPage(),
            settings: RouteSettings(name: '/confirm', arguments: code),
          );
        }
        return null;
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
