import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../view_models/scan_view_model.dart';

class CameraScanScreen extends StatefulWidget {
  final ScanViewModel viewModel;

  const CameraScanScreen({
    Key? key,
    required this.viewModel,
  }) : super(key: key);

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isPermissionGranted = false;

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
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      await _cameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) return;

      setState(() {
        _isPermissionGranted = true;
      });

      _cameraController!.startImageStream((image) {
        widget.viewModel.processCameraImage(image, camera);
      });
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
      setState(() {
        _isPermissionGranted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
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
              // Camera Preview
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

              // UI Overlay
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
                          if (widget.viewModel.isProcessing)
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

                    if (widget.viewModel.scanResults.isNotEmpty) _buildActionOverlay(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionOverlay() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: widget.viewModel.scanResults.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final result = widget.viewModel.scanResults[index];
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
                  onPressed: () => widget.viewModel.launchIntent(
                    intentUri: result.intentUri,
                    data: data,
                    context: context,
                  ),
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
