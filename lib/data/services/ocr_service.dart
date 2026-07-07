import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<RecognizedText> processImage(InputImage inputImage) async {
    return await _textRecognizer.processImage(inputImage);
  }

  Future<void> close() async {
    await _textRecognizer.close();
  }
}
