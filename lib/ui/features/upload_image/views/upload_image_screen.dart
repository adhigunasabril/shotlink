import 'dart:io';
import 'package:flutter/material.dart';
import '../view_models/upload_image_view_model.dart';
import '../../../core/widgets/scan_action_overlay.dart';

class UploadImageScreen extends StatefulWidget {
  final UploadImageViewModel viewModel;

  const UploadImageScreen({
    Key? key,
    required this.viewModel,
  }) : super(key: key);

  @override
  State<UploadImageScreen> createState() => _UploadImageScreenState();
}

class _UploadImageScreenState extends State<UploadImageScreen> {
  @override
  void initState() {
    super.initState();
    // Start picking image on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.viewModel.pickAndProcessImage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final imagePath = widget.viewModel.imagePath;
        final isLoading = widget.viewModel.isLoading;
        final results = widget.viewModel.scanResults;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Scan Uploaded Image'),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Image Preview or Empty State
              if (imagePath != null)
                Center(
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                )
              else if (!isLoading)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 80,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No image selected',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => widget.viewModel.pickAndProcessImage(),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Select Image'),
                      ),
                    ],
                  ),
                ),

              // Loading Overlay
              if (isLoading)
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
                  ),
                ),

              // Results Overlay
              if (results.isNotEmpty && !isLoading)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: ScanActionOverlay(
                      scanResults: results,
                      onActionPressed: (intentUri, data) => widget.viewModel.launchIntent(
                        intentUri: intentUri,
                        data: data,
                        context: context,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
