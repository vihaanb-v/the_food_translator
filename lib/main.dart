import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'login.dart';

// Optional: Remove this if not used elsewhere
late final List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      home: LoginScreen(), // ✅ No longer passes `cameras`
    );
  }
}
