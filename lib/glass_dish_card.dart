import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

class GlassDishCard extends StatelessWidget {
  final Map<String, dynamic> dish;
  final VoidCallback? onFavoriteToggle;
  final bool showPopupOnTap;

  const GlassDishCard({
    super.key,
    required this.dish,
    this.onFavoriteToggle,
    this.showPopupOnTap = true,
  });

  void _showPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: DefaultTabController(
          length: 3,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            width: MediaQuery.of(context).size.width * 0.9,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dish['title'] ?? 'Dish',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                const TabBar(
                  tabs: [
                    Tab(child: Text('Description')),
                    Tab(child: Text('Healthier Recipe')),
                    Tab(child: Text('Mimic Recipe')),
                  ],
                  labelColor: Colors.black,
                  indicatorColor: Colors.grey,
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _PopupContent(dish['imagePath'], dish['description']),
                      _PopupContent(dish['imagePath'], dish['healthyRecipe']),
                      _PopupContent(dish['imagePath'], dish['mimicRecipe']),
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

  @override
  Widget build(BuildContext context) {
    final imagePath = dish['imagePath'];
    final isLocal = imagePath != null && !imagePath.toString().startsWith('http');
    final hasImage = imagePath != null && imagePath.toString().isNotEmpty;

    return GestureDetector(
      onTap: showPopupOnTap ? () => _showPopup(context) : null,
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
                  // 📸 Image
                  Stack(
                    children: [
                      if (hasImage)
                        isLocal
                            ? Image.file(
                          File(imagePath),
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                        )
                            : Image.network(
                          imagePath,
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
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
                      // ❤️ Favorite button only (no delete)
                      if (onFavoriteToggle != null)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: GestureDetector(
                            onTap: onFavoriteToggle,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.85),
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
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
    );
  }
}

class _PopupContent extends StatelessWidget {
  final String? imagePath;
  final String? text;

  const _PopupContent(this.imagePath, this.text);

  @override
  Widget build(BuildContext context) {
    final isLocal = imagePath != null && !imagePath!.startsWith('http');

    return Column(
      children: [
        if (imagePath != null && imagePath!.isNotEmpty)
          isLocal
              ? Image.file(File(imagePath!), width: double.infinity, height: 180, fit: BoxFit.cover)
              : Image.network(imagePath!, width: double.infinity, height: 180, fit: BoxFit.cover),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Text(
                  text ?? 'No content available',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
