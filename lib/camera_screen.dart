import 'dart:io';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  String _lastAnalyzedHealthy = '';
  String _lastAnalyzedMimic = '';

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

      _analyzeWithGPT(file);
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  Future<void> _analyzeWithGPT(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('http://192.168.68.61:5000/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': base64Image}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Extract all fields from the GPT response
        final rawTitle = (data['title'] as String?)?.trim();
        final description = (data['description'] as String?)?.trim() ??
            "No description available.";
        final healthyRecipe = (data['healthyRecipe'] as String?)?.trim() ??
            "No healthy recipe available.";
        final mimicRecipe = (data['mimicRecipe'] as String?)?.trim() ??
            "No mimic recipe available.";

        // Clean and validate title
        final title = (rawTitle != null && rawTitle.toLowerCase() != "dish" &&
            rawTitle.isNotEmpty)
            ? rawTitle
            : "Unknown Dish";

        // ✅ FIX: Store values so we can use them from the check button too
        setState(() {
          _lastAnalyzedTitle = title;
          _lastAnalyzedDescription = description;
          _lastAnalyzedHealthy = healthyRecipe;
          _lastAnalyzedMimic = mimicRecipe;
        });

        _showFoodPopup(title, description, healthyRecipe, mimicRecipe);
      } else {
        setState(() => _aiDescription = "Error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _aiDescription = "Error analyzing image.");
    }
  }

  void _showExitConfirmationDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Discard Image',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Discard this image?",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Your current image will be lost if you exit.",
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(), // Close dialog
                          child: const Text(
                            "Cancel",
                            style: TextStyle(fontSize: 16, color: Colors.black),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close dialog
                            _retakePicture(); // Reset preview but stay on camera
                          },
                          child: const Text(
                            "Discard",
                            style: TextStyle(fontSize: 16, color: Colors.red),
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
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
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

  void _showFoodPopup(String title,
      String description,
      String healthyRecipe,
      String mimicRecipe,) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Food Description',
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) =>
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery
                    .of(context)
                    .size
                    .height * 0.66,
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
                            Navigator.of(context).pop(); // Close popup
                            _retakePicture();
                          },
                          child: const Text(
                            "Retake",
                            style: TextStyle(fontSize: 14, color: Colors.black),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close the popup
                            _confirmPictureWithDish(
                              title,
                              description,
                              healthyRecipe,
                              mimicRecipe,
                              _capturedImage!.path,
                            );
                          },
                          child: const Text("Save", style: TextStyle(fontSize: 14, color: Colors.blue)),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  void _retakePicture() {
    setState(() {
      _capturedImage = null;
      _showPreview = false;
      _aiDescription = "";
    });
  }

  void _confirmPictureWithDish(
      String title,
      String description,
      String healthy,
      String mimic,
      String imagePath,
      ) async {
    final result = {
      'title': title,
      'description': description,
      'healthyRecipe': healthy,
      'mimicRecipe': mimic,
      'imagePath': imagePath,
      'isFavorite': false,
    };

    print("🔁 Returning to HomeScreen with: $result");
    Navigator.of(context).pop(result);

    // ✅ Save to Firestore AFTER leaving CameraPage
    try {
      final file = File(imagePath);
      final imageBytes = await file.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final dishData = {
        ...result,
        'imageBytes': base64Image,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('savedDishes')
          .add(dishData);
    } catch (e) {
      print("🔥 Firestore save failed: $e");
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
          if (_showPreview && _capturedImage != null)
            Positioned.fill(
              child: Image.file(
                File(_capturedImage!.path),
                fit: BoxFit.contain,
              ),
            )
          else if (cameraController != null &&
              cameraController!.value.isInitialized)
            LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onScaleStart: _handleZoomStart,
                  onScaleUpdate: _handleZoomUpdate,
                  onScaleEnd: _handleZoomEnd,
                  onTapUp: (d) => _handleFocusTap(d, constraints),
                  child: Stack(
                    children: [
                      Center(
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: cameraController!.value.previewSize!.height,
                                height: cameraController!.value.previewSize!.width,
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
                              border: Border.all(color: Colors.yellow, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            )
          else
            const Center(child: CircularProgressIndicator()),

          // ✅ Always-visible ✖ Close button with dynamic behavior
          Positioned(
            top: 50,
            right: 20,
            child: GestureDetector(
              onTap: _handleExitTap,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.black),
              ),
            ),
          ),

          // ✅ Zoom UI (only show during live camera, not in preview)
          if (!_showPreview) ...[
            Positioned(
              bottom: 140,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${_currentZoom.toStringAsFixed(1)}x",
                      style: const TextStyle(color: Colors.black, fontSize: 18),
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
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
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

          // ✅ Loading overlay during GPT analysis
          if (_aiDescription.isNotEmpty)
            Positioned(
              bottom: 80,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _aiDescription,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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