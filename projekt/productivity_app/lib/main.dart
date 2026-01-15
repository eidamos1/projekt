// main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_links/app_links.dart';
import 'firebase_options.dart'; // Konfigurace Firebase
import 'pages/login.dart';
import 'pages/calendar_page.dart';
import 'pages/confirm_task.dart';
import 'pages/settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform);
runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp()));
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;

  bool get isDarkMode => themeMode == ThemeMode.dark;

  void toggleTheme(bool isOn) {
    themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>(); // Klíč pro navigaci odkudkoliv
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

    // 1. Zkontroluj, jestli aplikace byla otevřena přes odkaz (byla vypnutá)
    try {
      final Uri? initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleLink(initialLink);
      }
    } catch (e) {
      print('Chyba při načítání úvodního odkazu: $e');
    }

    // 2. Poslouchej odkazy, když aplikace běží na pozadí
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleLink(uri);
      }
    }, onError: (err) {
      print('Chyba streamu odkazů: $err');
    });
  }

  // Funkce, která zpracuje odkaz typu: adamapp://confirm?code=123456
  void _handleLink(Uri uri) {
    print("Přijat odkaz: $uri");

    String? code = uri.queryParameters['code'];
    
    // Zkontrolujeme, jestli je to náš odkaz pro potvrzení
    if (uri.host == 'confirm' && uri.queryParameters.containsKey('code')) {
      String? code = uri.queryParameters['code'];
      
      if (code != null) {
        // Počkáme chvilku, než se Flutter úplně načte, pokud se appka teprve zapíná
        Future.delayed(Duration(seconds: 1), () {
          // Přesměrujeme na stránku ConfirmTaskPage a předáme kód
          _navigatorKey.currentState?.pushNamed(
            '/confirm',
            arguments: code, // Pošleme kód jako argument
          );
        });
      }
    }
    // 2. Pokud tam není, zkusíme se podívat do fragmentu (pro Web s #)
    // Např: http://localhost/#/confirm?code=123
    if (code == null && uri.fragment.isNotEmpty) {
      // Rozparsujeme fragment jako nové URI
      try {
        // Přidáme fiktivní scheme, aby to šlo parsovat
        final fragmentUri = Uri.parse('dummy://dummy/${uri.fragment}');
        code = fragmentUri.queryParameters['code'];
      } catch (e) {
        print('Chyba parsování fragmentu: $e');
      }
    }

    // Kontrola, zda jsme našli kód a zda jde o potvrzovací stránku
    // Na mobilu je host 'confirm', na webu může být 'confirm' v cestě nebo fragmentu
    bool isConfirmPage = uri.host == 'confirm' || 
                         uri.path.contains('confirm') || 
                         uri.fragment.contains('confirm');

    if (isConfirmPage && code != null) {
      print("Nalezen kód: $code");
      
      // Počkáme chvilku, než se Flutter úplně načte
      Future.delayed(Duration(seconds: 1), () {
        _navigatorKey.currentState?.pushNamed(
          '/confirm',
          arguments: code,
        );
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'Motivator',
      debugShowCheckedModeBanner: false, // Skryje nápis DEBUG
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          
        ),
                textTheme: GoogleFonts.poppinsTextTheme(),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo[700],
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      
        // Globální nastavení fontu
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData(brightness: Brightness.light).textTheme),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(),
        '/calendar': (context) => CalendarPage(),
        '/confirm': (context) => ConfirmTaskPage(),
        '/settings': (context) => SettingsPage(),
      },
    );
  }
}