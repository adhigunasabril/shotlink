import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class BarcodeService {
  final BarcodeScanner _barcodeScanner = BarcodeScanner();

  Future<List<Barcode>> processImage(InputImage inputImage) async {
    return await _barcodeScanner.processImage(inputImage);
  }

  Future<void> close() async {
    await _barcodeScanner.close();
  }
}
