import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:reading_moments_app/core/log/app_logger.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.korean,
  );

  Future<String> recognizeText(String imagePath) async {
    AppLogger.apiStart(
      'ocrRecognizeText',
      detail: 'imagePath=$imagePath',
    );
    print('📷 ocrRecognizeText START | imagePath=$imagePath');

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final paragraphs = <String>[];

      for (final block in recognizedText.blocks) {
        final lines = block.lines
            .map((line) => _cleanText(line.text))
            .where((text) => text.isNotEmpty)
            .toList();

        if (lines.isEmpty) continue;

        final paragraph = lines.join(' ').trim();
        if (paragraph.isEmpty) continue;

        paragraphs.add(paragraph);
      }

      final result = paragraphs.join('\n\n').trim();

      AppLogger.apiSuccess(
        'ocrRecognizeText',
        detail:
            'blockCount=${recognizedText.blocks.length}, paragraphCount=${paragraphs.length}, textLength=${result.length}',
      );
      print(
        '✅ ocrRecognizeText SUCCESS | blockCount=${recognizedText.blocks.length} | paragraphCount=${paragraphs.length} | textLength=${result.length}',
      );

      return result;
    } catch (e, st) {
      AppLogger.apiError('ocrRecognizeText', e, stackTrace: st);
      print('❌ ocrRecognizeText FAIL | $e');
      rethrow;
    }
  }

  List<String> splitIntoParagraphs(String rawText) {
    final normalized = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (normalized.isEmpty) {
      return <String>[];
    }

    final paragraphs = normalized
        .split(RegExp(r'\n\s*\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((e) => e.isNotEmpty)
        .toList();

    AppLogger.info(
      'ocrSplitIntoParagraphs | count=${paragraphs.length}, textLength=${normalized.length}',
    );
    print(
      '🧱 ocrSplitIntoParagraphs | count=${paragraphs.length} | textLength=${normalized.length}',
    );

    return paragraphs;
  }

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(' ,', ',')
        .replaceAll(' .', '.')
        .replaceAll(' !', '!')
        .replaceAll(' ?', '?')
        .trim();
  }

  void dispose() {
    _textRecognizer.close();
  }
}