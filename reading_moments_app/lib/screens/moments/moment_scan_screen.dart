import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reading_moments_app/core/log/app_logger.dart';
import 'package:reading_moments_app/core/log/logged_state_mixin.dart';
import 'package:reading_moments_app/screens/moments/moment_create_screen.dart';
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
  final ReadingExplainService _readingExplainService = ReadingExplainService();

  bool _loading = false;
  bool _ocrPreviewExpanded = false;
  File? _imageFile;

  List<String> _paragraphs = <String>[];
  List<_SelectableUnitItem> _selectableUnits = <_SelectableUnitItem>[];
  final Set<int> _selectedIndexes = <int>{};

  @override
  String get screenName => 'MomentScanScreen';

  bool get _canExplainSingleSentence =>
      !_loading && _selectedIndexes.length == 1 && _selectableUnits.isNotEmpty;

  bool get _hasMultipleSelection => _selectedIndexes.length > 1;

  String? get _selectedSentence {
    if (_selectedIndexes.length != 1) return null;
    final index = _selectedIndexes.first;
    if (index < 0 || index >= _selectableUnits.length) return null;
    return _selectableUnits[index].text;
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
        _paragraphs = <String>[];
        _selectableUnits = <_SelectableUnitItem>[];
        _selectedIndexes.clear();
        _ocrPreviewExpanded = false;
      });

      final rawText = await _ocrService.recognizeText(picked.path);
      final paragraphs = _ocrService.splitIntoParagraphs(rawText);
      final selectableUnits = _buildSelectableUnitsFromParagraphs(paragraphs);

      debugPrint('===== OCR PARAGRAPHS START =====');
      for (var i = 0; i < paragraphs.length; i++) {
        debugPrint('[PARAGRAPH ${i + 1}] ${paragraphs[i]}');
      }
      debugPrint('===== OCR PARAGRAPHS END =====');

      debugPrint('===== SELECTABLE PARAGRAPHS START =====');
      for (final item in selectableUnits) {
        debugPrint(
          '[P${item.paragraphIndex + 1}-${item.orderInParagraph + 1}] ${item.text}',
        );
      }
      debugPrint('===== SELECTABLE PARAGRAPHS END =====');

      if (!mounted) return;

      setState(() {
        _paragraphs = paragraphs;
        _selectableUnits = selectableUnits;
      });

      AppLogger.action(
        'SelectableParagraphsPrepared',
        detail:
            'bookId=${widget.bookId}, paragraphCount=${_paragraphs.length}, selectableCount=${_selectableUnits.length}, mode=paragraph_only',
      );
      print(
        '🧱 SelectableParagraphsPrepared | bookId=${widget.bookId} | paragraphCount=${_paragraphs.length} | selectableCount=${_selectableUnits.length} | mode=paragraph_only',
      );

      if (_selectableUnits.isEmpty) {
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

  List<_SelectableUnitItem> _buildSelectableUnitsFromParagraphs(
    List<String> paragraphs,
  ) {
    final results = <_SelectableUnitItem>[];

    for (var paragraphIndex = 0;
        paragraphIndex < paragraphs.length;
        paragraphIndex++) {
      final paragraph = paragraphs[paragraphIndex].trim();
      if (paragraph.isEmpty) continue;

      results.add(
        _SelectableUnitItem(
          text: paragraph,
          paragraphIndex: paragraphIndex,
          orderInParagraph: 0,
        ),
      );
    }

    return results;
  }

  void _toggleOcrPreviewExpanded() {
    setState(() {
      _ocrPreviewExpanded = !_ocrPreviewExpanded;
    });

    AppLogger.action(
      'ToggleOcrParagraphPreview',
      detail:
          'bookId=${widget.bookId}, expanded=$_ocrPreviewExpanded, paragraphCount=${_paragraphs.length}',
    );
    print(
      '🪄 ToggleOcrParagraphPreview | bookId=${widget.bookId} | expanded=$_ocrPreviewExpanded | paragraphCount=${_paragraphs.length}',
    );
  }

  void _toggleSentence(int index, bool selected) {
    setState(() {
      if (selected) {
        _selectedIndexes.add(index);
      } else {
        _selectedIndexes.remove(index);
      }
    });

    final item = _selectableUnits[index];

    AppLogger.action(
      'sentence_selected',
      detail:
          'bookId=${widget.bookId}, index=$index, paragraph=${item.paragraphIndex + 1}, selected=$selected, selectedCount=${_selectedIndexes.length}',
    );
    print(
      '☑️ sentence_selected | bookId=${widget.bookId} | index=$index | paragraph=${item.paragraphIndex + 1} | selected=$selected | selectedCount=${_selectedIndexes.length}',
    );
  }

  Future<void> _openCreateScreen({
    required String quoteText,
    String? easyExplainText,
  }) async {
    AppLogger.action(
      'OpenMomentCreateFromScan',
      detail:
          'bookId=${widget.bookId}, hasEasyExplain=${(easyExplainText ?? '').trim().isNotEmpty}',
    );
    print(
      '📝 OpenMomentCreateFromScan | bookId=${widget.bookId} | hasEasyExplain=${(easyExplainText ?? '').trim().isNotEmpty}',
    );

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MomentCreateScreen(
          bookId: widget.bookId,
          initialQuoteText: quoteText,
          initialEasyExplainText: easyExplainText,
          initialInputMethod: 'ocr',
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _goToCreateScreen() async {
    if (_selectedIndexes.isEmpty) {
      showToast(context, '저장할 문장을 선택하세요.');
      return;
    }

    final selectedTexts = _selectedIndexes.toList()..sort();
    final mergedText =
        selectedTexts.map((i) => _selectableUnits[i].text).join('\n\n');

    await _openCreateScreen(quoteText: mergedText);
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
        onConfirm: (quoteText, explainText) async {
          await _openCreateScreen(
            quoteText: quoteText,
            easyExplainText: explainText,
          );
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
    if (_paragraphs.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _toggleOcrPreviewExpanded,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'OCR 문단 원문',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    _ocrPreviewExpanded ? '접기' : '보기',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blueGrey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _ocrPreviewExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.blueGrey.shade700,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...List.generate(_paragraphs.length, (index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == _paragraphs.length - 1 ? 0 : 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '문단 ${index + 1}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _paragraphs[index],
                            style: const TextStyle(height: 1.55),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            crossFadeState: _ocrPreviewExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
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

    if (_selectableUnits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('분리된 문장이 없습니다. 다른 사진으로 다시 시도해 주세요.')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '선택 가능한 문장',
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
        ...List.generate(_selectableUnits.length, (index) {
          final item = _selectableUnits[index];
          final selected = _selectedIndexes.contains(index);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: CheckboxListTile(
              value: selected,
              onChanged: (value) => _toggleSentence(index, value ?? false),
              title: Text(
                item.text,
                style: const TextStyle(height: 1.5),
              ),
              subtitle: Text(
                '문단 ${item.paragraphIndex + 1} · 항목 ${item.orderInParagraph + 1}',
              ),
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
              '책 페이지를 촬영하거나 앨범에서 사진을 선택한 뒤, 저장할 문장을 골라 주세요.',
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
                '디버그 모드에서는 OCR 문단과 선택 가능한 문단 결과가 콘솔에 출력됩니다.',
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
  final Future<void> Function(String quoteText, String explainText) onConfirm;
  final ReadingExplainService explainService;
  final int bookId;

  const _ExplainResultSheet({
    required this.initialText,
    required this.onConfirm,
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

  String _buildExplainText() {
    final explanation = _result?.explanation.trim() ?? '';
    return explanation;
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
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Text(
                  _buildExplainText(),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading || _result == null
                    ? null
                    : () async {
                        final quoteText = _textController.text.trim();
                        final explainText = _buildExplainText().trim();

                        AppLogger.action(
                          'ConfirmEasyExplain',
                          detail:
                              'bookId=${widget.bookId}, quoteLength=${quoteText.length}, explainLength=${explainText.length}',
                        );
                        print(
                          '✅ ConfirmEasyExplain | bookId=${widget.bookId} | quoteLength=${quoteText.length} | explainLength=${explainText.length}',
                        );

                        Navigator.pop(context);
                        await widget.onConfirm(quoteText, explainText);
                      },
                icon: const Icon(Icons.check),
                label: const Text('확인'),
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
                      print('🪟 ai_explain_closed | bookId=${widget.bookId}');
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

class _SelectableUnitItem {
  final String text;
  final int paragraphIndex;
  final int orderInParagraph;

  const _SelectableUnitItem({
    required this.text,
    required this.paragraphIndex,
    required this.orderInParagraph,
  });
}