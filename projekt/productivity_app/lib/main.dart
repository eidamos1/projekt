// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Konfigurace Firebase
import 'pages/login.dart';
import 'pages/calendar_page.dart';
import 'pages/confirm_task.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializace Firebase podle platformy
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kalendářový plánovač',
      theme: ThemeData(primarySwatch: Colors.blue),
      // Nastavení rout
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(),
        '/calendar': (context) => CalendarPage(),
        '/confirm': (context) => ConfirmTaskPage(),
      },
    );
  }
}
