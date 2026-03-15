import 'package:flutter/material.dart';
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

class _EditRecordScreenState extends State<EditRecordScreen> {
  final MyRecordsService _myRecordsService = MyRecordsService();

  late final TextEditingController _quoteController;
  late final TextEditingController _noteController;
  late final TextEditingController _pageController;

  bool _saving = false;
  late String _type;
  late String _visibility;

  @override
  void initState() {
    super.initState();
    _quoteController = TextEditingController(text: widget.item.quoteText ?? '');
    _noteController = TextEditingController(text: widget.item.noteText ?? '');
    _pageController = TextEditingController(
      text: widget.item.page?.toString() ?? '',
    );
    _type = widget.item.type;
    _visibility = widget.item.visibility;
  }

  Future<void> _save() async {
    final quoteText = _quoteController.text.trim();
    final noteText = _noteController.text.trim();
    final page = int.tryParse(_pageController.text.trim());

    if (quoteText.isEmpty && noteText.isEmpty) {
      showToast(context, '구절 또는 내 생각 중 하나는 입력해 주세요.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _myRecordsService.updateNote(
        noteId: widget.item.id,
        type: _type,
        quoteText: quoteText,
        noteText: noteText,
        visibility: _visibility,
        page: page,
      );

      if (!mounted) return;
      showToast(context, '기록이 수정되었습니다.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, '기록 수정 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _typeLabel(String value) {
    switch (value) {
      case 'summary':
        return '요약';
      case 'question':
        return '질문';
      case 'quote':
      default:
        return '구절';
    }
  }

  @override
  void dispose() {
    _quoteController.dispose();
    _noteController.dispose();
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
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(
              labelText: '기록 종류',
            ),
            items: const [
              DropdownMenuItem(
                value: 'quote',
                child: Text('구절'),
              ),
              DropdownMenuItem(
                value: 'summary',
                child: Text('요약'),
              ),
              DropdownMenuItem(
                value: 'question',
                child: Text('질문'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _type = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '페이지',
              hintText: '예: 127',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quoteController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: '${_typeLabel(_type)} 내용',
              hintText: '인상 깊은 문장이나 내용을 입력하세요.',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: '내 생각',
              hintText: '이 문장을 보고 든 생각을 적어보세요.',
              border: OutlineInputBorder(),
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