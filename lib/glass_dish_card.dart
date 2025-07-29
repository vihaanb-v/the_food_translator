import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'saved_dishes_manager.dart';

class GlassDishCard extends StatelessWidget {
  final Map<String, dynamic> dish;
  final bool showPopupOnTap;

  const GlassDishCard({
    super.key,
    required this.dish,
    this.showPopupOnTap = true,
  });

  void _showPopup(BuildContext context) {
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
                      const TabBar(
                        isScrollable: false,
                        padding: EdgeInsets.zero,
                        labelPadding: EdgeInsets.symmetric(horizontal: 2),
                        indicatorPadding: EdgeInsets.zero,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey,
                        overlayColor: WidgetStatePropertyAll(Colors.transparent),
                        labelStyle: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: [
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
                              dish['healthyRecipe'] is Map<String, dynamic> ? dish['healthyRecipe'] : 'No healthy recipe available',
                            ),
                            _buildTabContent(
                              dish['imagePath'],
                              dish['mimicRecipe'] is Map<String, dynamic> ? dish['mimicRecipe'] : 'No mimic recipe available',
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

  Widget _buildTabContent(String? imagePath, dynamic content) {
    final isLocal = imagePath != null && !imagePath.startsWith('http');

    return Column(
      children: [
        if (imagePath != null && imagePath.isNotEmpty)
          isLocal
              ? Image.file(File(imagePath), width: double.infinity, height: 180, fit: BoxFit.cover)
              : Image.network(imagePath, width: double.infinity, height: 180, fit: BoxFit.cover),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: content is String
                    ? Text(content, style: const TextStyle(fontSize: 16))
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
      offset: Offset.zero,
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
            if (nutrition.isNotEmpty) ...[
              divider(),
              sectionTitle(Icons.health_and_safety_outlined, "Nutrition (per serving)"),
              const SizedBox(height: 6),
              Text("• Calories: ${nutrition['calories'] ?? '--'} kcal"),
              Text("• Protein: ${nutrition['protein'] ?? '--'}"),
              Text("• Carbs: ${nutrition['carbs'] ?? '--'}"),
              Text("• Fat: ${nutrition['fat'] ?? '--'}"),
            ],
            divider(),
            sectionTitle(Icons.shopping_cart_outlined, "Ingredients"),
            const SizedBox(height: 6),
            ...List<String>.from(recipe['ingredients'] ?? []).map(
                  (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text("• $item"),
              ),
            ),
            divider(),
            sectionTitle(Icons.restaurant_menu_outlined, "Instructions"),
            const SizedBox(height: 6),
            ...List<String>.from(recipe['instructions'] ?? []).asMap().entries.map(
                  (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text("${entry.key + 1}. ${entry.value}"),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showShoppingListPopup(BuildContext context) {
    String currentTab = 'healthy';
    final dishId = dish['id'] ?? dish['title'] ?? 'unknown';
    final healthyIngredients = (dish['healthyRecipe']?['ingredients'] ?? []).cast<String>();
    final mimicIngredients = (dish['mimicRecipe']?['ingredients'] ?? []).cast<String>();
    final manager = context.read<SavedDishesManager>();

    Set<String> checkedHealthy = Set.from(manager.getHealthyCheckedIngredients(dishId));
    Set<String> checkedMimic = Set.from(manager.getMimicCheckedIngredients(dishId));

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: StatefulBuilder(
                builder: (context, setState) {
                  final ingredients = currentTab == 'healthy' ? healthyIngredients : mimicIngredients;
                  final checked = currentTab == 'healthy' ? checkedHealthy : checkedMimic;

                  return Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.black.withOpacity(0.4), width: 1.2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ToggleButtons(
                              isSelected: [currentTab == 'healthy', currentTab == 'mimic'],
                              onPressed: (index) {
                                setState(() {
                                  currentTab = index == 0 ? 'healthy' : 'mimic';
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              color: Colors.white.withOpacity(0.8),
                              selectedColor: Colors.black,
                              fillColor: Colors.white,
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              constraints: const BoxConstraints(minHeight: 40, minWidth: 100),
                              children: const [Text("Healthy"), Text("Mimic")],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Ingredient list
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: ingredients.length,
                              itemBuilder: (context, index) {
                                final ingredient = ingredients[index];
                                final isChecked = checked.contains(ingredient);

                                return CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    ingredient,
                                    style: TextStyle(
                                      color: isChecked ? Colors.white : Colors.white.withOpacity(0.85),
                                      fontSize: 15,
                                    ),
                                  ),
                                  value: isChecked,
                                  activeColor: Colors.black,
                                  checkColor: Colors.white,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        checked.add(ingredient);
                                      } else {
                                        checked.remove(ingredient);
                                      }

                                      if (currentTab == 'healthy') {
                                        checkedHealthy = checked;
                                        manager.updateShoppingList(dishId, checkedHealthy, checkedMimic);
                                      } else {
                                        checkedMimic = checked;
                                        manager.updateShoppingList(dishId, checkedHealthy, checkedMimic);
                                      }
                                    });
                                  },
                                  controlAffinity: ListTileControlAffinity.leading,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Bottom buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    checked.addAll(ingredients);

                                    if (currentTab == 'healthy') {
                                      checkedHealthy = checked;
                                      manager.updateShoppingList(dishId, checkedHealthy, checkedMimic);
                                    } else {
                                      checkedMimic = checked;
                                      manager.updateShoppingList(dishId, checkedHealthy, checkedMimic);
                                    }
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.black),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text("Add All"),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text("Save"),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    checked.clear();

                                    if (currentTab == 'healthy') {
                                      checkedHealthy = checked;
                                      manager.updateShoppingList(dishId, checkedHealthy, checkedMimic);
                                    } else {
                                      checkedMimic = checked;
                                      manager.updateShoppingList(dishId, checkedHealthy, checkedMimic);
                                    }
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.black),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text("Clear"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
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
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => context.read<SavedDishesManager>().toggleFavorite(dish['id'], !(dish['isFavorite'] ?? false)),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.85),
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                                ),
                                child: Icon(
                                  dish['isFavorite'] == true ? Icons.favorite : Icons.favorite_border,
                                  color: Colors.redAccent,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Stack(
                      children: [
                        Column(
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
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showShoppingListPopup(context),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 6,
                                    offset: const Offset(2, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.shopping_cart_outlined, color: Colors.black, size: 20),
                              ),
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
        ),
      ),
    );
  }
}

class _PopupContent extends StatelessWidget {
  final String? imagePath;
  final dynamic content;

  const _PopupContent(this.imagePath, this.content);

  Widget _buildContent(dynamic content) {
    if (content is String) {
      return Text(
        content,
        style: const TextStyle(fontSize: 16),
      );
    } else if (content is Map<String, dynamic>) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (content['title'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                content['title'],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          if (content['ingredients'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                "Ingredients:\n${(content['ingredients'] as List).join(', ')}",
                style: const TextStyle(fontSize: 15),
              ),
            ),
          if (content['instructions'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                "Instructions:\n${content['instructions']}",
                style: const TextStyle(fontSize: 15),
              ),
            ),
          if (content['nutrition'] != null)
            Text(
              "Nutrition:\n${content['nutrition']}",
              style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic),
            ),
        ],
      );
    } else {
      return const Text(
        'No content available',
        style: TextStyle(fontSize: 16),
      );
    }
  }

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
                child: _buildContent(content),
              ),
            ),
          ),
        ),
      ],
    );
  }
}