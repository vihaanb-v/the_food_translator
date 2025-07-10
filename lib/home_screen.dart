import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'camera_screen.dart';
import 'profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'chat_chef_modal.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({super.key});
  final user = FirebaseAuth.instance.currentUser!;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  List<Map<String, dynamic>> savedDishes = [];

  bool _isLoading = true;
  bool _showContent = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  dynamic _parseRecipeSafely(dynamic value) {
    if (value is String) {
      try {
        return jsonDecode(value);
      } catch (e) {
        debugPrint("❌ Failed to decode recipe JSON: $e");
        return null;
      }
    } else if (value is Map<String, dynamic>) {
      return value;
    } else {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSavedDishesFromFirestore();
  }

  void _loadSavedDishesFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedDishes')
        .orderBy('createdAt', descending: true)
        .get();

    final List<Map<String, dynamic>> loadedDishes = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final imageUrl = data['imageUrl'] as String?;
      if (imageUrl == null || imageUrl.isEmpty) continue;

      try {
        final response =
        await HttpClient().getUrl(Uri.parse('$imageUrl?f_auto,q_auto'));
        final imageData = await response.close();
        final bytes = await consolidateHttpClientResponseBytes(imageData);
        final file = await File('${Directory.systemTemp.path}/${doc.id}.jpg')
            .writeAsBytes(bytes);

        loadedDishes.add({
          'id': doc.id,
          'title': data['title'],
          'description': data['description'],
          'healthyRecipe': _parseRecipeSafely(data['healthyRecipe']),
          'mimicRecipe': _parseRecipeSafely(data['mimicRecipe']),
          'imagePath': file.path,
          'isFavorite': data['isFavorite'] ?? false,
        });
      } catch (e) {
        debugPrint("❌ Failed to load image from $imageUrl: $e");
        // Continue even if one image fails
      }
    }

    // Always end loading state even if image download failed
    if (!mounted) return;
    setState(() {
      savedDishes = loadedDishes;
      _isLoading = false;
    });

    // Trigger smooth reveal animation
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _showContent = true);
    });
  }

  void _toggleFavorite(int index) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final dishId = savedDishes[index]['id'];
    final current = savedDishes[index]['isFavorite'] ?? false;

    setState(() {
      savedDishes[index]['isFavorite'] = !current;
    });

    if (uid != null && dishId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('savedDishes')
          .doc(dishId)
          .update({'isFavorite': !current});
    }
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
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );

    if (result == null) return;

    final imageUrl = result['imageUrl'];
    if (imageUrl == null || imageUrl is! String || imageUrl.isEmpty) return;

    try {
      final response = await HttpClient().getUrl(Uri.parse(imageUrl));
      final imageData = await response.close();
      final bytes = await consolidateHttpClientResponseBytes(imageData);
      final file = await File('${Directory.systemTemp.path}/${DateTime.now().millisecondsSinceEpoch}.jpg')
          .writeAsBytes(bytes);

      result['imagePath'] = file.path;
      result['isFavorite'] = result['isFavorite'] ?? false;

      setState(() {
        savedDishes.insert(0, result);
        _listKey.currentState?.insertItem(0);
      });
    } catch (e) {
      debugPrint("❌ Failed to download image: $e");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDishPopup(Map<String, dynamic> dish) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dish Popup',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
          child: Center(
            child: Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: DefaultTabController(
                length: 3,
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.75,
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(
                              child: Text(
                                dish['title'] ?? 'Dish',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(Icons.close, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TabBar(
                        isScrollable: false, // ← enable scroll to control spacing manually
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 2), // tighter spacing
                        indicatorPadding: EdgeInsets.zero,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey,
                        overlayColor: WidgetStateProperty.all(Colors.transparent),
                        labelStyle: const TextStyle(
                          fontSize: 13.5, // slightly smaller
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: const [
                          Tab(text: 'Description'),
                          Tab(text: 'Healthier Recipe'),
                          Tab(text: 'Mimic Recipe'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildTabContent(
                              dish['imagePath'],
                              dish['description'] ?? 'No description',
                            ),
                            _buildTabContent(
                              dish['imagePath'],
                              dish['healthyRecipe'] is Map ? dish['healthyRecipe'] : 'No healthy recipe available',
                            ),
                            _buildTabContent(
                              dish['imagePath'],
                              dish['mimicRecipe'] is Map ? dish['mimicRecipe'] : 'No mimic recipe available',
                            ),
                          ],
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
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildTabContent(String imagePath, dynamic content) {
    return Column(
      children: [
        Image.file(
          File(imagePath),
          width: double.infinity,
          height: 180,
          fit: BoxFit.cover,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: content is String
                    ? Text(
                  content,
                  style: const TextStyle(fontSize: 16),
                )
                    : _buildStructuredRecipe(content),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStructuredRecipe(Map<String, dynamic> recipe) {
    final nutrition = recipe['nutrition'] ?? {};

    Widget sectionTitle(IconData icon, String text) {
      return Row(
        children: [
          Icon(icon, size: 20, color: Colors.black),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    Widget divider() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(color: Colors.black12.withOpacity(0.4), thickness: 1),
    );

    return AnimatedSlide(
      duration: const Duration(milliseconds: 500),
      offset: Offset(0, 0),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recipe['title'] != null)
              Text(
                recipe['title'],
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

            const SizedBox(height: 10),

            // ⏱️ Serving + Time
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_outline, size: 18),
                    const SizedBox(width: 4),
                    Text("Servings: ${recipe['servings'] ?? '--'}"),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 18),
                    const SizedBox(width: 4),
                    Text("${recipe['prepTime'] ?? '--'} prep"),
                    const Text(" • "),
                    Text("${recipe['cookTime'] ?? '--'} cook"),
                  ],
                ),
              ],
            ),

            divider(),

            // 🥗 Ingredients
            sectionTitle(Icons.shopping_cart_outlined, "Ingredients"),
            const SizedBox(height: 6),
            ...List<String>.from(recipe['ingredients'] ?? [])
                .map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text("• $item"),
            )),

            divider(),

            // 👨‍🍳 Instructions
            sectionTitle(Icons.restaurant_menu_outlined, "Instructions"),
            const SizedBox(height: 6),
            ...List<String>.from(recipe['instructions'] ?? [])
                .asMap()
                .entries
                .map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text("${entry.key + 1}. ${entry.value}"),
            )),

            if (nutrition.isNotEmpty) ...[
              divider(),
              sectionTitle(Icons.health_and_safety_outlined, "Nutrition (per serving)"),
              const SizedBox(height: 6),
              Text("• Calories: ${nutrition['calories'] ?? '--'} kcal"),
              Text("• Protein: ${nutrition['protein'] ?? '--'}"),
              Text("• Carbs: ${nutrition['carbs'] ?? '--'}"),
              Text("• Fat: ${nutrition['fat'] ?? '--'}"),
            ],
          ],
        ),
      ),
    );
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
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, anim1, anim2) => const ChatChefModal(),
    );
  }

  Widget buildSavedDishButton(Map<String, dynamic> dish, int index) {
    return Dismissible(
      key: Key(dish['imagePath'] + index.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 32),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Delete this dish?",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Are you sure you want to permanently remove this recipe?",
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
                          child: const Text("Delete"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      onDismissed: (_) async {
        if (index < 0 || index >= savedDishes.length) return;

        final removedDish = savedDishes[index];
        final dishId = removedDish['id'] as String?;
        final uid = FirebaseAuth.instance.currentUser?.uid;

        Future.microtask(() => _savedDishesRemoveAt(index));

        if (uid != null && dishId != null && dishId.isNotEmpty) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('savedDishes')
                .doc(dishId)
                .delete();
          } catch (e) {
            debugPrint('❌ Failed to delete dish from Firestore: $e');
          }
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.black,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: AnimatedSlide(
        offset: Offset.zero,
        duration: const Duration(milliseconds: 300),
        child: GestureDetector(
          onTap: () => _showDishPopup(dish),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔥 Image with dark glass overlay
                      Stack(
                        children: [
                          Image.file(
                            File(dish['imagePath']),
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.cover,
                          ),
                          Container(
                            height: 160,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.35),
                                  Colors.transparent,
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                          ),
                          // ❤️ Favorite Button
                          Positioned(
                            top: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: () => _toggleFavorite(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.85),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  dish['isFavorite'] == true
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.redAccent,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // 🍽 Dish info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dish['title'] ?? 'Untitled Dish',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: const [
                                Icon(Icons.restaurant_menu, size: 16, color: Colors.black),
                                SizedBox(width: 6),
                                Text(
                                  "Tap to view recipe",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _savedDishesRemoveAt(int index) {
    final removedItem = savedDishes.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
          (context, animation) => SizeTransition(
        sizeFactor: animation,
        child: buildSavedDishButton(removedItem, index),
      ),
      duration: const Duration(milliseconds: 300),
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
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain, // Prevents side clipping
                ),
              ),
            ),
          ),
        ),
        title: const Text(
          'Disypher',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Tooltip(
            message: "View Profile",
            child: IconButton(
              icon: Hero(
                tag: 'profile-pic',
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: widget.user.photoURL != null
                      ? NetworkImage(widget.user.photoURL!)
                      : const AssetImage('assets/profile_placeholder.jpg') as ImageProvider,
                  backgroundColor: Colors.white,
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 500),
                    pageBuilder: (_, __, ___) => ProfilePage(savedDishes: savedDishes),
                    transitionsBuilder: (_, animation, __, child) {
                      final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
                      return FadeTransition(
                        opacity: curved,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(curved),
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _isLoading
            ? const Center(
          key: ValueKey('loader'),
          child: CircularProgressIndicator(),
        )
            : ListView(
          key: const ValueKey('loadedContent'),
          padding: const EdgeInsets.symmetric(vertical: 20),
          children: [
            // 🔍 Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase().trim();
                  });
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
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                    const BorderSide(color: Colors.black, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                    const BorderSide(color: Colors.black, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                    const BorderSide(color: Colors.black, width: 1.5),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 📸 Camera Button
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _openCamera,
                splashColor: Colors.grey.withOpacity(0.2),
                highlightColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🧠 Filtered Dishes
            Builder(
              builder: (context) {
                final filteredDishes = savedDishes.where((dish) {
                  final title =
                  (dish['title'] ?? '').toString().toLowerCase();
                  final desc =
                  (dish['description'] ?? '').toString().toLowerCase();
                  return title.contains(_searchQuery) ||
                      desc.contains(_searchQuery);
                }).toList();

                if (filteredDishes.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.fastfood, size: 90, color: Colors.grey),
                        SizedBox(height: 22),
                        Text(
                          "No matching recipes found",
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12),
                        Text(
                          "Try a different search or add a new dish.",
                          style:
                          TextStyle(fontSize: 14.5, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredDishes.length,
                  itemBuilder: (context, index) {
                    return buildSavedDishButton(
                        filteredDishes[index], index);
                  },
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20, right: 10),
        child: FloatingActionButton(
          backgroundColor: Colors.black,
          onPressed: _openChatChefModal,
          child:
          const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
        ),
      ),
    );
  }
}