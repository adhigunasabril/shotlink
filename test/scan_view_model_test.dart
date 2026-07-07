import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_photo_link/ui/features/scan/view_models/scan_view_model.dart';
import 'package:open_photo_link/data/repositories/scan_repository.dart';
import 'package:open_photo_link/data/services/url_launcher_service.dart';
import 'package:open_photo_link/domain/models/scan_result.dart';

class MockScanRepository extends Fake implements ScanRepository {
  final List<ScanResult> stubbedResults;
  MockScanRepository(this.stubbedResults);

  @override
  Future<List<ScanResult>> scanImage(InputImage inputImage) async => stubbedResults;
}

class MockUrlLauncherService extends Fake implements UrlLauncherService {
  Uri? launchedUrl;
  bool canLaunchReturnValue = true;

  @override
  Future<bool> canLaunch(Uri url) async {
    return canLaunchReturnValue;
  }

  @override
  Future<bool> launch(Uri url, {LaunchMode mode = LaunchMode.externalApplication}) async {
    launchedUrl = url;
    return true;
  }
}

void main() {
  group('ScanViewModel Unit Tests', () {
    test('toggleScanning should update state', () {
      final repository = MockScanRepository([]);
      final urlLauncher = MockUrlLauncherService();
      final viewModel = ScanViewModel(
        scanRepository: repository,
        urlLauncherService: urlLauncher,
      );

      expect(viewModel.isScanning, isTrue);

      viewModel.toggleScanning(false);
      expect(viewModel.isScanning, isFalse);
    });

    test('clearDetections should clear results and sizes', () {
      final repository = MockScanRepository([]);
      final urlLauncher = MockUrlLauncherService();
      final viewModel = ScanViewModel(
        scanRepository: repository,
        urlLauncherService: urlLauncher,
      );

      viewModel.clearDetections();
      expect(viewModel.scanResults, isEmpty);
      expect(viewModel.imageSize, isNull);
    });
  });
}
