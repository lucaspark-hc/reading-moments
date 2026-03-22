import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reading_moments_app/core/log/app_logger.dart';
import 'package:reading_moments_app/core/log/logged_state_mixin.dart';
import 'package:reading_moments_app/screens/moments/moment_create_screen.dart';
import 'package:reading_moments_app/services/meaning_unit_service.dart';
import 'package:reading_moments_app/services/ocr_service.dart';
import 'package:reading_moments_app/services/reading_explain_service.dart';
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

class _MomentScanScreenState extends State<MomentScanScreen>
    with LoggedStateMixin<MomentScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();
  final MeaningUnitService _meaningUnitService = MeaningUnitService();
  final ReadingExplainService _readingExplainService = ReadingExplainService();

  bool _loading = false;
  File? _imageFile;
  String _paragraphText = '';
  List<String> _meaningUnits = <String>[];
  final Set<int> _selectedIndexes = <int>{};

  @override
  String get screenName => 'MomentScanScreen';

  bool get _canExplainSingleSentence =>
      !_loading && _selectedIndexes.length == 1 && _meaningUnits.isNotEmpty;

  bool get _hasMultipleSelection => _selectedIndexes.length > 1;

  String? get _selectedSentence {
    if (_selectedIndexes.length != 1) return null;
    final index = _selectedIndexes.first;
    if (index < 0 || index >= _meaningUnits.length) return null;
    return _meaningUnits[index];
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _pickAndRecognize(ImageSource source) async {
    AppLogger.action(
      'OpenMomentScanImagePicker',
      detail: 'bookId=${widget.bookId}, source=${source.name}',
    );
    print(
      '📷 OpenMomentScanImagePicker | bookId=${widget.bookId} | source=${source.name}',
    );

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (picked == null) return;

      setState(() {
        _loading = true;
        _imageFile = File(picked.path);
        _paragraphText = '';
        _meaningUnits = <String>[];
        _selectedIndexes.clear();
      });

      final rawText = await _ocrService.recognizeText(picked.path);
      final paragraphText = _normalizeParagraphText(rawText);

      debugPrint('===== OCR PARAGRAPH START =====');
      debugPrint(paragraphText);
      debugPrint('===== OCR PARAGRAPH END =====');

      final units = await _meaningUnitService.splitMeaningUnits(paragraphText);
      final normalizedUnits = _normalizeMeaningUnits(units);

      if (!mounted) return;

      setState(() {
        _paragraphText = paragraphText;
        _meaningUnits = normalizedUnits;
      });

      AppLogger.action(
        'MeaningUnitsPrepared',
        detail:
            'bookId=${widget.bookId}, paragraphLength=${_paragraphText.length}, count=${_meaningUnits.length}',
      );
      print(
        '🧩 MeaningUnitsPrepared | bookId=${widget.bookId} | paragraphLength=${_paragraphText.length} | count=${_meaningUnits.length}',
      );

      if (_meaningUnits.isEmpty) {
        showToast(context, '인식된 문장이 없습니다. 다른 사진으로 시도해 주세요.');
      }
    } catch (e, st) {
      AppLogger.apiError('momentScanRecognize', e, stackTrace: st);
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

  String _normalizeParagraphText(String rawText) {
    return rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _normalizeMeaningUnits(List<String> items) {
    final results = <String>[];
    final seen = <String>{};

    for (final item in items) {
      final cleaned = _cleanText(item);

      if (cleaned.isEmpty) continue;
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

    AppLogger.action(
      'sentence_selected',
      detail:
          'bookId=${widget.bookId}, index=$index, selected=$selected, selectedCount=${_selectedIndexes.length}',
    );
    print(
      '☑️ sentence_selected | bookId=${widget.bookId} | index=$index | selected=$selected | selectedCount=${_selectedIndexes.length}',
    );
  }

  Future<void> _goToCreateScreen({String? overrideText}) async {
    if (_selectedIndexes.isEmpty &&
        (overrideText == null || overrideText.trim().isEmpty)) {
      showToast(context, '저장할 문장을 선택하세요.');
      return;
    }

    final selectedTexts = _selectedIndexes.toList()..sort();
    final mergedText = overrideText?.trim().isNotEmpty == true
        ? overrideText!.trim()
        : selectedTexts.map((i) => _meaningUnits[i]).join('\n');

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

  Future<void> _openExplainBottomSheet() async {
    if (_selectedIndexes.isEmpty) {
      showToast(context, '문장을 먼저 선택하세요.');
      return;
    }

    if (_selectedIndexes.length > 1) {
      showToast(context, '문장을 하나만 선택해 주세요.');
      return;
    }

    final sentence = _selectedSentence;
    if (sentence == null || sentence.trim().isEmpty) {
      showToast(context, '선택된 문장을 확인해 주세요.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ExplainResultSheet(
        initialText: sentence,
        onSaveToMoment: (text) async {
          await _goToCreateScreen(overrideText: text);
        },
        explainService: _readingExplainService,
        bookId: widget.bookId,
      ),
    );
  }

  Widget _buildTopActions() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed:
                _loading ? null : () => _pickAndRecognize(ImageSource.camera),
            icon: const Icon(Icons.photo_camera),
            label: const Text('카메라'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed:
                _loading ? null : () => _pickAndRecognize(ImageSource.gallery),
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

  Widget _buildParagraphPreview() {
    if (_paragraphText.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OCR 문단 원문',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _paragraphText,
            style: const TextStyle(height: 1.55),
          ),
        ],
      ),
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

    if (_meaningUnits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('의미 단위로 분리된 문장이 없습니다. 다른 사진으로 다시 시도해 주세요.')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '의미 단위 문장',
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
        ...List.generate(_meaningUnits.length, (index) {
          final sentence = _meaningUnits[index];
          final selected = _selectedIndexes.contains(index);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: CheckboxListTile(
              value: selected,
              onChanged: (value) => _toggleSentence(index, value ?? false),
              title: Text(sentence, style: const TextStyle(height: 1.5)),
              subtitle: Text('의미 단위 ${index + 1}'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildExplainHelperText() {
    if (_selectedIndexes.isEmpty) {
      return Text(
        '문장을 하나 선택하면 쉽게 풀어보기를 사용할 수 있습니다.',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade700,
        ),
      );
    }

    if (_hasMultipleSelection) {
      return const Text(
        '문장을 하나만 선택해 주세요.',
        style: TextStyle(
          fontSize: 13,
          color: Colors.orange,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Text(
      '문장을 수정하면 더 정확한 설명을 받을 수 있습니다.',
      style: TextStyle(
        fontSize: 13,
        color: Colors.grey.shade700,
      ),
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
              '책 페이지를 촬영하거나 앨범에서 사진을 선택한 뒤, 저장할 의미 단위를 골라 주세요.',
              style: TextStyle(color: Colors.blueGrey, height: 1.5),
            ),
            const SizedBox(height: 16),
            _buildTopActions(),
            const SizedBox(height: 20),
            _buildImagePreview(),
            _buildParagraphPreview(),
            if (_imageFile != null) const SizedBox(height: 20),
            _buildSentenceList(),
            const SizedBox(height: 24),
            _buildExplainHelperText(),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed:
                    _canExplainSingleSentence ? _openExplainBottomSheet : null,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('쉽게 풀어보기'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: canProceed ? _goToCreateScreen : null,
                icon: const Icon(Icons.save_alt),
                label: const Text('저장'),
              ),
            ),
            const SizedBox(height: 16),
            if (kDebugMode)
              const Text(
                '디버그 모드에서는 OCR 원문과 의미 단위 분리 결과가 콘솔에 출력됩니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExplainResultSheet extends StatefulWidget {
  final String initialText;
  final Future<void> Function(String text) onSaveToMoment;
  final ReadingExplainService explainService;
  final int bookId;

  const _ExplainResultSheet({
    required this.initialText,
    required this.onSaveToMoment,
    required this.explainService,
    required this.bookId,
  });

  @override
  State<_ExplainResultSheet> createState() => _ExplainResultSheetState();
}

class _ExplainResultSheetState extends State<_ExplainResultSheet> {
  late final TextEditingController _textController;
  bool _loading = true;
  String? _errorText;
  ReadingExplainResult? _result;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestExplanation(isRetry: false);
    });
  }

  Future<void> _requestExplanation({required bool isRetry}) async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _loading = false;
        _errorText = '문장을 확인해 주세요.';
        _result = null;
      });
      return;
    }

    AppLogger.action(
      isRetry ? 'ai_explain_retry' : 'ai_explain_requested',
      detail: 'bookId=${widget.bookId}, textLength=${text.length}',
    );
    print(
      '🤖 ${isRetry ? 'ai_explain_retry' : 'ai_explain_requested'} | bookId=${widget.bookId} | textLength=${text.length}',
    );

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final result = await widget.explainService.explainSentence(text);

      if (!mounted) return;

      setState(() {
        _result = result;
        _loading = false;
        _errorText = null;
      });

      AppLogger.action(
        'ai_explain_success',
        detail: 'bookId=${widget.bookId}, textLength=${text.length}',
      );
      print(
        '✅ ai_explain_success | bookId=${widget.bookId} | textLength=${text.length}',
      );
    } catch (e, st) {
      AppLogger.apiError('ai_explain', e, stackTrace: st);

      if (!mounted) return;

      setState(() {
        _loading = false;
        _result = null;
        _errorText = '설명을 불러오지 못했습니다. 다시 시도해 주세요.';
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '선택 문장',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '문장을 수정하면 더 정확한 설명을 받을 수 있습니다',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '쉽게 풀어보기 결과',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorText != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorText!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              )
            else if (_result != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _result!.summary,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _result!.explanation,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                        await widget.onSaveToMoment(_textController.text.trim());
                      },
                icon: const Icon(Icons.edit_note),
                label: const Text('기록으로 남기기'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            await _requestExplanation(isRetry: true);
                          },
                    child: const Text('다시 보기'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      AppLogger.action(
                        'ai_explain_closed',
                        detail: 'bookId=${widget.bookId}',
                      );
                      print(
                        '🪟 ai_explain_closed | bookId=${widget.bookId}',
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}