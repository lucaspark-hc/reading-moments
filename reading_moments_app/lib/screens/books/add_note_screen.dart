import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/book_model.dart';
import '../../models/reading_note.dart';
import '../../services/reading_notes_service.dart';

class AddNoteScreen extends StatefulWidget {
  final BookModel book;
  final ReadingNote? existingNote;

  const AddNoteScreen({
    super.key,
    required this.book,
    this.existingNote,
  });

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quoteController = TextEditingController();
  final _noteController = TextEditingController();
  final _pageController = TextEditingController();

  final ReadingNotesService _notesService = ReadingNotesService();

  bool _isSaving = false;
  bool _initialized = false;

  String _type = 'quote';
  String _visibility = 'private';

  bool get _isEditMode => widget.existingNote != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindInitialDataOnce();
  }

  void _bindInitialDataOnce() {
    if (_initialized) return;
    _initialized = true;

    final note = widget.existingNote;
    if (note == null) return;

    _type = note.type;
    _visibility = note.visibility;

    _quoteController.value = TextEditingValue(
      text: note.quoteText ?? '',
      selection: TextSelection.collapsed(
        offset: (note.quoteText ?? '').length,
      ),
    );

    _noteController.value = TextEditingValue(
      text: note.noteText ?? '',
      selection: TextSelection.collapsed(
        offset: (note.noteText ?? '').length,
      ),
    );

    _pageController.value = TextEditingValue(
      text: note.page?.toString() ?? '',
      selection: TextSelection.collapsed(
        offset: (note.page?.toString() ?? '').length,
      ),
    );
  }

  @override
  void dispose() {
    _quoteController.dispose();
    _noteController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final quote = _quoteController.text.trim();
    final noteText = _noteController.text.trim();

    if (quote.isEmpty && noteText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('구절 또는 생각 중 하나는 입력해야 합니다.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final pageText = _pageController.text.trim();
      final page = pageText.isEmpty ? null : int.tryParse(pageText);

      if (_isEditMode) {
        await _notesService.updateNote(
          id: widget.existingNote!.id,
          type: _type,
          quoteText: quote.isEmpty ? null : quote,
          noteText: noteText.isEmpty ? null : noteText,
          visibility: _visibility,
          page: page,
        );
      } else {
        await _notesService.createNote(
          userId: user.id,
          bookId: widget.book.id,
          type: _type,
          quoteText: quote.isEmpty ? null : quote,
          noteText: noteText.isEmpty ? null : noteText,
          visibility: _visibility,
          page: page,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? '기록이 수정되었습니다.' : '기록이 저장되었습니다.'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditMode ? '수정 실패: $e' : '저장 실패: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
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
  Widget build(BuildContext context) {
    final book = widget.book;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '기록 수정' : '기록 추가'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if ((book.author ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  book.author!,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                '기록 종류',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _type,
                items: ['quote', 'summary', 'question']
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(_typeLabel(e)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _type = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _quoteController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '구절',
                  hintText: '인상 깊은 문장을 입력하세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _noteController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '내 생각',
                  hintText: '이 문장에 대한 생각을 남겨보세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _pageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '페이지(선택)',
                  hintText: '예: 128',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '공개 범위',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              RadioListTile<String>(
                value: 'private',
                groupValue: _visibility,
                title: const Text('비공개'),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _visibility = value;
                  });
                },
              ),
              RadioListTile<String>(
                value: 'public',
                groupValue: _visibility,
                title: const Text('공개'),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _visibility = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const CircularProgressIndicator()
                      : Text(_isEditMode ? '수정 완료' : '저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}