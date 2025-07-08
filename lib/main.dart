import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth_page.dart';
import 'home_screen.dart';
import 'firebase_options.dart';
import 'profile_page.dart';
import 'my_dishes_page.dart' as dishes;
import 'favorites_page.dart' as favs;
import 'profile_routes.dart'; // Still fine for SettingsPage and PrivacyPage

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
      home: const AuthPage(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/home':
            return MaterialPageRoute(builder: (_) => HomeScreen());

          case '/profile':
            final args = settings.arguments as List<Map<String, dynamic>>;
            return MaterialPageRoute(
              builder: (_) => ProfilePage(savedDishes: args),
            );

          case '/my-dishes':
            final args = settings.arguments as List<Map<String, dynamic>>;
            return MaterialPageRoute(
              builder: (_) => dishes.MyDishesPage(savedDishes: args),
            );

          case '/favorites':
            final args = settings.arguments as List<Map<String, dynamic>>;
            return MaterialPageRoute(
              builder: (_) => favs.FavoritesPage(savedDishes: args),
            );

          case '/settings':
            return MaterialPageRoute(builder: (_) => const SettingsPage());

          case '/privacy':
            return MaterialPageRoute(builder: (_) => const PrivacyPage());

          default:
            return null;
        }
      },
    );
  }
}