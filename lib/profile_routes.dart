import 'package:flutter/material.dart';

// 🍳 My Dishes Page
class MyDishesPage extends StatelessWidget {
  final List<Map<String, dynamic>> savedDishes;

  const MyDishesPage({super.key, required this.savedDishes});

  @override
  Widget build(BuildContext context) {
    return _SexyScaffold(
      title: "🍽 My Dishes",
      child: ListView.builder(
        itemCount: savedDishes.length,
        itemBuilder: (context, index) {
          final dish = savedDishes[index];
          return ListTile(
            leading: const Icon(Icons.fastfood),
            title: Text(dish['title'] ?? 'Unnamed Dish'),
            subtitle: Text(dish['description'] ?? 'No description'),
          );
        },
      ),
    );
  }
}

// 💖 Favorites Page
class FavoritesPage extends StatelessWidget {
  final List<Map<String, dynamic>> savedDishes;

  const FavoritesPage({super.key, required this.savedDishes});

  @override
  Widget build(BuildContext context) {
    final favoriteDishes = savedDishes.where((dish) => dish['isFavorite'] == true).toList();

    return _SexyScaffold(
      title: "❤️ Favorites",
      child: favoriteDishes.isEmpty
          ? const Center(
        child: Text(
          "No favorites yet. Add some love!",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      )
          : ListView.builder(
        itemCount: favoriteDishes.length,
        itemBuilder: (context, index) {
          final dish = favoriteDishes[index];
          return ListTile(
            leading: const Icon(Icons.favorite, color: Colors.red),
            title: Text(dish['title'] ?? 'Unnamed Dish'),
            subtitle: Text(dish['description'] ?? 'No description'),
          );
        },
      ),
    );
  }
}

// ⚙️ Settings Page
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SexyScaffold(
      title: "⚙️ Settings",
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _SettingTile(icon: Icons.palette, label: "Theme & Appearance"),
          _SettingTile(icon: Icons.notifications, label: "Notifications"),
          _SettingTile(icon: Icons.language, label: "Language"),
          _SettingTile(icon: Icons.lock, label: "Password & Security"),
        ],
      ),
    );
  }
}

// 🔒 Privacy Page
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SexyScaffold(
      title: "🔐 Privacy",
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _PrivacyTile(
            title: "Data Collection",
            description: "We only collect what's needed to make your food experience fire 🔥",
          ),
          _PrivacyTile(
            title: "Delete Account",
            description: "Nuke your account and data if you're done being delicious 😢",
          ),
          _PrivacyTile(
            title: "Privacy Policy",
            description: "Read the fine print – it's shorter than a Gordon Ramsay temper.",
          ),
        ],
      ),
    );
  }
}

// 🔥 Reusable Sexy Scaffold
class _SexyScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const _SexyScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        backgroundColor: Colors.orange[100],
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

// 🛠 Settings Tile
class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SettingTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepOrange),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {},
      ),
    );
  }
}

// 🛡 Privacy Tile
class _PrivacyTile extends StatelessWidget {
  final String title;
  final String description;

  const _PrivacyTile({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(description,
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }
}