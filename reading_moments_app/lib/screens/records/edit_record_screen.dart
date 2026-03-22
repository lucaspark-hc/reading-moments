import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/log/app_logger.dart';
import 'package:reading_moments_app/core/log/logged_state_mixin.dart';
import 'package:reading_moments_app/models/my_record_item.dart';
import 'package:reading_moments_app/services/my_records_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class EditRecordScreen extends StatefulWidget {
  final MyRecordItem item;

  const EditRecordScreen({
    super.key,
    required this.item,
  });

  @override
  State<EditRecordScreen> createState() => _EditRecordScreenState();
}

class _EditRecordScreenState extends State<EditRecordScreen>
    with LoggedStateMixin<EditRecordScreen> {
  final MyRecordsService _myRecordsService = MyRecordsService();

  late final TextEditingController _sentenceController;
  late final TextEditingController _thoughtController;
  late final TextEditingController _pageController;

  bool _saving = false;
  late String _visibility;

  @override
  String get screenName => 'EditRecordScreen';

  @override
  void initState() {
    super.initState();
    _sentenceController = TextEditingController(text: widget.item.quoteText ?? '');
    _thoughtController = TextEditingController(text: widget.item.noteText ?? '');
    _pageController = TextEditingController(
      text: widget.item.page?.toString() ?? '',
    );
    _visibility = widget.item.visibility;
  }

  Future<void> _save() async {
    final sentence = _sentenceController.text.trim();
    final thought = _thoughtController.text.trim();
    final page = int.tryParse(_pageController.text.trim());

    if (sentence.isEmpty) {
      showToast(context, '문장을 입력해 주세요.');
      return;
    }

    setState(() => _saving = true);

    AppLogger.action(
      'SaveEditedRecord',
      detail: 'recordId=${widget.item.id}, visibility=$_visibility, page=$page',
    );

    try {
      await _myRecordsService.updateNote(
        noteId: widget.item.id,
        quoteText: sentence,
        noteText: thought.isEmpty ? null : thought,
        visibility: _visibility,
        page: page,
      );

      if (!mounted) return;
      showToast(context, '기록이 수정되었습니다.');
      Navigator.pop(context, true);
    } catch (e, st) {
      AppLogger.apiError('updateNote(from EditRecordScreen)', e, stackTrace: st);
      if (!mounted) return;
      showToast(context, '기록 수정 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _sentenceController.dispose();
    _thoughtController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: const Text('기록 수정'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            item.bookTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if ((item.bookAuthor ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.bookAuthor!,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _sentenceController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '문장',
              hintText: '인상 깊은 문장을 입력하세요.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _thoughtController,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: '내 생각 (선택)',
              hintText: '이 문장을 보고 든 생각을 적어보세요.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '페이지 (선택)',
              hintText: '예: 127',
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '공개 범위',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          RadioListTile<String>(
            value: 'public',
            groupValue: _visibility,
            title: const Text('공개'),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _visibility = value);
            },
          ),
          RadioListTile<String>(
            value: 'private',
            groupValue: _visibility,
            title: const Text('비공개'),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _visibility = value);
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('수정 저장'),
            ),
          ),
        ],
      ),
    );
  }
}