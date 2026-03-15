import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.korean,
  );

  Future<String> recognizeText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _textRecognizer.processImage(
      inputImage,
    );

    debugPrint('===== OCR DEBUG START =====');
    debugPrint('block count: ${recognizedText.blocks.length}');
    debugPrint('raw text: ${recognizedText.text}');

    final extractedLines = <String>[];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final cleaned = _cleanText(line.text);
        if (_isUsefulLine(cleaned)) {
          extractedLines.add(cleaned);
        }
      }
    }

    debugPrint('useful lines: $extractedLines');
    debugPrint('===== OCR DEBUG END =====');

    if (extractedLines.isNotEmpty) {
      return extractedLines.join('\n');
    }

    return _normalizeRawText(recognizedText.text);
  }

  List<String> splitIntoSentences(String rawText) {
    final normalized = _normalizeRawText(rawText);
    if (normalized.isEmpty) return [];

    final rawLines = normalized
        .split('\n')
        .map(_cleanText)
        .where((e) => e.isNotEmpty)
        .where(_isUsefulLine)
        .toList();

    if (rawLines.isEmpty) return [];

    // 1) 줄 단위로 잘린 본문을 자연스럽게 이어붙임
    final mergedParagraphText = _mergeLinesToParagraph(rawLines);

    // 2) 문장 단위 분리
    final splitSentences = _splitParagraphIntoSentences(mergedParagraphText);

    // 3) 후처리
    final finalSentences = <String>[];
    final seen = <String>{};

    for (final sentence in splitSentences) {
      final cleaned = _postProcessSentence(sentence);

      if (cleaned.isEmpty) continue;
      if (!_isUsefulSentence(cleaned)) continue;
      if (seen.contains(cleaned)) continue;

      seen.add(cleaned);
      finalSentences.add(cleaned);
    }

    if (finalSentences.isNotEmpty) {
      return finalSentences;
    }

    // fallback
    return rawLines;
  }

  String _mergeLinesToParagraph(List<String> lines) {
    final buffer = StringBuffer();

    for (int i = 0; i < lines.length; i++) {
      final current = lines[i];

      if (buffer.isEmpty) {
        buffer.write(current);
        continue;
      }

      final previousText = buffer.toString();

      // 문장이 이미 끝났으면 띄우고 새 문장처럼 이어감
      if (_looksSentenceEnded(previousText)) {
        buffer.write(' ');
        buffer.write(current);
        continue;
      }

      // 현재 줄이 이전 줄의 자연스러운 이어짐인지 판단
      if (_shouldAppendWithoutHardBreak(previousText, current)) {
        buffer.write(' ');
        buffer.write(current);
      } else {
        buffer.write(' ');
        buffer.write(current);
      }
    }

    return _cleanText(buffer.toString());
  }

  List<String> _splitParagraphIntoSentences(String text) {
    if (text.isEmpty) return [];

    final normalized = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(' .', '.')
        .replaceAll(' !', '!')
        .replaceAll(' ?', '?')
        .trim();

    if (normalized.isEmpty) return [];

    final sentences = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < normalized.length; i++) {
      final char = normalized[i];
      buffer.write(char);

      final current = buffer.toString().trim();

      if (_isSentenceBoundary(normalized, i, current)) {
        final sentence = _cleanText(current);
        if (sentence.isNotEmpty) {
          sentences.add(sentence);
        }
        buffer.clear();
      }
    }

    if (buffer.isNotEmpty) {
      final tail = _cleanText(buffer.toString());
      if (tail.isNotEmpty) {
        sentences.add(tail);
      }
    }

    return sentences;
  }

  bool _isSentenceBoundary(String fullText, int index, String current) {
    final char = fullText[index];

    // ., !, ? 로 끝나는 경우
    if (char == '.' || char == '!' || char == '?') {
      return true;
    }

    // 한국어 종결형에서 문장 종결 처리
    if (_endsWithKoreanEnding(current)) {
      final nextChar = index + 1 < fullText.length ? fullText[index + 1] : '';
      if (nextChar.isEmpty || nextChar == ' ') {
        return true;
      }
    }

    return false;
  }

  bool _endsWithKoreanEnding(String text) {
    return text.endsWith('다') ||
        text.endsWith('요') ||
        text.endsWith('죠') ||
        text.endsWith('까') ||
        text.endsWith('네') ||
        text.endsWith('니다') ||
        text.endsWith('했다') ||
        text.endsWith('였다') ||
        text.endsWith('했다.') ||
        text.endsWith('였다.') ||
        text.endsWith('습니다') ||
        text.endsWith('습니다.');
  }

  bool _looksSentenceEnded(String text) {
    return text.endsWith('.') ||
        text.endsWith('!') ||
        text.endsWith('?') ||
        _endsWithKoreanEnding(text);
  }

  bool _shouldAppendWithoutHardBreak(String previous, String current) {
    if (previous.isEmpty || current.isEmpty) return true;

    // 이전 줄이 너무 짧으면 이어붙이는 편이 자연스러움
    if (previous.length < 20) return true;

    // 현재 줄이 조사/어미와 이어질 만한 일반 본문이면 이어붙임
    if (RegExp(r'^[가-힣]').hasMatch(current)) return true;

    return true;
  }

  bool _isUsefulLine(String text) {
    if (text.isEmpty) return false;
    if (text == '-') return false;
    if (text == '—') return false;
    if (text == '•') return false;
    if (text.length < 2) return false;

    final hangulCount = RegExp(r'[가-힣]').allMatches(text).length;
    final alphaCount = RegExp(r'[A-Za-z]').allMatches(text).length;
    final digitCount = RegExp(r'[0-9]').allMatches(text).length;

    // 한글 포함 라인은 우선 살림
    if (hangulCount >= 1) return true;

    // 영문+숫자 조합 위주 쓰레기값 제거
    if (hangulCount == 0 && alphaCount >= 3 && digitCount >= 1) {
      return false;
    }

    // 한글도 없고 너무 짧으면 제거
    if (hangulCount == 0 && text.length < 5) {
      return false;
    }

    return true;
  }

  bool _isUsefulSentence(String text) {
    if (text.isEmpty) return false;
    if (text.length < 4) return false;

    final hangulCount = RegExp(r'[가-힣]').allMatches(text).length;
    final alphaCount = RegExp(r'[A-Za-z]').allMatches(text).length;
    final digitCount = RegExp(r'[0-9]').allMatches(text).length;

    if (hangulCount == 0 && alphaCount >= 3 && digitCount >= 1) {
      return false;
    }

    if (hangulCount == 0 && text.length < 8) {
      return false;
    }

    return true;
  }

  String _postProcessSentence(String text) {
    var result = _cleanText(text);

    // OCR에서 자주 생기는 이상 공백/기호 정리
    result = result
        .replaceAll(' ,', ',')
        .replaceAll(' .', '.')
        .replaceAll(' !', '!')
        .replaceAll(' ?', '?')
        .replaceAll(' :', ':')
        .replaceAll(' ;', ';')
        .trim();

    // 앞뒤 불필요 기호 제거
    result = result.replaceAll(RegExp(r'^[\-\•\·\s]+'), '');
    result = result.replaceAll(RegExp(r'[\-\•\·\s]+$'), '');

    return result.trim();
  }

  String _normalizeRawText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .split('\n')
        .map(_cleanText)
        .join('\n')
        .trim();
  }

  String _cleanText(String text) {
    return text
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void dispose() {
    _textRecognizer.close();
  }
}
