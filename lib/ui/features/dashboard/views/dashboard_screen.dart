import 'package:flutter/material.dart';
import '../../scan/view_models/scan_view_model.dart';
import '../../scan/views/camera_scan_screen.dart';

class DashboardScreen extends StatelessWidget {
  final ScanViewModel scanViewModel;

  const DashboardScreen({
    Key? key,
    required this.scanViewModel,
  }) : super(key: key);

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
                    // Reset scanner state before launching camera screen
                    scanViewModel.clearDetections();
                    scanViewModel.toggleScanning(true);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CameraScanScreen(viewModel: scanViewModel),
                      ),
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
}
