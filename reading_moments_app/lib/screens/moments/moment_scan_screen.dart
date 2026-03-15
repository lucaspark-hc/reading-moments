import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reading_moments_app/screens/moments/moment_create_screen.dart';
import 'package:reading_moments_app/services/ocr_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class MomentScanScreen extends StatefulWidget {
  final int bookId;
  final String bookTitle;

  const MomentScanScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  State<MomentScanScreen> createState() => _MomentScanScreenState();
}

class _MomentScanScreenState extends State<MomentScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();

  bool _loading = false;
  File? _imageFile;
  List<String> _sentences = [];
  final Set<int> _selectedIndexes = <int>{};

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _pickAndRecognize(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (picked == null) return;

      setState(() {
        _loading = true;
        _imageFile = File(picked.path);
        _sentences = [];
        _selectedIndexes.clear();
      });

      final rawText = await _ocrService.recognizeText(picked.path);

      debugPrint('===== OCR RAW TEXT START =====');
      debugPrint(rawText);
      debugPrint('===== OCR RAW TEXT END =====');

      List<String> parsed = [];

      try {
        parsed = _ocrService.splitIntoSentences(rawText);
      } catch (e) {
        debugPrint('splitIntoSentences error: $e');
      }

      parsed = _normalizeTexts(parsed);

      if (parsed.isEmpty) {
        parsed = _fallbackSplitText(rawText);
      }

      if (!mounted) return;

      setState(() {
        _sentences = parsed;
      });

      debugPrint('OCR parsed sentence count: ${_sentences.length}');
      debugPrint('OCR parsed sentences: $_sentences');

      if (_sentences.isEmpty) {
        showToast(context, '인식된 문장이 없습니다. 다른 사진으로 시도해 주세요.');
      }
    } catch (e) {
      if (!mounted) return;
      showToast(context, 'OCR 처리 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<String> _fallbackSplitText(String rawText) {
    final normalized = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (normalized.isEmpty) return [];

    final lines = normalized
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map(_cleanText)
        .where((e) => e.isNotEmpty)
        .where((e) => e != '-')
        .where((e) => e != '•')
        .where((e) => e != '.')
        .toList();

    if (lines.isEmpty) return [];

    final merged = <String>[];
    final buffer = StringBuffer();

    for (final line in lines) {
      final isShortLine = line.length <= 12;
      final endsLikeSentence = _looksSentenceEnded(line);

      if (buffer.isEmpty) {
        buffer.write(line);
      } else {
        buffer.write(' ');
        buffer.write(line);
      }

      if (!isShortLine || endsLikeSentence) {
        final text = _cleanText(buffer.toString());
        if (text.isNotEmpty) {
          merged.add(text);
        }
        buffer.clear();
      }
    }

    if (buffer.isNotEmpty) {
      final text = _cleanText(buffer.toString());
      if (text.isNotEmpty) {
        merged.add(text);
      }
    }

    return _normalizeTexts(merged);
  }

  bool _looksSentenceEnded(String text) {
    return text.endsWith('.') ||
        text.endsWith('!') ||
        text.endsWith('?') ||
        text.endsWith('다') ||
        text.endsWith('요') ||
        text.endsWith('까') ||
        text.endsWith('죠') ||
        text.endsWith('네');
  }

  List<String> _normalizeTexts(List<String> items) {
    final results = <String>[];
    final seen = <String>{};

    for (final item in items) {
      final cleaned = _cleanText(item);

      if (cleaned.isEmpty) continue;
      if (cleaned == '-') continue;
      if (cleaned.length < 2) continue;
      if (seen.contains(cleaned)) continue;

      seen.add(cleaned);
      results.add(cleaned);
    }

    return results;
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

  void _toggleSentence(int index, bool selected) {
    setState(() {
      if (selected) {
        _selectedIndexes.add(index);
      } else {
        _selectedIndexes.remove(index);
      }
    });
  }

  Future<void> _goToCreateScreen() async {
    if (_selectedIndexes.isEmpty) {
      showToast(context, '저장할 문장을 선택하세요.');
      return;
    }

    final selectedTexts = _selectedIndexes.toList()..sort();
    final mergedText = selectedTexts.map((i) => _sentences[i]).join('\n');

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MomentCreateScreen(
          bookId: widget.bookId,
          initialQuoteText: mergedText,
          initialInputMethod: 'ocr',
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Widget _buildTopActions() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _loading
                ? null
                : () => _pickAndRecognize(ImageSource.camera),
            icon: const Icon(Icons.photo_camera),
            label: const Text('카메라'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _loading
                ? null
                : () => _pickAndRecognize(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('앨범 선택'),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    if (_imageFile == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '선택한 이미지',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            _imageFile!,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: double.infinity,
              height: 220,
              color: Colors.grey.shade300,
              alignment: Alignment.center,
              child: const Text('이미지를 불러올 수 없습니다.'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSentenceList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_imageFile == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('카메라 또는 앨범에서 이미지를 선택하세요.')),
      );
    }

    if (_sentences.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('인식된 문장이 없습니다. 다른 사진으로 다시 시도해 주세요.')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '인식된 문장',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '선택 ${_selectedIndexes.length}개',
              style: const TextStyle(
                color: Colors.blueGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_sentences.length, (index) {
          final sentence = _sentences[index];
          final selected = _selectedIndexes.contains(index);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: CheckboxListTile(
              value: selected,
              onChanged: (value) => _toggleSentence(index, value ?? false),
              title: Text(sentence, style: const TextStyle(height: 1.5)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = _selectedIndexes.isNotEmpty && !_loading;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.bookTitle} 스캔')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '책 페이지를 촬영하거나 앨범에서 사진을 선택한 뒤, 저장할 문장을 골라 주세요.',
              style: TextStyle(color: Colors.blueGrey, height: 1.5),
            ),
            const SizedBox(height: 16),
            _buildTopActions(),
            const SizedBox(height: 20),
            _buildImagePreview(),
            if (_imageFile != null) const SizedBox(height: 20),
            _buildSentenceList(),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: canProceed ? _goToCreateScreen : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('선택한 문장으로 기록하기'),
              ),
            ),
            const SizedBox(height: 16),
            if (kDebugMode)
              const Text(
                '디버그 모드에서는 OCR 원문과 파싱 결과가 콘솔에 출력됩니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}
