import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum PasswordStrength { weak, medium, strong }

class RegisterPage extends StatefulWidget {
  final Function()? onTap;
  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  PasswordStrength _passwordStrength = PasswordStrength.weak;

  PasswordStrength evaluatePasswordStrength(String password) {
    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'\d'));
    bool hasSpecial = password.contains(RegExp(r'[!@#\$&*~^%()+\-_=<>?]'));
    bool isLong = password.length >= 8;

    int score = [hasUpper, hasLower, hasDigit, hasSpecial, isLong].where((e) => e).length;

    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  bool isStrongPassword(String password) {
    return evaluatePasswordStrength(password) == PasswordStrength.strong;
  }

  Widget _buildStrengthBar(String password) {
    final strength = evaluatePasswordStrength(password);

    double widthFactor;
    Color color;
    String label;

    switch (strength) {
      case PasswordStrength.weak:
        widthFactor = 0.33;
        color = Colors.red;
        label = 'Weak';
        break;
      case PasswordStrength.medium:
        widthFactor = 0.66;
        color = Colors.yellow;
        label = 'Medium';
        break;
      case PasswordStrength.strong:
        widthFactor = 1.0;
        color = Colors.green;
        label = 'Strong';
        break;
    }

    final bool showHints = password.isNotEmpty;

    List<String> hints = [];
    if (!password.contains(RegExp(r'[A-Z]'))) hints.add("Add an uppercase letter");
    if (!password.contains(RegExp(r'[a-z]'))) hints.add("Add a lowercase letter");
    if (!password.contains(RegExp(r'\d'))) hints.add("Add a number");
    if (!password.contains(RegExp(r'[!@#\$&*~^%()+\-_=<>?]'))) hints.add("Add a special character");
    if (password.length < 8) hints.add("Use 8+ characters");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedAlign(
          alignment: Alignment.centerLeft,
          duration: const Duration(milliseconds: 300),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 8,
            width: MediaQuery.of(context).size.width * widthFactor,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        if (showHints && hints.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...hints.map((hint) => Text(
            "• $hint",
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 13.5,
              color: Colors.black54,
            ),
          )),
        ],
      ],
    );
  }

  void _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showErrorDialog("Please fill out all fields.");
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showErrorDialog("Please enter a valid email address.");
      return;
    }

    if (password != confirmPassword) {
      _showErrorDialog("Passwords do not match.");
      return;
    }

    if (!isStrongPassword(password)) {
      _showErrorDialog("Password must be 8+ characters, with uppercase, lowercase, number, and special character.");
      return;
    }

    late BuildContext dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dContext) {
        dialogContext = dContext;
        return const Center(
          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
        );
      },
    );

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (mounted) {
        Navigator.pop(dialogContext);
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(dialogContext);
      switch (e.code) {
        case 'invalid-email':
          _showErrorDialog("The email address is invalid.");
          break;
        case 'email-already-in-use':
          _showErrorDialog("An account already exists with this email.");
          break;
        case 'weak-password':
          _showErrorDialog("Your password is too weak.");
          break;
        default:
          _showErrorDialog("Registration failed: ${e.message}");
          break;
      }
    } catch (_) {
      if (mounted) Navigator.pop(dialogContext);
      _showErrorDialog("An unexpected error occurred. Please try again.");
    }
  }

  void _showErrorDialog(String message) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Error",
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (_, anim1, __, ___) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: Opacity(
            opacity: anim1.value,
            child: Dialog(
              backgroundColor: Colors.white.withOpacity(0.94),
              elevation: 12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_rounded, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 18),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text(
                            "OK",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              reverse: true,
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      Hero(
                        tag: 'logo',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset('assets/logo.png', height: 180),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        "Disypher",
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Create a new account",
                        style: TextStyle(fontSize: 15.5, color: Colors.black54),
                      ),
                      const SizedBox(height: 36),

                      // 📧 Email
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 15.5),
                        decoration: InputDecoration(
                          hintText: "Email",
                          hintStyle: const TextStyle(color: Colors.black),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black26, width: 1.3),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black87, width: 1.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 🔒 Password
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onChanged: (val) {
                          setState(() {
                            _passwordStrength = evaluatePasswordStrength(val);
                          });
                        },
                        style: const TextStyle(fontSize: 15.5),
                        decoration: InputDecoration(
                          hintText: "Password",
                          hintStyle: const TextStyle(color: Colors.black),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.black,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black26, width: 1.3),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black87, width: 1.6),
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _passwordController.text.isNotEmpty
                            ? Column(
                          key: const ValueKey("bar"),
                          children: [
                            const SizedBox(height: 10),
                            _buildStrengthBar(_passwordController.text),
                            const SizedBox(height: 20), // 👈 more spacing before confirm
                          ],
                        )
                            : const SizedBox(height: 20), // 👈 keeps spacing consistent
                      ),

                      // 🔁 Confirm Password
                      TextField(
                        controller: _confirmPasswordController,
                        enabled: isStrongPassword(_passwordController.text),
                        obscureText: _obscurePassword,
                        style: const TextStyle(fontSize: 15.5),
                        decoration: InputDecoration(
                          hintText: "Confirm Password",
                          hintStyle: const TextStyle(color: Colors.black),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.black,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black38, width: 1.3),
                          ),
                          disabledBorder: OutlineInputBorder( // 👈 when it's disabled initially
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black26, width: 1.3),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black87, width: 1.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // ✅ Sign Up
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _signUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(fontSize: 15.5, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.4),
                          ),
                        ),
                      ),
                      const Spacer(),

                      // 👈 Already have account
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Already have an account?", style: TextStyle(color: Colors.black87)),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () async {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                                  ),
                                );
                                await Future.delayed(const Duration(milliseconds: 800));
                                Navigator.of(context).pop();
                                widget.onTap!();
                              },
                              child: const Text(
                                "Login here.",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
