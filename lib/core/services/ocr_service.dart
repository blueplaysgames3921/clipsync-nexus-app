// ═══════════════════════════════════════════════════════════════════════════
// ocr_service.dart
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:io';
import 'dart:typed_data';

/// On-device OCR. Uses google_mlkit_text_recognition on Android,
/// and flutter_tesseract_ocr on Windows.
class OcrService {
  Future<String> extractText(Uint8List imageBytes) async {
    if (Platform.isAndroid) {
      return _extractAndroid(imageBytes);
    } else if (Platform.isWindows) {
      return _extractWindows(imageBytes);
    }
    return '';
  }

  Future<String> _extractAndroid(Uint8List bytes) async {
    // google_mlkit_text_recognition integration:
    //
    // import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
    // final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    // final tempFile = await _writeTempFile(bytes);
    // final inputImage = InputImage.fromFile(tempFile);
    // final recognized = await recognizer.processImage(inputImage);
    // await recognizer.close();
    // return recognized.text;
    //
    // Multi-script: detect script first via language hint, then use
    // TextRecognitionScript.chinese / .japanese / .korean / .devanagari etc.

    return '[OCR: android placeholder — integrate google_mlkit_text_recognition]';
  }

  Future<String> _extractWindows(Uint8List bytes) async {
    // flutter_tesseract_ocr integration:
    //
    // import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
    // final tempPath = await _writeTempFilePath(bytes);
    // final result = await FlutterTesseractOcr.extractText(
    //   tempPath,
    //   language: 'eng+chi_sim+jpn+kor+ara+hin+rus',
    //   args: {'psm': '3', 'oem': '1'},
    // );
    // return result;

    return '[OCR: windows placeholder — integrate flutter_tesseract_ocr]';
  }

  Future<File> _writeTempFile(Uint8List bytes) async {
    final tmp = Directory.systemTemp.createTempSync('csn_ocr_');
    final file = File('${tmp.path}/ocr_input.png');
    await file.writeAsBytes(bytes);
    return file;
  }
}
