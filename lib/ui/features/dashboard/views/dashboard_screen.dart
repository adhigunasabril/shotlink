import 'package:flutter/material.dart';
import '../../scan/view_models/scan_view_model.dart';
import '../../scan/views/camera_scan_screen.dart';
import '../../upload_image/view_models/upload_image_view_model.dart';
import '../../upload_image/views/upload_image_screen.dart';
import '../../settings/views/settings_screen.dart';
import '../../../../data/services/preferences_service.dart';

class DashboardScreen extends StatelessWidget {
  final ScanViewModel scanViewModel;
  final UploadImageViewModel uploadViewModel;
  final PreferencesService preferencesService;

  const DashboardScreen({
    Key? key,
    required this.scanViewModel,
    required this.uploadViewModel,
    required this.preferencesService,
  }) : super(key: key);

  void _navigateToScan(BuildContext context) {
    scanViewModel.clearDetections();
    scanViewModel.toggleScanning(true);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScanScreen(viewModel: scanViewModel),
      ),
    );
  }

  void _navigateToUpload(BuildContext context) {
    uploadViewModel.clearData();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UploadImageScreen(viewModel: uploadViewModel),
      ),
    );
  }

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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(preferencesService: preferencesService),
                ),
              );
            },
          ),
        ],
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
                  onTap: () async {
                    if (preferencesService.isCountryConfigured()) {
                      _navigateToScan(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Silakan pilih negara Anda terlebih dahulu di halaman Settings.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      final configured = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsScreen(
                            preferencesService: preferencesService,
                            isRedirected: true,
                          ),
                        ),
                      );
                      if (configured == true && context.mounted) {
                        _navigateToScan(context);
                      }
                    }
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
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.08),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white10),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async {
                          if (preferencesService.isCountryConfigured()) {
                            _navigateToUpload(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Silakan pilih negara Anda terlebih dahulu di halaman Settings.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            final configured = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SettingsScreen(
                                  preferencesService: preferencesService,
                                  isRedirected: true,
                                ),
                              ),
                            );
                            if (configured == true && context.mounted) {
                              _navigateToUpload(context);
                            }
                          }
                        },
                        icon: const Icon(Icons.photo_library_outlined, color: Color(0xFF2563EB)),
                        label: const Text(
                          'Upload from Gallery',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
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
}
