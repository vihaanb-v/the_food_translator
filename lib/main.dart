import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth_page.dart';
import 'home_screen.dart';
import 'firebase_options.dart';

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
      ),
      home: const AuthPage(), // default entry point
      routes: {
        '/home': (context) => HomeScreen(), // ✅ added named route
        // You can add others if needed:
        // '/login': (context) => LoginScreen(onTap: () {}),
        // '/register': (context) => RegisterPage(onTap: () {}),
      },
    );
  }
}
