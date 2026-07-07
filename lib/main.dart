import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'data/repositories/scan_repository.dart';
import 'data/services/barcode_service.dart';
import 'data/services/ocr_service.dart';
import 'data/services/url_launcher_service.dart';
import 'ui/core/theme.dart';
import 'ui/features/dashboard/views/dashboard_screen.dart';
import 'ui/features/scan/view_models/scan_view_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await availableCameras();
  } catch (e) {
    debugPrint('Error initializing cameras at startup: $e');
  }

  // Inject Dependencies manually (or via DI container if needed, but constructor-injection is sufficient here)
  final ocrService = OcrService();
  final barcodeService = BarcodeService();
  final urlLauncherService = UrlLauncherService();

  final scanRepository = ScanRepository(
    ocrService: ocrService,
    barcodeService: barcodeService,
  );

  final scanViewModel = ScanViewModel(
    scanRepository: scanRepository,
    urlLauncherService: urlLauncherService,
  );

  runApp(MyApp(scanViewModel: scanViewModel));
}

class MyApp extends StatelessWidget {
  final ScanViewModel scanViewModel;

  const MyApp({
    Key? key,
    required this.scanViewModel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shotlink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: DashboardScreen(scanViewModel: scanViewModel),
    );
  }
}
