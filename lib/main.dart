import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

late List<CameraDescription> cameras;
const double guideBoxSize = 220;

Future<void> main() async {
  WidgetsBinding widgetsBinding =
    WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AquaSight',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C5364),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Interpreter? _interpreter;
  File? _image;

  final labels = ['Clear', 'Cloudy', 'Murky'];
  final double confThreshold = 0.80;
  final double marginThreshold = 0.15;

  bool isModelLoaded = false;
  bool isAnalyzing = false;

  double confidenceValue = 0.0;
  String result = "Initializing AI model...";

  File imageToFile(img.Image image) {
    final tempDir = Directory.systemTemp;
    final path =
        "${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.png";

    final file = File(path);
    file.writeAsBytesSync(img.encodePng(image));
    return file;
  }

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');

      if (!mounted) return;

      setState(() {
        isModelLoaded = true;
        result = "Model is ready! Awaiting image...";
      });
      FlutterNativeSplash.remove();

    } catch (e) {
      setState(() {
        result = "Error loading model!";
      });
      FlutterNativeSplash.remove();
    }
  }

  Future<void> pickImage(ImageSource source) async {
    if (!isModelLoaded) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (!mounted || pickedFile == null) return;

    setState(() {
      _image = File(pickedFile.path);
    });

    runModel(_image!);
  }

  Future<Map<String, dynamic>> preprocess(File file) async{
    final bytes = await file.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (image == null) return {};

    if (image.width > 1000 || image.height > 1000) {
      image = img.copyResize(image, width: 1000);
    }

    // 🔥 CENTER CROP
    int size = min(image.width, image.height);

    int offsetX = (image.width - size) ~/ 2;
    int offsetY = (image.height - size) ~/ 2;

    img.Image cropped = img.copyCrop(
      image,
      x: offsetX,
      y: offsetY,
      width: size,
      height: size,
    );

    // 🔄 Resize separately (IMPORTANT)
    img.Image resized = img.copyResize(cropped, width: 224, height: 224);

    var input = [
      List.generate(
        224,
        (y) => List.generate(
          224,
          (x) {
            final pixel = resized.getPixel(x, y); // ✅ FIXED
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      )
    ];

    return {
      "input": input,
      "cropped": cropped, // original cropped (not resized)
    };
  }

  void runModel(File file) async {
    if (_interpreter == null) return;

    setState(() {
      isAnalyzing = true;
      result = "Analyzing...";
    });

    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    var processed = await preprocess(file);
    if (processed.isEmpty) return;
    var input = processed["input"];
    img.Image croppedImage = processed["cropped"];



    var output = List.generate(1, (_) => List.filled(3, 0.0));

    _interpreter!.run(input, output);

    List<double> probs = output[0];

    int maxIndex = probs.indexWhere((e) => e == probs.reduce(max));
    double maxConf = probs[maxIndex];

    List<double> sorted = [...probs]..sort();
    double margin = sorted[2] - sorted[1];

    String prediction;

    if (maxConf < confThreshold || margin < marginThreshold) {
      prediction = "Not Water";
    } else {
      prediction = labels[maxIndex];
    }

    if (!mounted) return;

    setState(() {
      isAnalyzing = false;
      confidenceValue = maxConf;
      result = prediction;
      _image = imageToFile(croppedImage); // ✅ now correct
    });
  }

  Future<void> openCamera() async {
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          onCapture: (file) {
            if (!mounted) return;

            setState(() {
              _image = file;
            });

            runModel(file);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,

        // EXIT LEFT
        leading: IconButton(
          icon: const Icon(Icons.exit_to_app, color: Colors.white),
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Exit App"),
                content:
                    const Text("Are you sure you want to exit?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      SystemNavigator.pop();
                    },
                    child: const Text("Exit"),
                  ),
                ],
              ),
            );
          },
        ),

        title: const Text(
          "AquaSight",
          style: TextStyle(color: Colors.white),
        ),

        // HELP RIGHT
        actions: [
          IconButton(
            icon:
                const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("How to Use"),
                  content: const Text(
                    "1. Capture or upload water image\n"
                    "2. Center the container\n"
                    "3. Wait for analysis\n"
                    "4. View result and confidence",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context),
                      child: const Text("Got it"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 10),

                // IMAGE + SCAN EFFECT
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(20),
                          color:
                              Colors.black.withValues(alpha: 0.3),
                        ),
                        child: _image != null
                            ? ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(20),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 400),
                                  transitionBuilder: (child, animation) {
                                    return ScaleTransition(
                                      scale: animation,
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    key: ValueKey(_image!.path), // 🔥 IMPORTANT
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.file(
                                      _image!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              )
                        : const Center(
                            child: Text(
                              "Capture or upload water image",
                              style: TextStyle(
                                  color: Colors.white70),
                            ),
                              ),
                      ),

                      if (_image != null && !isAnalyzing)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "AI Focus Area",
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      if (isAnalyzing)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(20),
                              gradient:
                                  const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white24,
                                  Colors.transparent
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                      if (isAnalyzing) 
                        const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white, 
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // BUTTONS
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed:
                          isModelLoaded ? openCamera : null,
                      icon:
                          const Icon(Icons.camera_alt),
                      label: const Text("Camera"),
                    ),
                    ElevatedButton.icon(
                      onPressed: isModelLoaded
                          ? () => pickImage(
                              ImageSource.gallery)
                          : null,
                      icon: const Icon(Icons.photo),
                      label: const Text("Gallery"),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // RESULT + CONFIDENCE
                Container(
                  constraints: const BoxConstraints(
                    minHeight: 100,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // 🔥 INLINE STATUS (TEXT + SPINNER SIDE BY SIDE)
                      if (isAnalyzing)
                        SizedBox(
                          height: 70,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                "Analyzing...",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                              SizedBox(width: 10),
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        )
                      
                      else
                        Text(
                          result,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),

                      const SizedBox(height: 10),

                      // 🔥 CONFIDENCE BAR (only when NOT analyzing)
                      if (!isAnalyzing)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: confidenceValue),
                          duration: const Duration(milliseconds: 800),
                          builder: (context, value, _) {
                            return Column(
                              children: [
                                LinearProgressIndicator(
                                  value: value,
                                  minHeight: 8,
                                  backgroundColor: Colors.white24,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "Confidence: ${(value * 100).toStringAsFixed(1)}%",
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                             );
                          },
                        ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final Function(File) onCapture;
  const CameraScreen({
    super.key, 
    required this.onCapture,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> 
    with SingleTickerProviderStateMixin {
  CameraController? controller;
  bool isReady = false;
  bool isScanning = false;
  int currentCameraIndex = 0;
  FlashMode flashMode = FlashMode.off;
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    initCamera();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  Future<void> initCamera() async {
    controller = CameraController(
      cameras[currentCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller!.initialize();

    // 🔥 Stabilize camera (important for ML consistency)
    await controller!.setFocusMode(FocusMode.auto);
    await controller!.setExposureMode(ExposureMode.auto);

    if (!mounted) return;

    setState(() => isReady = true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    controller?.dispose();
    super.dispose();
  }

  Future<void> captureImage() async {
    if (!controller!.value.isInitialized) return;
    setState(() => isScanning = true);
    _scanController.repeat(reverse: true); // 🔥 start effect
    await Future.delayed(const Duration(milliseconds: 300));
    final image = await controller!.takePicture();

    if (!mounted) return;
    widget.onCapture(File(image.path));
    _scanController.stop(); // 🔥 stop effect
    Navigator.pop(context);
  }

  Future<void> switchCamera() async {
    currentCameraIndex =
        (currentCameraIndex + 1) % cameras.length;

    await controller?.dispose();
    await initCamera();
  }

  Future<void> toggleFlash() async {
    flashMode = flashMode == FlashMode.off
        ? FlashMode.torch
        : FlashMode.off;

    await controller?.setFlashMode(flashMode);

    if (!mounted) return;

    setState(() {});
  }

  Future<void> importImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery);

    if (!mounted || picked == null) return;

    widget.onCapture(File(picked.path));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!isReady) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 📷 Camera Preview
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller!.value.previewSize!.height,
                height: controller!.value.previewSize!.width,
                child: CameraPreview(controller!),
              ),
            ),
          ),

          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.5),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: guideBoxSize,
                      height: guideBoxSize,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🎯 GUIDE BOX
          Positioned.fill(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 🔵 MAIN BOX
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isScanning ? Colors.cyanAccent : Colors.white70,
                        width: 3,
                      ),
                      boxShadow: isScanning
                          ? [
                              BoxShadow(
                                color: Colors.cyanAccent.withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                  ),

                  // ⚡ SCANNING BEAM
                  if (isScanning)
                    AnimatedBuilder(
                      animation: _scanController,
                      builder: (context, child) {
                        double value = (_scanController.value * 220) - 110;

                        return Positioned(
                          top: value + 110,
                          child: Container(
                            width: 220,
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.cyanAccent,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // 🧠 INSTRUCTION TEXT
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "Align container inside box",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ),
          ),

          // ⚡ FLASH (Top Left)
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: Icon(
                flashMode == FlashMode.off
                    ? Icons.flash_off
                    : Icons.flash_on,
                color: Colors.white,
              ),
              onPressed: toggleFlash,
            ),
          ),

          // ❌ BACK (Top Right)
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 🎛️ BOTTOM CONTROLS
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
              children: [
                // 📁 Import
                IconButton(
                  icon: const Icon(Icons.photo,
                      color: Colors.white),
                  onPressed: importImage,
                ),

                // 📸 Capture
                GestureDetector(
                  onTap: captureImage,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white, width: 4),
                    ),
                  ),
                ),

                // 🔄 Switch Camera
                IconButton(
                  icon: const Icon(Icons.cameraswitch,
                      color: Colors.white),
                  onPressed: switchCamera,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}