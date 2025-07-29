import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dialogs.dart';
import 'my_dishes_page.dart';
import 'favorites_page.dart';
import 'navigation_utils.dart';
import 'package:provider/provider.dart';
import 'user_profile_provider.dart';
import 'auth_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser!;
  String? updatedPhotoUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    updatedPhotoUrl = user.photoURL;
  }

  Future<void> _showImagePickerOptions() async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.black.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 28),
                    const SizedBox(height: 12),
                    const Text(
                      "Update Profile Picture",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Take a Photo"),
                      style: _pickerButtonStyle(),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text("Choose from Gallery"),
                      style: _pickerButtonStyle(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  ButtonStyle _pickerButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploading = true); // 🔥 Start loader

    final url = await _uploadToCloudinary(File(picked.path));

    if (url != null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await user.updatePhotoURL('$url?v=$timestamp');
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser!;
      setState(() => updatedPhotoUrl = refreshedUser.photoURL);

      Provider.of<UserProfileProvider>(context, listen: false)
          .setPhotoUrl(refreshedUser.photoURL ?? '');
    }

    setState(() => _isUploading = false); // ✅ End loader
  }

  Future<String?> _uploadToCloudinary(File imageFile) async {
    final uid = user.uid;
    final publicId = 'pfp_$uid';
    final folder = 'users/$uid';
    const uploadPreset = 'flutter_user_upload';
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

    try {
      // 1️⃣ Get Signature from backend
      final sigResponse = await http.post(
        Uri.parse("http://192.168.68.61:5000/cloudinary-signature"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "folder": folder,
          "public_id": publicId,
          "timestamp": timestamp,
          "upload_preset": uploadPreset,
        }),
      );

      if (sigResponse.statusCode != 200) {
        debugPrint("❌ Signature request failed: ${sigResponse.body}");
        return null;
      }

      final sigData = jsonDecode(sigResponse.body);
      final cloudName = sigData["cloud_name"];
      final apiKey = sigData["api_key"];
      final signature = sigData["signature"];
      final signedTimestamp = sigData["timestamp"];
      final signedPublicId = sigData["public_id"];
      final signedFolder = sigData["folder"];
      final signedUploadPreset = sigData["upload_preset"];

      // 2️⃣ Upload to Cloudinary
      final uploadRequest = http.MultipartRequest(
        "POST",
        Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload"),
      )
        ..fields["api_key"] = apiKey
        ..fields["folder"] = signedFolder
        ..fields["public_id"] = signedPublicId
        ..fields["signature"] = signature
        ..fields["timestamp"] = signedTimestamp
        ..fields["upload_preset"] = signedUploadPreset
        ..files.add(await http.MultipartFile.fromPath("file", imageFile.path));

      final uploadResponse = await uploadRequest.send();
      final responseBody = await uploadResponse.stream.bytesToString();

      if (uploadResponse.statusCode == 200) {
        final jsonResp = json.decode(responseBody);
        return jsonResp["secure_url"];
      } else {
        debugPrint("❌ Upload failed: $responseBody");
        return null;
      }
    } catch (e) {
      debugPrint("🔥 Upload error: $e");
      return null;
    }
  }

  Widget _buildMainContent(String email, String? photoUrl) {
    return Stack(
      children: [
        SizedBox(
          height: 300,
          width: double.infinity,
          child: Image.asset('assets/logo.png', fit: BoxFit.cover),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 300,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 30),
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: _showImagePickerOptions,
                    child: Hero(
                      tag: 'profile-pic',
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          key: ValueKey(photoUrl),
                          radius: 60,
                          backgroundColor: Colors.white,
                          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                              ? NetworkImage(photoUrl)
                              : const AssetImage('assets/profile_placeholder.jpg') as ImageProvider,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: _showImagePickerOptions,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.edit, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "Disypher",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ListView(
                    children: [
                      const SizedBox(height: 4),
                      GlassTile(
                        icon: Icons.history,
                        title: "My Dishes",
                        onTap: () => smoothPush(context, const MyDishesPage()),
                      ),
                      const SizedBox(height: 10),
                      GlassTile(
                        icon: Icons.favorite,
                        title: "Favorites",
                        onTap: () => smoothPush(context, const FavoritesPage()),
                      ),
                      const SizedBox(height: 10),
                      GlassTile(
                        icon: Icons.settings,
                        title: "Settings",
                        onTap: () => Navigator.pushNamed(context, '/settings'),
                      ),
                      const SizedBox(height: 10),
                      GlassTile(
                        icon: Icons.logout,
                        title: "Log Out",
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            barrierDismissible: true,
                            builder: (context) => Dialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              insetPadding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      "Are you sure?",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      "Do you really want to log out?",
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
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: const Text("Cancel", style: TextStyle(fontSize: 15)),
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
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: const Text("Log Out", style: TextStyle(fontSize: 15)),
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                          if (confirmed == true) {
                            showLoadingDialog(context, "Logging out...");
                            await Future.delayed(const Duration(milliseconds: 1200));

                            await FirebaseAuth.instance.signOut(); // 👈 This alone updates auth state

                            if (context.mounted) {
                              Navigator.of(context).pop(); // Close loading dialog
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(36, 0, 36, 24),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text("Back to Home", style: TextStyle(fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = updatedPhotoUrl;
    final email = user.email ?? "Unknown";

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          _buildMainContent(email, photoUrl),
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class GlassTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const GlassTile({super.key, required this.icon, required this.title, this.onTap});

  @override
  State<GlassTile> createState() => _GlassTileState();
}

class _GlassTileState extends State<GlassTile> {
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        setState(() => _isTapped = true);
        Future.delayed(const Duration(milliseconds: 200), () {
          setState(() => _isTapped = false);
          if (widget.onTap != null) widget.onTap!();
        });
      },
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.8),
              Colors.white.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            if (_isTapped)
              BoxShadow(
                color: Colors.orangeAccent.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black26.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
          ],
          border: Border.all(color: Colors.black.withOpacity(0.15), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ListTile(
              leading: Icon(widget.icon, color: Colors.black, size: 26),
              title: Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Colors.black87,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
            ),
          ),
        ),
      ),
    );
  }
}