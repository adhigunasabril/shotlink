import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:open_photo_link/data/repositories/scan_repository.dart';
import 'package:open_photo_link/data/services/barcode_service.dart';
import 'package:open_photo_link/data/services/ocr_service.dart';

class FakeInputImage extends Fake implements InputImage {}

class MockOcrService extends Fake implements OcrService {
  final RecognizedText stubbedText;
  MockOcrService(this.stubbedText);

  @override
  Future<RecognizedText> processImage(InputImage inputImage) async => stubbedText;
}

class MockBarcodeService extends Fake implements BarcodeService {
  final List<Barcode> stubbedBarcodes;
  MockBarcodeService(this.stubbedBarcodes);

  @override
  Future<List<Barcode>> processImage(InputImage inputImage) async => stubbedBarcodes;
}

class FakeTextElement extends Fake implements TextElement {
  @override
  final String text;
  @override
  final Rect boundingBox;

  FakeTextElement({required this.text, required this.boundingBox});
}

class FakeTextLine extends Fake implements TextLine {
  @override
  final String text;
  @override
  final List<TextElement> elements;
  @override
  final Rect boundingBox;

  FakeTextLine({
    required this.text,
    required this.elements,
    required this.boundingBox,
  });
}

class FakeTextBlock extends Fake implements TextBlock {
  @override
  final String text;
  @override
  final List<TextLine> lines;
  @override
  final Rect boundingBox;

  FakeTextBlock({
    required this.text,
    required this.lines,
    required this.boundingBox,
  });
}

class FakeRecognizedText extends Fake implements RecognizedText {
  @override
  final String text;
  @override
  final List<TextBlock> blocks;

  FakeRecognizedText({required this.text, required this.blocks});
}

void main() {
  group('ScanRepository Unit Tests', () {
    test('should extract phone number correctly from OCR lines', () async {
      // Given
      final textElement = FakeTextElement(
        text: '081234567890',
        boundingBox: const Rect.fromLTRB(10, 10, 100, 30),
      );

      final textLine = FakeTextLine(
        text: 'Hubungi 0812-3456-7890',
        elements: [textElement],
        boundingBox: const Rect.fromLTRB(0, 10, 200, 30),
      );

      final textBlock = FakeTextBlock(
        text: 'Hubungi 0812-3456-7890',
        lines: [textLine],
        boundingBox: const Rect.fromLTRB(0, 10, 200, 30),
      );

      final recognizedText = FakeRecognizedText(
        text: 'Hubungi 0812-3456-7890',
        blocks: [textBlock],
      );

      final ocrService = MockOcrService(recognizedText);
      final barcodeService = MockBarcodeService([]);
      final repository = ScanRepository(
        ocrService: ocrService,
        barcodeService: barcodeService,
      );

      // When
      final results = await repository.scanImage(FakeInputImage());

      // Then
      expect(results, hasLength(1));
      expect(results.first.data['type'], equals('phone'));
      expect(results.first.data['phone'], equals('081234567890'));
      expect(results.first.intentUri, contains('whatsapp://send?phone=6281234567890'));
    });
  });
}
