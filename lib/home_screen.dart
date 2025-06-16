import 'dart:io';
import 'package:flutter/material.dart';
import 'camera_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
    showDialog(
      context: context,
      builder: (context) {
        return DefaultTabController(
          length: 3,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      dish['title'] ?? 'Dish',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const TabBar(
                    tabs: [
                      Tab(text: 'Description'),
                      Tab(text: 'Healthier Recipe'),
                      Tab(text: 'Mimic Recipe'),
                    ],
                    labelColor: Colors.black,
                    indicatorColor: Colors.deepOrange,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildTabContent(dish['description'] ?? 'No description'),
                        _buildTabContent(dish['healthyRecipe'] ?? 'No healthy recipe available'),
                        _buildTabContent(dish['mimicRecipe'] ?? 'No mimic recipe available'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabContent(String text) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Scrollbar(
        child: SingleChildScrollView(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget buildSavedDishButton(Map<String, dynamic> dish) {
    return GestureDetector(
      onTap: () {
        print("Tapped: ${dish['title']}"); // ✅ Add debug print
        _showDishPopup(dish);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: FileImage(File(dish['imagePath'])),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
          ),
        ),
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.all(12),
        child: Text(
          dish['title'] ?? 'Dish',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 2, color: Colors.black)],
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
          ...savedDishes.map(buildSavedDishButton).toList(),
        ],
      ),
    );
  }
}
