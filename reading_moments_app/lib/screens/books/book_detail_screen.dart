import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/book_model.dart';
import '../../models/reading_note.dart';
import '../../services/reading_notes_service.dart';
import 'add_note_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final BookModel book;

  const BookDetailScreen({
    super.key,
    required this.book,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final ReadingNotesService _notesService = ReadingNotesService();

  bool _isLoading = true;
  List<ReadingNote> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final notes = await _notesService.getMyNotesByBook(
        userId: user.id,
        bookId: widget.book.id,
      );

      if (!mounted) return;

      setState(() {
        _notes = notes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내 기록 조회 실패: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _goAddNote() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNoteScreen(book: widget.book),
      ),
    );

    if (result == true) {
      await _loadNotes();
    }
  }

  Future<void> _goEditNote(ReadingNote note) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNoteScreen(
          book: widget.book,
          existingNote: note,
        ),
      ),
    );

    if (result == true) {
      await _loadNotes();
    }
  }

  Future<void> _deleteNote(ReadingNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('기록 삭제'),
          content: const Text('이 기록을 삭제하시겠습니까? 삭제 후 복구할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _notesService.deleteNote(note.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기록이 삭제되었습니다.')),
      );

      await _loadNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  String _visibilityLabel(String visibility) {
    return visibility == 'public' ? '공개' : '비공개';
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Widget _buildNoteCard(ReadingNote note) {
    final hasSentence = (note.quoteText ?? '').trim().isNotEmpty;
    final hasThought = (note.noteText ?? '').trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(label: Text(_visibilityLabel(note.visibility))),
                const Spacer(),
                if (note.page != null) ...[
                  Text('p.${note.page}'),
                  const SizedBox(width: 4),
                ],
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await _goEditNote(note);
                    } else if (value == 'delete') {
                      await _deleteNote(note);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('수정'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('삭제'),
                    ),
                  ],
                ),
              ],
            ),
            if (hasSentence) ...[
              const SizedBox(height: 10),
              const Text(
                '문장',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '“${note.quoteText!}”',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
            if (hasThought) ...[
              const SizedBox(height: 14),
              const Text(
                '내 생각',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                note.noteText!,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              _formatDate(note.createdAt),
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('아직 기록이 없습니다. 첫 문장을 기록해 보세요.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;

    return Scaffold(
      appBar: AppBar(
        title: const Text('책 상세'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goAddNote,
        label: const Text('문장 기록'),
        icon: const Icon(Icons.edit_note),
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotes,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              book.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if ((book.author ?? '').trim().isNotEmpty)
              Text(
                book.author!,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            const SizedBox(height: 16),
            if ((book.coverUrl ?? '').trim().isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  book.coverUrl!,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 220,
                    color: Colors.grey.shade300,
                    alignment: Alignment.center,
                    child: const Text('표지 이미지 없음'),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              '내 기록',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '이 책에서 기록한 문장과 생각을 모아봅니다.',
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_notes.isEmpty)
              _buildEmptyState()
            else
              ..._notes.map(_buildNoteCard),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}