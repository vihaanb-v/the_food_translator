import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth_page.dart';
import 'home_screen.dart';
import 'firebase_options.dart';
import 'profile_page.dart';
import 'profile_routes.dart'; // 🔥 all 4 sexy profile sub-pages

// Optional: Remove this if not used elsewhere
late final List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  cameras = await availableCameras();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Food Translator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.grey[50],
        useMaterial3: true,
        colorSchemeSeed: Colors.deepOrange,
      ),
      home: const AuthPage(), // default entry point (checks login state)
      routes: {
        '/home': (context) => HomeScreen(),
        '/profile': (context) => const ProfilePage(),
        '/my-dishes': (context) => const MyDishesPage(),
        '/favorites': (context) => const FavoritesPage(),
        '/settings': (context) => const SettingsPage(),
        '/privacy': (context) => const PrivacyPage(),
      },
    );
  }
}
