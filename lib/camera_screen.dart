import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with SingleTickerProviderStateMixin {
  List<CameraDescription> cameras = [];
  CameraController? cameraController;
  XFile? _capturedImage;
  bool _showPreview = false;
  String _aiDescription = "";
  String _lastAnalyzedTitle = '';
  String _lastAnalyzedDescription = '';
  Map<String, dynamic> _lastAnalyzedHealthy = {};
  Map<String, dynamic> _lastAnalyzedMimic = {};
  String _lastImageUrl = '';
  String _userCaption = '';

  double _currentZoom = 1.0;
  final double _minZoom = 1.0;
  final double _maxZoom = 3.0;
  double _initialZoom = 1.0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  Offset? _tapPosition;
  bool _showFocusBox = false;

  @override
  void initState() {
    super.initState();
    _setupCameraController();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    cameraController?.dispose();
    super.dispose();
  }

  Future<void> _setupCameraController() async {
    cameras = await availableCameras();
    if (cameras.isEmpty) return;

    cameraController = CameraController(
      cameras.first,
      ResolutionPreset.max,
      enableAudio: false,
    );

    await cameraController!.initialize();
    _currentZoom = 1.0;
    await cameraController!.setZoomLevel(_currentZoom);

    if (mounted) setState(() {});
  }

  void _handleZoomStart(ScaleStartDetails details) {
    _initialZoom = _currentZoom;
    _fadeController.forward();
  }

  void _handleZoomUpdate(ScaleUpdateDetails details) async {
    final newZoom = (_initialZoom * details.scale)
        .clamp(_minZoom, _maxZoom)
        .toDouble();

    if (newZoom != _currentZoom) {
      setState(() => _currentZoom = newZoom);
      await cameraController?.setZoomLevel(newZoom);
    }
  }

  void _handleZoomEnd(ScaleEndDetails details) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) _fadeController.reverse();
  }

  void _handleFocusTap(TapUpDetails details, BoxConstraints constraints) async {
    if (cameraController == null || !cameraController!.value.isInitialized)
      return;

    final local = details.localPosition;
    final normalized = Offset(
      local.dx / constraints.maxWidth,
      local.dy / constraints.maxHeight,
    );

    setState(() {
      _tapPosition = local;
      _showFocusBox = true;
    });

    await cameraController!.setFocusPoint(normalized);
    await cameraController!.setExposurePoint(normalized);

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showFocusBox = false);
    });
  }

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final File file = File(pickedFile.path);

      // ✅ Set same preview state
      setState(() {
        _capturedImage = pickedFile;
        _showPreview = true;
        _aiDescription = "Analyzing food...";
      });

      await _promptUserCaption(file);
    }
  }

  void _takePicture() async {
    try {
      final image = await cameraController!.takePicture();

      // ✅ Delay to ensure file is fully written
      await Future.delayed(const Duration(milliseconds: 300));

      final file = File(image.path);
      // ✅ Confirm the file exists and has content before proceeding
      while (!file.existsSync() || file.lengthSync() == 0) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      setState(() {
        _capturedImage = image;
        _showPreview = true;
        _aiDescription = "Analyzing food...";
      });

      await _promptUserCaption(file);
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  Future<void> _promptUserCaption(File imageFile) async {
    _userCaption = '';
    final TextEditingController _controller = TextEditingController();
    final FocusNode _focusNode = FocusNode();

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Caption Input",
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) {
        return Center( // ✅ Always centered
          child: Material(
            color: Colors.transparent,
            child: StatefulBuilder(
              builder: (context, setState) {
                final bottomInset = MediaQuery.of(context).viewInsets.bottom;

                return AnimatedPadding(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    bottom: bottomInset > 0 ? bottomInset : 0, // ✅ Push up only when keyboard opens
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white30, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: IntrinsicHeight(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "Add your flavor note",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                maxLength: 100,
                                autofocus: false,
                                style: const TextStyle(color: Colors.white),
                                cursorColor: Colors.white,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {}, // do not submit on done
                                onChanged: (value) {
                                  setState(() => _userCaption = value);
                                },
                                decoration: InputDecoration(
                                  hintText: "Describe the dish...",
                                  hintStyle: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                  counterStyle: const TextStyle(color: Colors.white38),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Colors.white30),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Colors.white),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text(
                                      "Skip",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _userCaption.trim().isNotEmpty
                                          ? Colors.black
                                          : Colors.black.withOpacity(0.3),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      elevation: _userCaption.trim().isNotEmpty ? 6 : 0,
                                      shadowColor: Colors.black54,
                                    ),
                                    onPressed: _userCaption.trim().isNotEmpty
                                        ? () => Navigator.of(context).pop()
                                        : null,
                                    child: const Text(
                                      "Submit",
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );

    await _analyzeWithGPT(imageFile);
  }

  void _showUnknownDishPopup(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Unknown Dish",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white30, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.amber),
                      const SizedBox(height: 12),
                      const Text(
                        "Dish Not Recognized",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "We couldn't confidently identify this dish. Try using a clearer, closer, or more focused photo.",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _resetAfterUnknownDish();
                        },
                        child: const Text(
                          "Okay, Got It",
                          style: TextStyle(fontSize: 16),
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
      transitionBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }

  void _resetAfterUnknownDish() async {
    // Delete the old image if it exists
    if (_capturedImage != null) {
      final file = File(_capturedImage!.path);
      if (await file.exists()) {
        try {
          await file.delete();
          debugPrint("🗑️ Deleted unrecognized image: ${file.path}");
        } catch (e) {
          debugPrint("⚠️ Failed to delete image: $e");
        }
      }
    }

    setState(() {
      _capturedImage = null;
      _showPreview = false;
      _aiDescription = "";
      _lastImageUrl = '';
      _lastAnalyzedTitle = '';
      _lastAnalyzedDescription = '';
      _lastAnalyzedHealthy = {};
      _lastAnalyzedMimic = {};
    });

    try {
      if (cameraController != null && !cameraController!.value.isInitialized) {
        await cameraController!.initialize(); // ✅ This will start the preview
        debugPrint("🔁 Reinitialized camera after unknown dish.");
      }
    } catch (e) {
      debugPrint("❌ Error reinitializing camera: $e");
    }
  }

  Future<void> _analyzeWithGPT(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http
          .post(
        Uri.parse('http://192.168.68.61:5000/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image': base64Image,
          'caption': _userCaption.trim(),
        }),
      )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        // 🔁 EARLY EXIT: Unknown dish trigger
        if (data['trigger'] == 'show_unknown_popup') {
          debugPrint("⚠️ Backend says unknown dish. Aborting analysis.");

          // ❌ Reset state to default as if camera just opened
          setState(() {
            _aiDescription = "";
            _lastImageUrl = '';
            _lastAnalyzedTitle = '';
            _lastAnalyzedDescription = '';
            _lastAnalyzedHealthy = {};
            _lastAnalyzedMimic = {};
          });

          // 🧼 Show popup and stay on camera
          _showUnknownDishPopup(context);
          return; // ⛔ Stop further processing
        }

        // ✅ Proceed normally if dish is recognized
        final rawTitle = (data['title'] as String?)?.trim();
        final description = (data['description'] as String?)?.trim() ?? "No description available.";
        final healthyRecipe = data['healthyRecipe'] ?? {};
        final mimicRecipe = data['mimicRecipe'] ?? {};
        final imageUrl = (data['imageUrl'] as String?)?.trim() ?? "";
        if (imageUrl.isEmpty) {
          debugPrint("❌ No image URL returned. Aborting...");
          setState(() => _aiDescription = "Failed to get image URL.");
          return;
        }

        final title = (rawTitle != null && rawTitle.toLowerCase() != "dish" && rawTitle.isNotEmpty)
            ? rawTitle
            : "Unknown Dish";

        setState(() {
          _lastImageUrl = imageUrl;
          _lastAnalyzedTitle = title;
          _lastAnalyzedDescription = description;
          _lastAnalyzedHealthy = healthyRecipe;
          _lastAnalyzedMimic = mimicRecipe;
          _aiDescription = "";
        });

        _showFoodPopup(title, description, healthyRecipe, mimicRecipe);
      } else {
        setState(() => _aiDescription = "Server error: ${response.statusCode}");
        debugPrint("⚠️ Server responded with status ${response.statusCode}: ${response.body}");
      }
    } on TimeoutException {
      setState(() => _aiDescription = "Server timed out. Try again.");
      debugPrint("❌ GPT analysis request timed out.");
    } catch (e) {
      setState(() => _aiDescription = "Error analyzing image.");
      debugPrint("🔥 Exception during GPT analysis: $e");
    }
  }

  void _showExitConfirmationDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Discard Image',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 36, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    const Text(
                      "Discard this image?",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Your current image will be lost if you exit.",
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(color: Colors.black87, fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _retakePicture();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              "Discard",
                              style: TextStyle(color: Colors.white, fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }

  void _handleExitTap() {
    if (_showPreview) {
      _showExitConfirmationDialog();
    } else {
      Navigator.of(context).pop(); // Exit immediately if no photo taken
    }
  }

  void _showFoodPopup(
      String title,
      String description,
      Map<String, dynamic> healthyRecipe,
      Map<String, dynamic> mimicRecipe,
      ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Food Description',
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.66,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        child: Text(
                          description.isEmpty
                              ? "No description available."
                              : description,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close popup only
                          _retakePicture();
                        },
                        child: const Text(
                          "Retake",
                          style: TextStyle(fontSize: 14, color: Colors.black),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final navigator = Navigator.of(context); // ✅ Capture early
                          navigator.pop(); // Close the popup

                          final result = await _confirmPictureWithDish(
                            title,
                            description,
                            healthyRecipe,
                            mimicRecipe,
                          );

                          if (!mounted) return;

                          navigator.pop(result ?? {}); // ✅ Always return to Home
                        },
                        child: const Text(
                          "Save",
                          style: TextStyle(fontSize: 14, color: Colors.blue),
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
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  void _retakePicture() async {
    // ✅ Delete the old image from disk if it exists
    if (_capturedImage != null) {
      final file = File(_capturedImage!.path);
      if (await file.exists()) {
        try {
          await file.delete();
          debugPrint("🗑️ Deleted discarded image: ${file.path}");
        } catch (e) {
          debugPrint("⚠️ Failed to delete image: $e");
        }
      }
    }

    // ✅ Reset state
    setState(() {
      _capturedImage = null;
      _showPreview = false;
      _aiDescription = "";
      _lastAnalyzedTitle = '';
      _lastAnalyzedDescription = '';
      _lastAnalyzedHealthy = {};
      _lastAnalyzedMimic = {};
    });
  }

  Future<Map<String, dynamic>?> _confirmPictureWithDish(
      String title,
      String description,
      Map<String, dynamic> healthy,
      Map<String, dynamic> mimic,
      ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print("❌ No user signed in.");
      return null;
    }

    if (_lastImageUrl.isEmpty) {
      print("🚨 No Cloudinary image URL available.");
      // Still return a fallback result so user is not stuck
      return {
        'title': title,
        'description': description,
        'healthyRecipe': healthy,
        'mimicRecipe': mimic,
        'imageUrl': '',
        'imagePath': '',
        'isFavorite': false,
      };
    }

    final result = {
      'title': title,
      'description': description,
      'healthyRecipe': healthy,
      'mimicRecipe': mimic,
      'imageUrl': '$_lastImageUrl?f_auto,q_auto',
      'imagePath': '$_lastImageUrl?f_auto,q_auto',
      'isFavorite': false,
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('savedDishes')
          .add({
        ...result,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _aiDescription = "";
      });

      return result;
    } catch (e) {
      print("🔥 Error saving to Firestore: $e");
      return result;
    }
  }

  Future<void> saveDishToFirestore(Map<String, dynamic> dishData) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedDishes')
        .add(dishData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ✅ Camera Preview OR Captured Image OR Loading
          Positioned.fill(
            child: _showPreview && _capturedImage != null
                ? Image.file(
              File(_capturedImage!.path),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return const Center(
                  child: Text(
                    "⚠️ Could not load image",
                    style: TextStyle(color: Colors.white),
                  ),
                );
              },
            )
                : (cameraController != null &&
                cameraController!.value.isInitialized)
                ? LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onScaleStart: _handleZoomStart,
                  onScaleUpdate: _handleZoomUpdate,
                  onScaleEnd: _handleZoomEnd,
                  onTapUp: (d) =>
                      _handleFocusTap(d, constraints),
                  child: Stack(
                    children: [
                      Center(
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: cameraController!.value
                                    .previewSize!.height,
                                height: cameraController!.value
                                    .previewSize!.width,
                                child: CameraPreview(cameraController!),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_showFocusBox && _tapPosition != null)
                        Positioned(
                          left: _tapPosition!.dx - 30,
                          top: _tapPosition!.dy - 30,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.yellow, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            )
                : const Center(child: CircularProgressIndicator()),
          ),
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Upload Button
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[900],
                      border: Border.all(color: Colors.white24, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _pickImageFromGallery,
                        child: const Center(
                          child: Icon(
                            Icons.photo_library_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Cancel Button — perfectly matched
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white24, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _handleExitTap,
                        child: const Center(
                          child: Icon(
                            Icons.close,
                            color: Colors.black,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ✅ Zoom UI (only when camera is active)
          if (!_showPreview && cameraController != null)
            ...[
              Positioned(
                bottom: 140,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Center(
                    child: Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${_currentZoom.toStringAsFixed(1)}x",
                        style: const TextStyle(
                            color: Colors.black, fontSize: 18),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 120,
                left: 40,
                right: 40,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white38,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white24,
                      trackHeight: 4.0,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8.0),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16.0),
                    ),
                    child: Slider(
                      value: _currentZoom,
                      min: _minZoom,
                      max: _maxZoom,
                      onChanged: (value) async {
                        setState(() => _currentZoom = value);
                        await cameraController?.setZoomLevel(value);
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

          // ✅ GPT Analysis Overlay
          if (_aiDescription.isNotEmpty)
            Positioned(
              bottom: 80,
              left: 20,
              right: 20,
              child: Container(
                padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _aiDescription,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}