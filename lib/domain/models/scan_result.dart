import 'dart:ui';

class ScanResult {
  final Map<String, dynamic> data;
  final Rect boundingBox;
  final String? intentUri;

  ScanResult({
    required this.data,
    required this.boundingBox,
    required this.intentUri,
  });
}
