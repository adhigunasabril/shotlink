import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      title: 'Shotlink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF2563EB),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class ScanResult {
  final Map<String, dynamic> data;
  final Rect boundingBox;
  final String? intentUri;

  ScanResult({
    required this.data,
    required this.boundingBox,
    required this.intentUri,
  });
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
  List<ScanResult> _scanResults = [];
  Size? _imageSize;
  InputImageRotation? _imageRotation;

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
      _cameraController = null;
      cameraController.dispose();
      setState(() {});
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
        ResolutionPreset.high, // High resolution (1080p) is fast to process and very sharp
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      await _cameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);
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
    if (_lastProcessedTime != null && now.difference(_lastProcessedTime!).inSeconds < 3) {
      return;
    }
    _lastProcessedTime = now;
    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      List<ScanResult> newResults = [];

      // 1. Process QR/Barcodes
      final barcodes = await _barcodeScanner.processImage(inputImage);
      for (final barcode in barcodes) {
        final qrRawValue = barcode.rawValue;
        if (qrRawValue != null) {
          final qrResult = LinkParser.processQRCode(qrRawValue);
          if (qrResult != null) {
            final intent = LinkParser.determineIntent(qrResult);
            if (intent != null) {
              newResults.add(ScanResult(
                data: qrResult,
                boundingBox: barcode.boundingBox,
                intentUri: intent,
              ));
            }
          }
        }
      }

      // 2. Process Text OCR
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final lineText = line.text;
          
          final phone = LinkParser.extractPhoneNumber(lineText);
          if (phone != null) {
            Rect? phoneBox;
            for (final element in line.elements) {
              if (element.text.contains(RegExp(r'\d'))) {
                phoneBox = phoneBox == null ? element.boundingBox : phoneBox.expandToInclude(element.boundingBox);
              }
            }
            final data = {'type': 'phone', 'phone': phone};
            final intent = LinkParser.determineIntent(data);
            if (intent != null) {
              newResults.add(ScanResult(
                data: data,
                boundingBox: phoneBox ?? line.boundingBox,
                intentUri: intent,
              ));
            }
            continue;
          }

          final sosmed = LinkParser.extractSocialMediaLink(lineText);
          if (sosmed != null) {
            final data = {'type': 'sosmed', 'url': sosmed};
            final intent = LinkParser.determineIntent(data);
            if (intent != null) {
              newResults.add(ScanResult(
                data: data,
                boundingBox: line.boundingBox,
                intentUri: intent,
              ));
            }
            continue;
          }

          final link = LinkParser.extractAnyLink(lineText);
          if (link != null) {
            final data = {'type': 'link', 'url': link};
            final intent = LinkParser.determineIntent(data);
            if (intent != null) {
              newResults.add(ScanResult(
                data: data,
                boundingBox: line.boundingBox,
                intentUri: intent,
              ));
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _scanResults = newResults;
          _imageSize = inputImage.metadata?.size;
          _imageRotation = inputImage.metadata?.rotation;
        });
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
    }

    _isProcessing = false;
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

  Future<void> _launchIntent(String? intentUri, Map<String, dynamic> data) async {
    if (intentUri == null) return;
    final url = Uri.parse(intentUri);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for custom schemes like instagram:// or whatsapp://
        String? fallbackUrl;
        if (data['type'] == 'phone') {
          fallbackUrl = LinkParser.buildWhatsAppUrl(data['phone']);
        } else if (data['type'] == 'sosmed') {
          fallbackUrl = data['url'];
        }
        if (fallbackUrl != null) {
          final fallbackUri = Uri.parse(fallbackUrl);
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to open link: $intentUri')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }
    }
  }

  void _clearDetection() {
    setState(() {
      _scanResults = [];
      _imageSize = null;
      _imageRotation = null;
    });
  }

  Rect? _getScreenRect(Rect? box, Size? imageSize, InputImageRotation? rotation, Size screenSize) {
    if (box == null || imageSize == null || rotation == null) return null;

    final bool isPortrait = rotation == InputImageRotation.rotation90deg || rotation == InputImageRotation.rotation270deg;
    
    // In portrait mode, camera sensor dimensions map flipped to screen coordinates
    final double srcWidth = isPortrait ? imageSize.height : imageSize.width;
    final double srcHeight = isPortrait ? imageSize.width : imageSize.height;

    final double scaleX = screenSize.width / srcWidth;
    final double scaleY = screenSize.height / srcHeight;
    final double scale = scaleX > scaleY ? scaleX : scaleY;
    
    final double offsetX = (screenSize.width - srcWidth * scale) / 2;
    final double offsetY = (screenSize.height - srcHeight * scale) / 2;

    double left = box.left;
    double right = box.right;
    double top = box.top;
    double bottom = box.bottom;

    if (rotation == InputImageRotation.rotation90deg) {
      left = box.top;
      right = box.bottom;
      top = imageSize.width - box.right;
      bottom = imageSize.width - box.left;
    } else if (rotation == InputImageRotation.rotation270deg) {
      left = imageSize.height - box.bottom;
      right = imageSize.height - box.top;
      top = box.left;
      bottom = box.right;
    }

    return Rect.fromLTRB(
      left * scale + offsetX,
      top * scale + offsetY,
      right * scale + offsetX,
      bottom * scale + offsetY,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
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
              'Camera access is required to scan links or contacts.',
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
          // Camera Preview (fitted to cover screen without stretching)
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              
              return Stack(
                fit: StackFit.expand,
                children: [
                  SizedBox(
                    width: size.width,
                    height: size.height,
                    child: ClipRect(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize?.height ?? size.width,
                          height: _cameraController!.value.previewSize?.width ?? size.height,
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Glassmorphic Scanner UI Overlay
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
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
                      const Spacer(),
                      if (_isProcessing)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                          ),
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                const Spacer(),

                if (_scanResults.isNotEmpty) _buildActionOverlay(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionOverlay() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _scanResults.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final result = _scanResults[index];
          final data = result.data;
          
          IconData icon;
          String title;
          String subtitle;
          Color buttonColor;

          final type = data['type'];
          if (type == 'phone') {
            icon = Icons.chat_bubble_outline;
            title = 'Chat WhatsApp';
            subtitle = data['phone'];
            buttonColor = const Color(0xFF25D366);
          } else if (type == 'sosmed') {
            final url = data['url'] as String;
            if (url.contains('instagram')) {
              icon = Icons.camera_alt_outlined;
              title = 'Open Instagram';
            } else if (url.contains('tiktok')) {
              icon = Icons.music_note;
              title = 'Open TikTok';
            } else {
              icon = Icons.people_outline;
              title = 'Open Social Media';
            }
            subtitle = url;
            buttonColor = const Color(0xFFE1306C);
          } else {
            icon = Icons.link;
            title = 'Open Link';
            subtitle = data['url'];
            buttonColor = const Color(0xFF2563EB);
          }

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: buttonColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: buttonColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    elevation: 0,
                  ),
                  onPressed: () => _launchIntent(result.intentUri, data),
                  child: const Icon(Icons.arrow_forward, size: 18),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.camera_alt, color: Color(0xFF2563EB), size: 28),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.link, color: Color(0xFF2563EB), size: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Text(
              'shotlink',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E293B),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(
                  bottom: BorderSide(color: Colors.white10, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.camera_alt, color: Color(0xFF2563EB), size: 32),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.link, color: Color(0xFF2563EB), size: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'shotlink',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Shoot your photo and link it!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'Other features coming soon',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Central Camera Action
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CameraScanScreen()),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF2563EB), width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 64,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Tap to Start Photo & Scan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Bottom tagline
              Text(
                'Point the camera at text/QR to open links instantly',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'More feature coming soon',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
