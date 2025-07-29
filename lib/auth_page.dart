import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:the_food_translator/home_screen.dart';
import 'package:the_food_translator/login_or_register.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  User? _lastUser;
  bool _isRedirecting = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // ✅ Detect auth state change → reset redirect status
        if (user != _lastUser) {
          _isRedirecting = false;
        }

        // ✅ Login: animate to HomeScreen
        if (user != null && !_isRedirecting) {
          _isRedirecting = true;
          _lastUser = user;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 500),
                pageBuilder: (_, __, ___) => HomeScreen(),
                transitionsBuilder: (_, animation, __, child) {
                  final slide = Tween<Offset>(
                    begin: const Offset(1.0, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ));
                  return SlideTransition(position: slide, child: child);
                },
              ),
            );
          });

          return const SizedBox.shrink();
        }

        // ✅ Logout: animate to Login screen
        if (user == null && !_isRedirecting) {
          _isRedirecting = true;
          _lastUser = null;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 500),
                pageBuilder: (_, __, ___) => const LoginOrRegisterPage(),
                transitionsBuilder: (_, animation, __, child) {
                  final slide = Tween<Offset>(
                    begin: const Offset(-1.0, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ));
                  return SlideTransition(position: slide, child: child);
                },
              ),
            );
          });

          return const SizedBox.shrink();
        }

        // ✅ Already stable state, no animation needed
        return user == null
            ? const LoginOrRegisterPage()
            : HomeScreen();
      },
    );
  }
}
