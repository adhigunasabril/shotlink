import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../data/repositories/scan_repository.dart';
import '../../../../data/services/image_picker_service.dart';
import '../../../../data/services/url_launcher_service.dart';
import '../../../../domain/models/scan_result.dart';
import '../../../../parser.dart';

import '../../../../data/services/preferences_service.dart';

class UploadImageViewModel extends ChangeNotifier {
  final ImagePickerService _imagePickerService;
  final ScanRepository _scanRepository;
  final UrlLauncherService _urlLauncherService;
  final PreferencesService _preferencesService;

  UploadImageViewModel({
    required ImagePickerService imagePickerService,
    required ScanRepository scanRepository,
    required UrlLauncherService urlLauncherService,
    required PreferencesService preferencesService,
  })  : _imagePickerService = imagePickerService,
        _scanRepository = scanRepository,
        _urlLauncherService = urlLauncherService,
        _preferencesService = preferencesService;

  String? _imagePath;
  String? get imagePath => _imagePath;

  List<ScanResult> _scanResults = [];
  List<ScanResult> get scanResults => _scanResults;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void clearData() {
    _imagePath = null;
    _scanResults = [];
    _isLoading = false;
    notifyListeners();
  }

  Future<void> pickAndProcessImage() async {
    try {
      final path = await _imagePickerService.pickImageFromGallery();
      if (path == null) return;

      _imagePath = path;
      _isLoading = true;
      _scanResults = [];
      notifyListeners();

      final inputImage = InputImage.fromFilePath(path);
      final countryDialCode = _preferencesService.getCountryDialCode() ?? '62';
      final results = await _scanRepository.scanImage(inputImage, countryDialCode: countryDialCode);

      _scanResults = results;
    } catch (e) {
      debugPrint('Error picking or processing image: $e');
    } finally {
      _isLoading = false;
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
        String? fallbackUrl;
        if (data['type'] == 'phone') {
          final countryDialCode = _preferencesService.getCountryDialCode() ?? '62';
          fallbackUrl = LinkParser.buildWhatsAppUrl(data['phone'], countryDialCode);
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
}
