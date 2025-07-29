import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import 'camera_screen.dart';
import 'profile_page.dart';
import 'chat_chef_modal.dart';
import 'user_profile_provider.dart';
import 'saved_dishes_manager.dart';
import 'glass_dish_card.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({super.key});
  final user = FirebaseAuth.instance.currentUser!;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _dishesLoaded = false;

  @override
  void initState() {
    super.initState();
    final url = FirebaseAuth.instance.currentUser?.photoURL;
    Provider.of<UserProfileProvider>(context, listen: false).loadInitial(url);

    // Small delay to allow Provider to propagate dishes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _dishesLoaded = true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCamera() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const CameraPage(),
        transitionsBuilder: (_, animation, __, child) {
          final curve = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );

    if (result == null || result['imageUrl'] == null) return;

    try {
      result['imagePath'] = result['imageUrl']; // ✅ Use Cloudinary URL directly
      result['isFavorite'] = result['isFavorite'] ?? false;

      final manager = Provider.of<SavedDishesManager>(context, listen: false);
      await manager.addDish(result);
    } catch (e) {
      debugPrint("❌ Failed to save analyzed dish: $e");
    }
  }

  void _openChatChefModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Chat Chef",
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      pageBuilder: (context, anim1, anim2) => const ChatChefModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 2,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Hero(
            tag: 'app-logo',
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.25),
                    blurRadius: 6,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset('assets/logo.png', fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        title: const Text(
          'Disypher',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20, letterSpacing: 0.5),
        ),
        actions: [
          Tooltip(
            message: "View Profile",
            child: IconButton(
              icon: Hero(
                tag: 'profile-pic',
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: context.watch<UserProfileProvider>().photoUrl.isNotEmpty
                      ? NetworkImage(context.watch<UserProfileProvider>().photoUrl)
                      : const AssetImage('assets/profile_placeholder.jpg') as ImageProvider,
                  backgroundColor: Colors.white,
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 500),
                    pageBuilder: (_, __, ___) => const ProfilePage(),
                    transitionsBuilder: (_, animation, __, child) {
                      final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
                      return FadeTransition(
                        opacity: curved,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(curved),
                          child: child,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Consumer<SavedDishesManager>(
        builder: (context, manager, _) {
          final filteredDishes = manager.dishes.where((dish) {
            final title = (dish['title'] ?? '').toString().toLowerCase();
            final desc = (dish['description'] ?? '').toString().toLowerCase();
            return title.contains(_searchQuery) || desc.contains(_searchQuery);
          }).toList();

          final isSearching = _searchQuery.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase().trim());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search recipes...',
                    prefixIcon: const Icon(Icons.search, color: Colors.black87),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.black54),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.black, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _openCamera,
                  splashColor: Colors.grey.withOpacity(0.2),
                  highlightColor: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.camera_alt, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "Decipher a Dish",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Avoid flicker: don't show any result state until _showCards is true
              if (!_dishesLoaded)
                const SizedBox.shrink()
              else if (filteredDishes.isEmpty && isSearching)
                AnimatedOpacity(
                  duration: Duration(milliseconds: 400),
                  opacity: 1.0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.fastfood, size: 90, color: Colors.grey),
                        SizedBox(height: 22),
                        Text("No matching recipes found", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                        SizedBox(height: 12),
                        Text("Try a different search or add a new dish.", style: TextStyle(fontSize: 14.5, color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredDishes.length,
                  itemBuilder: (context, index) {
                    return FadingDishCard(dish: filteredDishes[index], index: index);
                  },
                ),
            ],
          );
        },
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: max(MediaQuery.of(context).viewPadding.bottom - 30, 4),
          right: 10,
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.black,
          onPressed: _openChatChefModal,
          child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class FadingDishCard extends StatefulWidget {
  final Map<String, dynamic> dish;
  final int index;

  const FadingDishCard({super.key, required this.dish, required this.index});

  @override
  State<FadingDishCard> createState() => _FadingDishCardState();
}

class _FadingDishCardState extends State<FadingDishCard> {
  double _opacity = 0.0;

  Timer? _fadeTimer;

  @override
  void initState() {
    super.initState();

    _fadeTimer = Timer(Duration(milliseconds: widget.index * 80), () {
      if (mounted) {
        setState(() => _opacity = 1.0);
      }
    });
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOut,
      opacity: _opacity,
      child: Dismissible(
        key: Key(widget.dish['id']),
        direction: DismissDirection.endToStart,
        background: Container(
          color: Colors.black,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) {
          Provider.of<SavedDishesManager>(context, listen: false)
              .deleteDish(widget.dish['id']);
        },
        child: GlassDishCard(dish: widget.dish, showPopupOnTap: true),
      ),
    );
  }
}
