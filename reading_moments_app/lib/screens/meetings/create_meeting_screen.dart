import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/book_search_result.dart';
import 'package:reading_moments_app/services/books_service.dart';
import 'package:reading_moments_app/services/meetings_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final BooksService _booksService = BooksService();
  final MeetingsService _meetingsService = MeetingsService();

  final _searchController = TextEditingController();
  final _isbn = TextEditingController();
  final _bookTitle = TextEditingController();
  final _author = TextEditingController();
  final _description = TextEditingController();
  final _meetingTitle = TextEditingController();
  final _location = TextEditingController();
  final _maxParticipants = TextEditingController(text: '5');
  final _hostReason = TextEditingController();

  bool _loading = false;
  bool _searching = false;
  bool _reasonLoading = false;
  bool _descriptionLoading = false;

  DateTime _meetingDate = DateTime.now().add(const Duration(days: 1));
  List<BookSearchResult> _searchResults = [];
  BookSearchResult? _selectedBook;

  Future<void> _searchBooks() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      showToast(context, '검색어를 입력하세요.');
      return;
    }

    setState(() => _searching = true);
    try {
      _searchResults = await _booksService.searchBooks(q);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      showToast(context, '책 검색 실패: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectBook(BookSearchResult book) {
    setState(() {
      _selectedBook = book;
      _isbn.text = book.isbn;
      _bookTitle.text = book.title;
      _author.text = book.author;
      _description.text = book.description.trim();
    });
  }

  Future<void> _generateBookDescription() async {
    if (_selectedBook == null) {
      showToast(context, '먼저 책을 선택하세요.');
      return;
    }

    setState(() => _descriptionLoading = true);
    try {
      _description.text = await _booksService.generateDescription(
        title: _bookTitle.text.trim(),
        author: _author.text.trim(),
        publisher: _selectedBook?.publisher ?? '',
        publishedDate: _selectedBook?.publishedDate ?? '',
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      showToast(context, '책 소개 생성 실패: $e');
    } finally {
      if (mounted) setState(() => _descriptionLoading = false);
    }
  }

  Future<void> _generateReason() async {
    if (_selectedBook == null) {
      showToast(context, '먼저 책을 선택하세요.');
      return;
    }

    setState(() => _reasonLoading = true);
    try {
      _hostReason.text = await _booksService.generateReason(
        title: _bookTitle.text.trim(),
        author: _author.text.trim(),
        description: _description.text.trim(),
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      showToast(context, '선정 이유 생성 실패: $e');
    } finally {
      if (mounted) setState(() => _reasonLoading = false);
    }
  }

  Future<void> _saveMeeting() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      showToast(context, '로그인이 필요합니다.');
      return;
    }

    final meetingTitle = _meetingTitle.text.trim();
    final location = _location.text.trim();
    final maxParticipants = int.tryParse(_maxParticipants.text.trim()) ?? 5;
    final hostReason = _hostReason.text.trim();

    if (_selectedBook == null) {
      showToast(context, '책을 검색하고 선택하세요.');
      return;
    }

    if (meetingTitle.isEmpty) {
      showToast(context, '모임 제목을 입력하세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      final bookId = await _booksService.findOrCreateBook(
        isbn: _isbn.text.trim(),
        title: _bookTitle.text.trim(),
        author: _author.text.trim(),
        description: _description.text.trim(),
        coverUrl: _selectedBook?.coverUrl,
      );

      await _meetingsService.createMeeting(
        hostId: uid,
        bookId: bookId,
        title: meetingTitle,
        meetingDate: _meetingDate,
        location: location,
        maxParticipants: maxParticipants,
        hostReason: hostReason,
      );

      if (!mounted) return;
      showToast(context, '모임이 생성되었습니다.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showToast(context, '모임 생성 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _meetingDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_meetingDate),
    );
    if (time == null || !mounted) return;

    setState(() {
      _meetingDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _isbn.dispose();
    _bookTitle.dispose();
    _author.dispose();
    _description.dispose();
    _meetingTitle.dispose();
    _location.dispose();
    _maxParticipants.dispose();
    _hostReason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('모임 만들기'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('1. 책 검색'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: '책 제목 검색',
                    hintText: '예: 작별하지 않는다',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _searching ? null : _searchBooks,
                  child: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('검색'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_searchResults.isNotEmpty) ...[
            const Text('검색 결과'),
            const SizedBox(height: 8),
            ..._searchResults.map(
              (book) => Card(
                child: ListTile(
                  leading: book.coverUrl.isNotEmpty
                      ? Image.network(book.coverUrl, width: 40, fit: BoxFit.cover)
                      : const Icon(Icons.menu_book),
                  title: Text(book.title),
                  subtitle: Text('${book.author}\nISBN: ${book.isbn}'),
                  isThreeLine: true,
                  onTap: () => _selectBook(book),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          const Text('2. 선택한 책 정보'),
          const SizedBox(height: 12),
          if (_selectedBook != null && _selectedBook!.coverUrl.isNotEmpty)
            Center(
              child: Image.network(
                _selectedBook!.coverUrl,
                height: 160,
                fit: BoxFit.contain,
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _bookTitle,
            readOnly: true,
            decoration: const InputDecoration(labelText: '책 제목'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _author,
            readOnly: true,
            decoration: const InputDecoration(labelText: '저자'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _isbn,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'ISBN'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '책 소개',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: _descriptionLoading ? null : _generateBookDescription,
                  icon: const Icon(Icons.auto_awesome),
                  label: _descriptionLoading
                      ? const Text('생성 중...')
                      : const Text('자동생성'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _description,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '책 소개를 입력하거나 자동생성을 눌러주세요.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const Text('3. 모임 정보'),
          const SizedBox(height: 12),
          TextField(
            controller: _meetingTitle,
            decoration: const InputDecoration(labelText: '모임 제목'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            decoration: const InputDecoration(labelText: '장소'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _maxParticipants,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '최대 인원'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('모임 일시'),
            subtitle: Text(formatDateTime(_meetingDate)),
            trailing: const Icon(Icons.calendar_month),
            onTap: _pickDateTime,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '4. 선정 이유',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: _reasonLoading ? null : _generateReason,
                  icon: const Icon(Icons.auto_awesome),
                  label: _reasonLoading
                      ? const Text('생성 중...')
                      : const Text('자동생성'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _hostReason,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '선정 이유를 입력하거나 자동생성을 눌러주세요.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _saveMeeting,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('모임 저장'),
            ),
          ),
        ],
      ),
    );
  }
}