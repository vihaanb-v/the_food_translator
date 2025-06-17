import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'login.dart';

import 'package:the_food_translator/auth_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Optional: Remove this if not used elsewhere
late final List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // You can still load cameras for use in CameraPage later
  cameras = await availableCameras();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'JoinUp Camera',
      debugShowCheckedModeBanner: false,
      home: AuthPage(),
    );
  }
}
