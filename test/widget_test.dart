import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:open_photo_link/main.dart';
import 'package:open_photo_link/ui/features/scan/view_models/scan_view_model.dart';
import 'package:open_photo_link/data/repositories/scan_repository.dart';
import 'package:open_photo_link/data/services/ocr_service.dart';
import 'package:open_photo_link/data/services/barcode_service.dart';
import 'package:open_photo_link/data/services/url_launcher_service.dart';
import 'package:open_photo_link/domain/models/scan_result.dart';
import 'package:open_photo_link/data/services/image_picker_service.dart';
import 'package:open_photo_link/ui/features/upload_image/view_models/upload_image_view_model.dart';

class FakeOcrService extends Fake implements OcrService {}
class FakeBarcodeService extends Fake implements BarcodeService {}
class FakeUrlLauncherService extends Fake implements UrlLauncherService {}

class FakeScanRepository extends Fake implements ScanRepository {
  @override
  Future<List<ScanResult>> scanImage(InputImage inputImage) async => [];
}

class FakeScanViewModel extends ScanViewModel {
  FakeScanViewModel()
      : super(
          scanRepository: FakeScanRepository(),
          urlLauncherService: FakeUrlLauncherService(),
        );

  @override
  bool get isProcessing => false;

  @override
  bool get isScanning => true;

  @override
  List<ScanResult> get scanResults => [];
}

class FakeImagePickerService extends Fake implements ImagePickerService {}

class FakeUploadImageViewModel extends UploadImageViewModel {
  FakeUploadImageViewModel()
      : super(
          imagePickerService: FakeImagePickerService(),
          scanRepository: FakeScanRepository(),
          urlLauncherService: FakeUrlLauncherService(),
        );

  @override
  bool get isLoading => false;

  @override
  List<ScanResult> get scanResults => [];

  @override
  String? get imagePath => null;
}

void main() {
  testWidgets('Dashboard smoke test', (WidgetTester tester) async {
    final viewModel = FakeScanViewModel();
    final uploadViewModel = FakeUploadImageViewModel();

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(
      scanViewModel: viewModel,
      uploadViewModel: uploadViewModel,
    ));

    // Verify that our app bar contains the 'shotlink' logo text.
    expect(find.text('shotlink'), findsOneWidget);

    // Verify that we have a camera icon/button on the dashboard.
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    expect(find.text('Tap to Start Photo & Scan'), findsOneWidget);
  });
}
