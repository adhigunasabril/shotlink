import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../view_models/scan_view_model.dart';
import '../../../core/widgets/scan_action_overlay.dart';

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

                    if (widget.viewModel.scanResults.isNotEmpty)
                      ScanActionOverlay(
                        scanResults: widget.viewModel.scanResults,
                        onActionPressed: (intentUri, data) => widget.viewModel.launchIntent(
                          intentUri: intentUri,
                          data: data,
                          context: context,
                        ),
                      ),
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
}
