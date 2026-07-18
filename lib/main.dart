import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'data/repositories/scan_repository.dart';
import 'data/services/barcode_service.dart';
import 'data/services/ocr_service.dart';
import 'data/services/url_launcher_service.dart';
import 'ui/core/theme.dart';
import 'ui/features/dashboard/views/dashboard_screen.dart';
import 'ui/features/scan/view_models/scan_view_model.dart';
import 'data/services/image_picker_service.dart';
import 'ui/features/upload_image/view_models/upload_image_view_model.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'data/services/preferences_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await availableCameras();
  } catch (e) {
    debugPrint('Error initializing cameras at startup: $e');
  }

  final sharedPreferences = await SharedPreferences.getInstance();
  final preferencesService = PreferencesService(sharedPreferences);

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
    preferencesService: preferencesService,
  );

  final imagePickerService = ImagePickerService();
  final uploadViewModel = UploadImageViewModel(
    imagePickerService: imagePickerService,
    scanRepository: scanRepository,
    urlLauncherService: urlLauncherService,
    preferencesService: preferencesService,
  );

  runApp(MyApp(
    scanViewModel: scanViewModel,
    uploadViewModel: uploadViewModel,
    preferencesService: preferencesService,
  ));
}

class MyApp extends StatelessWidget {
  final ScanViewModel scanViewModel;
  final UploadImageViewModel uploadViewModel;
  final PreferencesService preferencesService;

  const MyApp({
    Key? key,
    required this.scanViewModel,
    required this.uploadViewModel,
    required this.preferencesService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shotlink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: DashboardScreen(
        scanViewModel: scanViewModel,
        uploadViewModel: uploadViewModel,
        preferencesService: preferencesService,
      ),
    );
  }
}
