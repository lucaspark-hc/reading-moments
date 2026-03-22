import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/log/app_logger.dart';
import '../../core/log/logged_state_mixin.dart';
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

class _AddNoteScreenState extends State<AddNoteScreen>
    with LoggedStateMixin<AddNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sentenceController = TextEditingController();
  final _thoughtController = TextEditingController();
  final _pageController = TextEditingController();

  final ReadingNotesService _notesService = ReadingNotesService();

  bool _isSaving = false;
  bool _initialized = false;

  String _visibility = 'private';

  @override
  String get screenName => 'AddNoteScreen';

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

    _visibility = note.visibility;

    _sentenceController.value = TextEditingValue(
      text: note.quoteText ?? '',
      selection: TextSelection.collapsed(
        offset: (note.quoteText ?? '').length,
      ),
    );

    _thoughtController.value = TextEditingValue(
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
    _sentenceController.dispose();
    _thoughtController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final sentence = _sentenceController.text.trim();
    final thought = _thoughtController.text.trim();

    if (sentence.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문장을 입력하세요.')),
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

      AppLogger.action(
        _isEditMode ? 'EditSentenceRecord' : 'CreateSentenceRecord',
        detail: 'bookId=${widget.book.id}, visibility=$_visibility, page=$page',
      );

      if (_isEditMode) {
        await _notesService.updateNote(
          id: widget.existingNote!.id,
          quoteText: sentence,
          noteText: thought.isEmpty ? null : thought,
          visibility: _visibility,
          page: page,
        );
      } else {
        await _notesService.createNote(
          userId: user.id,
          bookId: widget.book.id,
          quoteText: sentence,
          noteText: thought.isEmpty ? null : thought,
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
    } catch (e, st) {
      AppLogger.apiError(
        _isEditMode ? 'updateNote(from AddNoteScreen)' : 'createNote(from AddNoteScreen)',
        e,
        stackTrace: st,
      );

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

  @override
  Widget build(BuildContext context) {
    final book = widget.book;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '기록 수정' : '문장 기록'),
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
              TextFormField(
                controller: _sentenceController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '문장',
                  hintText: '인상 깊은 문장을 입력하세요',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return '문장을 입력하세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _thoughtController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '내 생각 (선택)',
                  hintText: '이 문장에 대한 생각을 남겨보세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _pageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '페이지 (선택)',
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
                      : Text(_isEditMode ? '수정 완료' : '기록 저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}