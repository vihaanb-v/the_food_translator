import 'dart:ui';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dialogs.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "Unknown";
    final photoUrl = user?.photoURL;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          // Blurred top header
          Container(
            height: 280,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFffecd2), Color(0xFFfcb69f)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 30),
                Hero(
                  tag: 'profile-pic',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      backgroundImage: const AssetImage('assets/profile_placeholder.jpg'),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Vihaan Bhaduri",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ListView(
                      children: [
                        GlassTile(
                          icon: Icons.history,
                          title: "My Dishes",
                          onTap: () => Navigator.pushNamed(context, '/my-dishes'),
                        ),
                        GlassTile(
                          icon: Icons.favorite,
                          title: "Favorites",
                          onTap: () => Navigator.pushNamed(context, '/favorites'),
                        ),
                        GlassTile(
                          icon: Icons.settings,
                          title: "Settings",
                          onTap: () => Navigator.pushNamed(context, '/settings'),
                        ),
                        GlassTile(
                          icon: Icons.security,
                          title: "Privacy",
                          onTap: () => Navigator.pushNamed(context, '/privacy'),
                        ),
                        GlassTile(
                          icon: Icons.logout,
                          title: "Log Out",
                          onTap: () async {
                            showLoadingDialog(context, "Logging out...");
                            await Future.delayed(const Duration(milliseconds: 1200));
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/',
                                    (route) => false,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Back to Home"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GlassTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const GlassTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  State<GlassTile> createState() => _GlassTileState();
}

class _GlassTileState extends State<GlassTile> {
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        setState(() => _isTapped = true);
        Future.delayed(const Duration(milliseconds: 200), () {
          setState(() => _isTapped = false);
          if (widget.onTap != null) widget.onTap!();
        });
      },
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          boxShadow: _isTapped
              ? [
            BoxShadow(
              color: Colors.orangeAccent.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white70, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                leading: Icon(widget.icon, color: Colors.black87),
                title: Text(
                  widget.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
