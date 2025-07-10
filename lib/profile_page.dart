import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dialogs.dart';
import 'my_dishes_page.dart';
import 'favorites_page.dart';
import 'navigation_utils.dart';

class ProfilePage extends StatelessWidget {
  final List<Map<String, dynamic>> savedDishes;

  const ProfilePage({super.key, required this.savedDishes});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "Unknown";
    final photoUrl = user?.photoURL;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          // 🌅 Background logo image
          SizedBox(
            height: 300,
            width: double.infinity,
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.cover,
            ),
          ),

          // 🧊 Blur and dark overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
              child: Container(
                color: Colors.black.withOpacity(0.15),
              ),
            ),
          ),

          // 👤 Profile content
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
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : const AssetImage('assets/profile_placeholder.jpg') as ImageProvider,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Disypher",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 40),

                // 🔽 Menu
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ListView(
                      children: [
                        GlassTile(
                          icon: Icons.history,
                          title: "My Dishes",
                          onTap: () => smoothPush(context, MyDishesPage(savedDishes: savedDishes)),
                        ),
                        GlassTile(
                          icon: Icons.favorite,
                          title: "Favorites",
                          onTap: () => smoothPush(context, FavoritesPage(savedDishes: savedDishes)),
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
                            final confirmed = await showDialog<bool>(
                              context: context,
                              barrierDismissible: true,
                              builder: (context) => Dialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                insetPadding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        "Are you sure?",
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        "Do you really want to log out?",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 15, color: Colors.black87),
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.black87,
                                                side: const BorderSide(color: Colors.black12),
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: const Text("Cancel"),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.redAccent,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: const Text("Log Out"),
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            );

                            if (confirmed == true) {
                              showLoadingDialog(context, "Logging out...");
                              await Future.delayed(const Duration(milliseconds: 1200));
                              await FirebaseAuth.instance.signOut();
                              if (context.mounted) {
                                Navigator.of(context).pop(); // close loading
                                Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // 🔙 Back button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
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
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.8),
              Colors.white.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            if (_isTapped)
              BoxShadow(
                color: Colors.orangeAccent.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black26.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
          ],
          border: Border.all(color: Colors.black.withOpacity(0.15), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ListTile(
              leading: Icon(widget.icon, color: Colors.black, size: 26),
              title: Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Colors.black87,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
            ),
          ),
        ),
      ),
    );
  }
}
