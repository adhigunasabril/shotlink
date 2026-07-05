import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:url_launcher/url_launcher.dart';
import 'parser.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Error initializing cameras: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open Photo Link',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6366F1),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        fontFamily: 'Roboto',
      ),
      home: const CameraScanScreen(),
    );
  }
}

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({Key? key}) : super(key: key);

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isPermissionGranted = false;
  bool _isProcessing = false;
  bool _isScanning = true;
  DateTime? _lastProcessedTime;

  // ML Kit instances
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final BarcodeScanner _barcodeScanner = BarcodeScanner();

  // Detection Results
  String? _detectedText;
  Map<String, dynamic>? _detectedData; // {"type": "phone"|"sosmed"|"link", "value": "..."}
  String? _intentUri;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _textRecognizer.close();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      final camera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium, // 720p as requested
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isPermissionGranted = true;
      });

      _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
      setState(() {
        _isPermissionGranted = false;
      });
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessing || !_isScanning) return;

    final now = DateTime.now();
    if (_lastProcessedTime != null && now.difference(_lastProcessedTime!).inMilliseconds < 500) {
      return; // Process every 500ms
    }

    _lastProcessedTime = now;
    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      // 1. Process QR/Barcodes
      final barcodes = await _barcodeScanner.processImage(inputImage);
      if (barcodes.isNotEmpty) {
        final qrRawValue = barcodes.first.rawValue;
        if (qrRawValue != null) {
          final qrResult = LinkParser.processQRCode(qrRawValue);
          if (qrResult != null) {
            _handleDetection(qrResult);
            _isProcessing = false;
            return;
          }
        }
      }

      // 2. Process Text OCR
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      final rawText = recognizedText.text;

      // Extract phone, sosmed, or links
      final phone = LinkParser.extractPhoneNumber(rawText);
      if (phone != null) {
        _handleDetection({'type': 'phone', 'phone': phone});
        _isProcessing = false;
        return;
      }

      final sosmed = LinkParser.extractSocialMediaLink(rawText);
      if (sosmed != null) {
        _handleDetection({'type': 'sosmed', 'url': sosmed});
        _isProcessing = false;
        return;
      }

      final link = LinkParser.extractAnyLink(rawText);
      if (link != null) {
        _handleDetection({'type': 'link', 'url': link});
        _isProcessing = false;
        return;
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
    }

    _isProcessing = false;
  }

  void _handleDetection(Map<String, dynamic> data) {
    if (!mounted) return;

    final intent = LinkParser.determineIntent(data);
    if (intent != null) {
      setState(() {
        _detectedData = data;
        _intentUri = intent;
      });
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationValue = sensorOrientation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationValue = (360 - rotationValue) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationValue);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _launchIntent() async {
    if (_intentUri == null) return;
    final url = Uri.parse(_intentUri!);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for custom schemes like instagram:// or whatsapp://
        if (_detectedData != null) {
          String? fallbackUrl;
          if (_detectedData!['type'] == 'phone') {
            fallbackUrl = LinkParser.buildWhatsAppUrl(_detectedData!['phone']);
          } else if (_detectedData!['type'] == 'sosmed') {
            fallbackUrl = _detectedData!['url'];
          }
          if (fallbackUrl != null) {
            final fallbackUri = Uri.parse(fallbackUrl);
            await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
            return;
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tidak dapat membuka link: $_intentUri')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saat membuka link: $e')),
        );
      }
    }
  }

  void _clearDetection() {
    setState(() {
      _detectedData = null;
      _intentUri = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
        ),
      );
    }

    if (!_isPermissionGranted) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Akses kamera diperlukan untuk memindai link atau kontak.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          CameraPreview(_cameraController!),

          // Glassmorphic Scanner UI Overlay
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'SCANNING',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isProcessing)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                // Scanner Frame/Target UI
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF6366F1), width: 2),
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.transparent,
                  ),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity: 0.2,
                          child: Icon(
                            Icons.qr_code_scanner,
                            size: 150,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Persistent Action Overlay
                if (_detectedData != null) _buildActionOverlay(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionOverlay() {
    IconData icon;
    String title;
    String subtitle;
    Color buttonColor;

    final type = _detectedData!['type'];
    if (type == 'phone') {
      icon = Icons.chat_bubble_outline;
      title = 'Chat WhatsApp';
      subtitle = _detectedData!['phone'];
      buttonColor = const Color(0xFF25D366);
    } else if (type == 'sosmed') {
      final url = _detectedData!['url'] as String;
      if (url.contains('instagram')) {
        icon = Icons.camera_alt_outlined;
        title = 'Buka Instagram';
      } else if (url.contains('tiktok')) {
        icon = Icons.music_note;
        title = 'Buka TikTok';
      } else {
        icon = Icons.people_outline;
        title = 'Buka Sosmed';
      }
      subtitle = url;
      buttonColor = const Color(0xFFE1306C);
    } else {
      icon = Icons.link;
      title = 'Buka Link';
      subtitle = _detectedData!['url'];
      buttonColor = const Color(0xFF6366F1);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: buttonColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: buttonColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white38, size: 20),
            onPressed: _clearDetection,
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              elevation: 0,
            ),
            onPressed: _launchIntent,
            child: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }
}
