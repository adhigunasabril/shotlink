import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../data/repositories/scan_repository.dart';
import '../../../../data/services/url_launcher_service.dart';
import '../../../../domain/models/scan_result.dart';
import '../../../../parser.dart';

class ScanViewModel extends ChangeNotifier {
  final ScanRepository _scanRepository;
  final UrlLauncherService _urlLauncherService;

  ScanViewModel({
    required ScanRepository scanRepository,
    required UrlLauncherService urlLauncherService,
  })  : _scanRepository = scanRepository,
        _urlLauncherService = urlLauncherService;

  List<ScanResult> _scanResults = [];
  List<ScanResult> get scanResults => _scanResults;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  bool _isScanning = true;
  bool get isScanning => _isScanning;

  Size? _imageSize;
  Size? get imageSize => _imageSize;

  InputImageRotation? _imageRotation;
  InputImageRotation? get imageRotation => _imageRotation;

  DateTime? _lastProcessedTime;

  void toggleScanning(bool value) {
    _isScanning = value;
    notifyListeners();
  }

  void clearDetections() {
    _scanResults = [];
    _imageSize = null;
    _imageRotation = null;
    notifyListeners();
  }

  Future<void> processCameraImage(CameraImage image, CameraDescription camera) async {
    if (_isProcessing || !_isScanning) return;

    final now = DateTime.now();
    if (_lastProcessedTime != null && now.difference(_lastProcessedTime!).inSeconds < 3) {
      return;
    }
    _lastProcessedTime = now;
    _isProcessing = true;
    notifyListeners();

    try {
      final inputImage = _inputImageFromCameraImage(image, camera);
      if (inputImage == null) {
        _isProcessing = false;
        notifyListeners();
        return;
      }

      final results = await _scanRepository.scanImage(inputImage);

      _scanResults = results;
      _imageSize = inputImage.metadata?.size;
      _imageRotation = inputImage.metadata?.rotation;
    } catch (e) {
      debugPrint('Error processing image in ViewModel: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> launchIntent({
    required String? intentUri,
    required Map<String, dynamic> data,
    required BuildContext context,
  }) async {
    if (intentUri == null) return;
    final url = Uri.parse(intentUri);
    try {
      if (await _urlLauncherService.canLaunch(url)) {
        await _urlLauncherService.launch(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for custom schemes like instagram:// or whatsapp://
        String? fallbackUrl;
        if (data['type'] == 'phone') {
          fallbackUrl = LinkParser.buildWhatsAppUrl(data['phone']);
        } else if (data['type'] == 'sosmed') {
          fallbackUrl = data['url'];
        }
        if (fallbackUrl != null) {
          final fallbackUri = Uri.parse(fallbackUrl);
          await _urlLauncherService.launch(fallbackUri, mode: LaunchMode.externalApplication);
          return;
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to open link: $intentUri')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationValue = sensorOrientation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationValue = (360 - rotationValue) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationValue);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }
}
