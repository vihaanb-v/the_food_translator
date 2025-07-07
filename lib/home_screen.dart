import 'dart:io';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'camera_screen.dart';
import 'profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({super.key});
  final user = FirebaseAuth.instance.currentUser!;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  List<Map<String, dynamic>> savedDishes = [];

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

      // ✅ Download Cloudinary image to local file
      try {
        final response = await HttpClient().getUrl(Uri.parse('$imageUrl?f_auto,q_auto'));
        final imageData = await response.close();
        final bytes = await consolidateHttpClientResponseBytes(imageData);
        final file = await File('${Directory.systemTemp.path}/${doc.id}.jpg')
            .writeAsBytes(bytes);

        loadedDishes.add({
          'id': doc.id,
          'title': data['title'],
          'description': data['description'],
          'healthyRecipe': data['healthyRecipe'],
          'mimicRecipe': data['mimicRecipe'],
          'imagePath': file.path,
          'isFavorite': data['isFavorite'] ?? false,
        });
      } catch (e) {
        debugPrint("❌ Failed to load image from $imageUrl: $e");
      }
    }

    if (!mounted) return;
    setState(() {
      savedDishes = loadedDishes;
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
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const CameraPage()),
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
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                dish['title'] ?? 'Dish',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(Icons.close, size: 20),
                            ),
                          ],
                        ),
                      ),
                      TabBar(
                        tabs: const [
                          Tab(child: Text('Description')),
                          Tab(child: Text('Healthier Recipe')),
                          Tab(child: Text('Mimic Recipe')),
                        ],
                        labelColor: Colors.black,
                        indicatorColor: Colors.grey,
                        overlayColor: MaterialStatePropertyAll(Colors.transparent),
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
                              dish['healthyRecipe'] ?? 'No healthy recipe available',
                            ),
                            _buildTabContent(
                              dish['imagePath'],
                              dish['mimicRecipe'] ?? 'No mimic recipe available',
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

  Widget _buildTabContent(String imagePath, String text) {
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
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildSavedDishButton(Map<String, dynamic> dish, int index) {
    return Dismissible(
      key: Key(dish['imagePath'] + index.toString()),
      direction: DismissDirection.endToStart,
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
            debugPrint('Failed to delete dish from Firestore: $e');
          }
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.black,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: AnimatedSlide(
        offset: Offset.zero,
        duration: const Duration(milliseconds: 300),
        child: GestureDetector(
          onTap: () => _showDishPopup(dish),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Image.file(
                      File(dish['imagePath']),
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: Icon(
                          dish['isFavorite'] == true
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _toggleFavorite(index),
                      ),
                    )
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dish['title'] ?? 'Dish',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
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
        title: const Text(
          'The Food Translator',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
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
                      "Open Camera",
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
          if (savedDishes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 140),
              child: Column(
                children: const [
                  Icon(Icons.fastfood, size: 90, color: Colors.grey),
                  SizedBox(height: 22),
                  Text(
                    "No saved dishes yet",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 14),
                  Text(
                    "Tap the camera to translate your first recipe.",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            AnimatedList(
              key: _listKey,
              initialItemCount: savedDishes.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index, animation) {
                final dish = savedDishes[index];
                return SizeTransition(
                  sizeFactor: animation,
                  child: buildSavedDishButton(dish, index),
                );
              },
            ),
        ],
      ),
    );
  }
}