import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'auth_page.dart';
import 'home_screen.dart';
import 'profile_page.dart';
import 'my_dishes_page.dart';
import 'favorites_page.dart';
import 'settings.dart';
import 'splash_screen.dart';
import 'user_profile_provider.dart';
import 'saved_dishes_manager.dart';

bool _hasShownSplash = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProfileProvider()),
            if (user != null)
              ChangeNotifierProvider(
                create: (_) => SavedDishesManager(userId: user.uid)..loadDishes(),
              ),
          ],
          child: MaterialApp(
            title: 'Disypher',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'Roboto',
              scaffoldBackgroundColor: Colors.grey[50],
              useMaterial3: true,
              colorSchemeSeed: Colors.deepOrange,
            ),
            home: const AppEntryPoint(), // only shown once
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/home':
                  return MaterialPageRoute(builder: (_) => HomeScreen());
                case '/profile':
                  return MaterialPageRoute(builder: (_) => const ProfilePage());
                case '/my-dishes':
                  return MaterialPageRoute(builder: (_) => const MyDishesPage());
                case '/favorites':
                  return MaterialPageRoute(builder: (_) => const FavoritesPage());
                case '/settings':
                  return MaterialPageRoute(builder: (_) => const SettingsPage());
                default:
                  return null;
              }
            },
          ),
        );
      },
    );
  }
}

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  bool _showSplash = !_hasShownSplash;

  @override
  void initState() {
    super.initState();

    if (_showSplash) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _hasShownSplash = true;
            _showSplash = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _showSplash ? const SplashScreen() : const AuthPage();
  }
}