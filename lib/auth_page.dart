import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:the_food_translator/home_screen.dart';
import 'package:the_food_translator/login.dart';
import 'package:the_food_translator/login_or_register.dart';

class AuthPage extends StatelessWidget{
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // User has logged in
          if (snapshot.hasData) {
            return HomeScreen();
          } else {
            // User has not logged in
            return LoginOrRegisterPage();
          }
        }
      )
    );
  }
}