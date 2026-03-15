import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/book_model.dart';
import 'package:reading_moments_app/models/book_search_result.dart';
import 'package:reading_moments_app/models/my_book_record_group_item.dart';
import 'package:reading_moments_app/screens/books/add_note_screen.dart';
import 'package:reading_moments_app/screens/records/book_records_screen.dart';
import 'package:reading_moments_app/screens/selections/book_selection_detail_screen.dart';
import 'package:reading_moments_app/services/book_selections_service.dart';
import 'package:reading_moments_app/services/books_service.dart';
import 'package:reading_moments_app/services/library_service.dart';
import 'package:reading_moments_app/services/my_records_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class CreateMeetingScreen extends StatefulWidget {
  final BookModel? initialBook;

  const CreateMeetingScreen({
    super.key,
    this.initialBook,
  });

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final BooksService _booksService = BooksService();
  final BookSelectionsService _bookSelectionsService = BookSelectionsService();
  final MyRecordsService _myRecordsService = MyRecordsService();
  final LibraryService _libraryService = LibraryService();

  final _searchController = TextEditingController();
  final _isbn = TextEditingController();
  final _bookTitle = TextEditingController();
  final _author = TextEditingController();
  final _description = TextEditingController();
  final _selectionReason = TextEditingController();

  bool _loading = false;
  bool _searching = false;
  bool _reasonLoading = false;
  bool _descriptionLoading = false;
  bool _openingNote = false;

  String _visibility = 'public';

  List<BookSearchResult> _searchResults = [];
  BookSearchResult? _selectedBook;

  bool get _isPreselectedMode => widget.initialBook != null;

  @override
  void initState() {
    super.initState();
    _bindInitialBook();
  }

  void _bindInitialBook() {
    final book = widget.initialBook;
    if (book == null) return;

    _bookTitle.text = book.title;
    _author.text = book.author ?? '';
    _isbn.text = book.isbn;
    _description.text = '';

    _selectedBook = BookSearchResult(
      googleBookId: 'wishlist_${book.id}',
      title: book.title,
      author: book.author ?? '',
      isbn: book.isbn,
      description: '',
      publisher: '',
      publishedDate: '',
      coverUrl: book.coverUrl ?? '',
    );
  }

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
      _selectionReason.text = await _booksService.generateReason(
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

  Future<void> _openAddNote() async {
    if (_selectedBook == null) {
      showToast(context, '먼저 책을 선택하세요.');
      return;
    }

    setState(() => _openingNote = true);
    try {
      final bookId = await _booksService.findOrCreateBook(
        isbn: _isbn.text.trim(),
        title: _bookTitle.text.trim(),
        author: _author.text.trim(),
        description: _description.text.trim(),
        coverUrl: _selectedBook?.coverUrl,
      );

      if (!mounted) return;

      final book = BookModel(
        id: bookId,
        isbn: _isbn.text.trim(),
        title: _bookTitle.text.trim(),
        author: _author.text.trim().isEmpty ? null : _author.text.trim(),
        coverUrl: _selectedBook?.coverUrl,
        category: null,
      );

      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AddNoteScreen(book: book),
        ),
      );

      if (!mounted) return;
      if (saved != true) return;

      final group = await _findBookRecordGroup(bookId);
      if (!mounted) return;

      if (group != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookRecordsScreen(group: group),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      showToast(context, '기록 화면 이동 실패: $e');
    } finally {
      if (mounted) setState(() => _openingNote = false);
    }
  }

  Future<MyBookRecordGroupItem?> _findBookRecordGroup(int bookId) async {
    final groups = await _myRecordsService.loadMyBookRecordGroups();
    for (final group in groups) {
      if (group.bookId == bookId) {
        return group;
      }
    }
    return null;
  }

  Future<void> _saveSelection() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      showToast(context, '로그인이 필요합니다.');
      return;
    }

    if (_selectedBook == null) {
      showToast(context, '책을 검색하고 선택하세요.');
      return;
    }

    final selectionReason = _selectionReason.text.trim();
    if (selectionReason.isEmpty) {
      showToast(context, '이 책을 고른 이유를 입력하세요.');
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

      final selection = await _bookSelectionsService.createSelection(
        userId: uid,
        bookId: bookId,
        bookDescription: _description.text.trim(),
        selectionReason: selectionReason,
        visibility: _visibility,
      );

      if (_isPreselectedMode) {
        await _libraryService.removeWishlistBook(bookId);
      }

      if (!mounted) return;
      showToast(context, '독서를 시작합니다.');

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookSelectionDetailScreen(selection: selection),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showToast(context, '독서 시작 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _isbn.dispose();
    _bookTitle.dispose();
    _author.dispose();
    _description.dispose();
    _selectionReason.dispose();
    super.dispose();
  }

  Widget _buildIntroCard() {
    final text = _isPreselectedMode
        ? '읽고 싶은 책에서 선택된 책입니다. 먼저 독서 시작을 완료해 주세요. 저장 후 기록 남기기로 이어갈 수 있습니다.'
        : '먼저 읽을 책을 고르고, 왜 이 책을 읽고 싶은지 정리해 저장합니다. 저장된 기록은 나중에 피드와 모임으로 이어질 수 있습니다.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(height: 1.5),
      ),
    );
  }

  Widget _buildSearchSection() {
    if (_isPreselectedMode) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                    ? Image.network(
                        book.coverUrl,
                        width: 40,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.menu_book),
                title: Text(book.title),
                subtitle: Text('${book.author}\nISBN: ${book.isbn}'),
                isThreeLine: true,
                onTap: () => _selectBook(book),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBookInfoSection() {
    final hasSelectedBook = _selectedBook != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_isPreselectedMode ? '1. 선택한 책 정보' : '2. 선택한 책 정보'),
        const SizedBox(height: 12),
        if (!hasSelectedBook)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('책을 검색해서 선택해 주세요.'),
          ),
        if (hasSelectedBook) ...[
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
                      : Text(
                          _description.text.trim().isEmpty ? '자동생성' : '다시 생성',
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_description.text.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '책 소개가 비어 있습니다. 자동생성을 눌러 채울 수 있습니다.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ),
          TextField(
            controller: _description,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '책 소개를 입력하거나 자동생성을 눌러주세요.',
              border: OutlineInputBorder(),
            ),
          ),
          if (!_isPreselectedMode) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _openingNote ? null : _openAddNote,
                icon: _openingNote
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_note),
                label: const Text('이 책으로 기록 남기기'),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildReasonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_isPreselectedMode ? '2. 이 책을 고른 이유' : '3. 이 책을 고른 이유'),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: SizedBox()),
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
          controller: _selectionReason,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: '왜 이 책을 읽고 싶은지, 어떤 이야기를 나누고 싶은지 적어보세요.',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildVisibilitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('읽을 책 고르기'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildIntroCard(),
          const SizedBox(height: 24),
          _buildSearchSection(),
          if (!_isPreselectedMode) const SizedBox(height: 24),
          _buildBookInfoSection(),
          const SizedBox(height: 24),
          _buildReasonSection(),
          const SizedBox(height: 20),
          _buildVisibilitySection(),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _saveSelection,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('독서 시작'),
            ),
          ),
        ],
      ),
    );
  }
}