import 'dart:ui';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import '../../domain/models/scan_result.dart';
import '../../parser.dart';
import '../services/barcode_service.dart';
import '../services/ocr_service.dart';

class ScanRepository {
  final OcrService _ocrService;
  final BarcodeService _barcodeService;

  ScanRepository({
    required OcrService ocrService,
    required BarcodeService barcodeService,
  })  : _ocrService = ocrService,
        _barcodeService = barcodeService;

  Future<List<ScanResult>> scanImage(InputImage inputImage, {String countryDialCode = '62'}) async {
    final List<ScanResult> newResults = [];

    // 1. Process QR/Barcodes
    try {
      final barcodes = await _barcodeService.processImage(inputImage);
      for (final barcode in barcodes) {
        final qrRawValue = barcode.rawValue;
        if (qrRawValue != null) {
          final qrResult = LinkParser.processQRCode(qrRawValue, countryDialCode: countryDialCode);
          if (qrResult != null) {
            final intent = LinkParser.determineIntent(qrResult, countryDialCode: countryDialCode);
            if (intent != null) {
              newResults.add(ScanResult(
                data: qrResult,
                boundingBox: barcode.boundingBox,
                intentUri: intent,
              ));
            }
          }
        }
      }
    } catch (e) {
      print('Error scanning barcode: $e');
    }

    // 2. Process Text OCR
    try {
      final recognizedText = await _ocrService.processImage(inputImage);
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final lineText = line.text;

          final phone = LinkParser.extractPhoneNumber(lineText, countryDialCode: countryDialCode);
          if (phone != null) {
            Rect? phoneBox;
            for (final element in line.elements) {
              if (element.text.contains(RegExp(r'\d'))) {
                phoneBox = phoneBox == null
                    ? element.boundingBox
                    : phoneBox.expandToInclude(element.boundingBox);
              }
            }
            final data = {'type': 'phone', 'phone': phone};
            final intent = LinkParser.determineIntent(data, countryDialCode: countryDialCode);
            if (intent != null) {
              newResults.add(ScanResult(
                data: data,
                boundingBox: phoneBox ?? line.boundingBox,
                intentUri: intent,
              ));
            }
            continue;
          }

          final sosmed = LinkParser.extractSocialMediaLink(lineText);
          if (sosmed != null) {
            final data = {'type': 'sosmed', 'url': sosmed};
            final intent = LinkParser.determineIntent(data, countryDialCode: countryDialCode);
            if (intent != null) {
              newResults.add(ScanResult(
                data: data,
                boundingBox: line.boundingBox,
                intentUri: intent,
              ));
            }
            continue;
          }

          final link = LinkParser.extractAnyLink(lineText);
          if (link != null) {
            final data = {'type': 'link', 'url': link};
            final intent = LinkParser.determineIntent(data, countryDialCode: countryDialCode);
            if (intent != null) {
              newResults.add(ScanResult(
                data: data,
                boundingBox: line.boundingBox,
                intentUri: intent,
              ));
            }
          }
        }
      }
    } catch (e) {
      print('Error processing OCR: $e');
    }

    return newResults;
  }
}
