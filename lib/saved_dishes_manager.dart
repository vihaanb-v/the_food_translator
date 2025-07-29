import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SavedDishesManager extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId;

  List<Map<String, dynamic>> _dishes = [];
  bool isLoading = true;

  List<Map<String, dynamic>> get dishes => _dishes;

  SavedDishesManager({required this.userId}) {
    loadDishes();
  }

  Future<void> loadDishes() async {
    try {
      isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dishes')
          .get();

      _dishes = snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();

      isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error loading dishes: $e');
      isLoading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic>? getDishById(String id) {
    return _dishes.firstWhere((dish) => dish['id'] == id, orElse: () => {});
  }

  Future<void> addDish(Map<String, dynamic> dishData) async {
    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('dishes')
        .add(dishData);

    _dishes.add({...dishData, 'id': docRef.id});
    notifyListeners();
  }

  Future<void> deleteDish(String id) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('dishes')
        .doc(id)
        .delete();

    _dishes.removeWhere((dish) => dish['id'] == id);
    notifyListeners();
  }

  void clearDishes() {
    _dishes.clear();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id, bool isFavorite) async {
    final index = _dishes.indexWhere((dish) => dish['id'] == id);
    if (index == -1) return;

    _dishes[index]['isFavorite'] = isFavorite;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('dishes')
        .doc(id)
        .update({'isFavorite': isFavorite});

    notifyListeners();
  }

  Future<void> updateShoppingList(String id, Set<String> healthyChecked, Set<String> mimicChecked) async {
    final index = _dishes.indexWhere((dish) => dish['id'] == id);
    if (index == -1) return;

    _dishes[index]['healthyCheckedIngredients'] = healthyChecked.toList();
    _dishes[index]['mimicCheckedIngredients'] = mimicChecked.toList();

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('dishes')
        .doc(id)
        .update({
      'healthyCheckedIngredients': healthyChecked.toList(),
      'mimicCheckedIngredients': mimicChecked.toList(),
    });

    notifyListeners();
  }

  bool isFavorite(String id) {
    return _dishes
        .firstWhere((dish) => dish['id'] == id,
        orElse: () => {'isFavorite': false})['isFavorite'] ??
        false;
  }

  Set<String> getHealthyCheckedIngredients(String id) {
    return Set<String>.from(
      _dishes
          .firstWhere((dish) => dish['id'] == id,
          orElse: () => {'healthyCheckedIngredients': []})['healthyCheckedIngredients'] ??
          [],
    );
  }

  Set<String> getMimicCheckedIngredients(String id) {
    return Set<String>.from(
      _dishes
          .firstWhere((dish) => dish['id'] == id,
          orElse: () => {'mimicCheckedIngredients': []})['mimicCheckedIngredients'] ??
          [],
    );
  }

  void addDishLocally(Map<String, dynamic> dishData) {
    _dishes.add(dishData);
    notifyListeners();
  }

  List<Map<String, dynamic>> get favoriteDishes =>
      _dishes.where((dish) => dish['isFavorite'] == true).toList();

  List<Map<String, dynamic>> get shoppingListDishes => _dishes.where((dish) {
    final healthy = dish['healthyCheckedIngredients'];
    final mimic = dish['mimicCheckedIngredients'];
    return (healthy != null && (healthy as List).isNotEmpty) ||
        (mimic != null && (mimic as List).isNotEmpty);
  }).toList();
}
