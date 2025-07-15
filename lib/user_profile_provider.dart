import 'package:flutter/material.dart';

class UserProfileProvider extends ChangeNotifier {
  String _photoUrl = '';

  String get photoUrl => _photoUrl;

  /// Sets the profile photo URL and notifies listeners
  void setPhotoUrl(String url) {
    _photoUrl = url;
    notifyListeners();
  }

  /// Loads the initial photo URL (e.g., from FirebaseAuth)
  void loadInitial(String? firebaseUrl) {
    if (firebaseUrl != null && firebaseUrl.isNotEmpty) {
      _photoUrl = firebaseUrl;
      notifyListeners();
    }
  }

  /// Optionally clear the photo (e.g., user resets to default)
  void clearPhoto() {
    _photoUrl = '';
    notifyListeners();
  }
}