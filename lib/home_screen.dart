import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'camera_screen.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({super.key});

  final user = FirebaseAuth.instance.currentUser!;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> savedDishes = [];

  void _openCamera() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraPage()),
    );

    print("Returned from camera: $result");

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        savedDishes.add(result);
      });
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
                        labelPadding: EdgeInsets.zero, // no extra padding inside tabs
                        padding: EdgeInsets.zero, // no outer padding on TabBar
                        indicatorPadding: EdgeInsets.zero,
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
      onDismissed: (_) {
        setState(() {
          savedDishes.removeAt(index);
        });
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
                Image.file(
                  File(dish['imagePath']),
                  width: double.infinity,
                  height: 140,
                  fit: BoxFit.cover,
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    dish['title'] ?? 'Dish',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("The Food Translator"),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Log out',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                // Optional: Navigate to login screen if needed
                // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthPage()));
              },
            ),
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
            ...savedDishes.asMap().entries.map((entry) => buildSavedDishButton(entry.value, entry.key)).toList(),
        ],
      ),
    );
  }
}
