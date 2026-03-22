import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/log/app_logger.dart';
import 'package:reading_moments_app/core/log/logged_state_mixin.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/book_model.dart';
import 'package:reading_moments_app/models/book_search_result.dart';
import 'package:reading_moments_app/models/meeting_model.dart';
import 'package:reading_moments_app/models/my_book_record_group_item.dart';
import 'package:reading_moments_app/screens/library/my_library_screen.dart';
import 'package:reading_moments_app/screens/meetings/meeting_detail_screen.dart';
import 'package:reading_moments_app/services/book_selections_service.dart';
import 'package:reading_moments_app/services/books_service.dart';
import 'package:reading_moments_app/services/library_service.dart';
import 'package:reading_moments_app/services/meetings_service.dart';
import 'package:reading_moments_app/services/my_records_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

enum BookPickerMode {
  reading,
  meeting,
}

class _BookPickerSessionState {
  final String query;
  final List<BookSearchResult> searchResults;
  final BookSearchResult? selectedBook;

  const _BookPickerSessionState({
    required this.query,
    required this.searchResults,
    required this.selectedBook,
  });
}

class _BookPickerSessionCache {
  static final Map<String, _BookPickerSessionState> _cache =
      <String, _BookPickerSessionState>{};

  static String key(BookPickerMode mode) => mode.name;

  static _BookPickerSessionState? take(BookPickerMode mode) {
    return _cache.remove(key(mode));
  }

  static void save(BookPickerMode mode, _BookPickerSessionState state) {
    _cache[key(mode)] = state;
  }

  static void clear(BookPickerMode mode) {
    _cache.remove(key(mode));
  }
}

class CreateMeetingScreen extends StatefulWidget {
  final BookModel? initialBook;
  final bool startInMeetingMode;

  const CreateMeetingScreen({
    super.key,
    this.initialBook,
    this.startInMeetingMode = false,
  });

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen>
    with LoggedStateMixin<CreateMeetingScreen> {
  final BooksService _booksService = BooksService();
  final BookSelectionsService _bookSelectionsService = BookSelectionsService();
  final MyRecordsService _myRecordsService = MyRecordsService();
  final LibraryService _libraryService = LibraryService();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _isbn = TextEditingController();
  final TextEditingController _bookTitle = TextEditingController();
  final TextEditingController _author = TextEditingController();
  final TextEditingController _description = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  bool _loading = false;
  bool _searching = false;
  bool _searched = false;

  List<BookSearchResult> _searchResults = <BookSearchResult>[];
  BookSearchResult? _selectedBook;
  late BookPickerMode _mode;

  bool get _isPreselectedMode => widget.initialBook != null;
  bool get _hasSelectedBook => _selectedBook != null;
  bool get _canSubmit => _hasSelectedBook && !_loading;
  bool get _showEmptySearchResult =>
      _searched && !_searching && _searchResults.isEmpty;

  @override
  String get screenName => 'CreateMeetingScreen';

  @override
  void initState() {
    super.initState();
    _mode = widget.startInMeetingMode
        ? BookPickerMode.meeting
        : BookPickerMode.reading;
    _restoreOrBindInitialState();
  }

  void _restoreOrBindInitialState() {
    if (_isPreselectedMode) {
      _bindInitialBook();
      AppLogger.action(
        'BookPickerRestoreSkippedForInitialBook',
        detail: 'mode=${_mode.name}, reason=initialBook',
      );
      debugPrint(
        '[CreateMeetingScreen] restore skipped because initialBook exists '
        'mode=${_mode.name}',
      );
      return;
    }

    final restored = _BookPickerSessionCache.take(_mode);
    if (restored == null) {
      AppLogger.action(
        'BookPickerSessionRestore',
        detail: 'mode=${_mode.name}, restored=false',
      );
      debugPrint(
        '[CreateMeetingScreen] session restore mode=${_mode.name} restored=false',
      );
      return;
    }

    _searchController.text = restored.query;
    _searchResults = restored.searchResults;
    _searched =
        restored.query.trim().isNotEmpty || restored.searchResults.isNotEmpty;

    if (restored.selectedBook != null) {
      _applySelectedBook(restored.selectedBook!, logEvent: false);
    }

    AppLogger.action(
      'BookPickerSessionRestore',
      detail:
          'mode=${_mode.name}, restored=true, query=${restored.query}, resultCount=${restored.searchResults.length}, hasSelection=${restored.selectedBook != null}',
    );
    debugPrint(
      '[CreateMeetingScreen] session restore mode=${_mode.name} restored=true '
      'query=${restored.query} resultCount=${restored.searchResults.length} '
      'hasSelection=${restored.selectedBook != null}',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _logCtaState('restore');
      if (restored.selectedBook != null) {
        _ensureSelectedCardVisible();
      }
    });
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

    AppLogger.action(
      'BindInitialBookForPicker',
      detail: 'mode=${_mode.name}, title=${book.title}, bookId=${book.id}',
    );
    debugPrint(
      '[CreateMeetingScreen] bindInitialBook mode=${_mode.name} '
      'title=${book.title} bookId=${book.id}',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _logCtaState('initialBook');
    });
  }

  void _saveSessionState() {
    if (_isPreselectedMode) {
      return;
    }

    final hasMeaningfulState = _searchController.text.trim().isNotEmpty ||
        _searchResults.isNotEmpty ||
        _selectedBook != null;

    if (!hasMeaningfulState) {
      _BookPickerSessionCache.clear(_mode);
      return;
    }

    _BookPickerSessionCache.save(
      _mode,
      _BookPickerSessionState(
        query: _searchController.text.trim(),
        searchResults: List<BookSearchResult>.from(_searchResults),
        selectedBook: _selectedBook,
      ),
    );

    AppLogger.action(
      'BookPickerSessionSaved',
      detail:
          'mode=${_mode.name}, query=${_searchController.text.trim()}, resultCount=${_searchResults.length}, hasSelection=${_selectedBook != null}',
    );
    debugPrint(
      '[CreateMeetingScreen] session saved mode=${_mode.name} '
      'query=${_searchController.text.trim()} resultCount=${_searchResults.length} '
      'hasSelection=${_selectedBook != null}',
    );
  }

  void _dismissKeyboard({required String source}) {
    FocusScope.of(context).unfocus();
    AppLogger.action(
      'BookPickerKeyboardDismissed',
      detail: 'mode=${_mode.name}, source=$source',
    );
    debugPrint(
      '[CreateMeetingScreen] keyboard dismissed mode=${_mode.name} source=$source',
    );
  }

  void _clearSelectionUi() {
    _selectedBook = null;
    _isbn.clear();
    _bookTitle.clear();
    _author.clear();
    _description.clear();
  }

  void _applySelectedBook(
    BookSearchResult book, {
    bool logEvent = true,
  }) {
    _selectedBook = book;
    _isbn.text = book.isbn;
    _bookTitle.text = book.title;
    _author.text = book.author;
    _description.text = book.description.trim();

    if (logEvent) {
      AppLogger.action(
        'SelectBookFromPicker',
        detail: 'mode=${_mode.name}, title=${book.title}, isbn=${book.isbn}',
      );
      debugPrint(
        '[CreateMeetingScreen] selectBook mode=${_mode.name} '
        'title=${book.title} isbn=${book.isbn}',
      );
    }

    AppLogger.action(
      'ExpandSelectedBookCard',
      detail: 'mode=${_mode.name}, title=${book.title}',
    );
    debugPrint(
      '[CreateMeetingScreen] expand selected card mode=${_mode.name} title=${book.title}',
    );
  }

  void _logCtaState(String source) {
    AppLogger.action(
      'BookPickerCtaStateChanged',
      detail:
          'mode=${_mode.name}, source=$source, enabled=$_canSubmit, hasSelection=$_hasSelectedBook',
    );
    debugPrint(
      '[CreateMeetingScreen] ctaState mode=${_mode.name} '
      'source=$source enabled=$_canSubmit hasSelection=$_hasSelectedBook',
    );
  }

  Future<void> _ensureSelectedCardVisible() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    if (_selectedBook == null) return;
    if (!_scrollController.hasClients) return;

    final index = _searchResults.indexWhere(
      (e) => e.googleBookId == _selectedBook!.googleBookId,
    );
    if (index < 0) return;

    const double collapsedHeight = 118;
    const double expandedExtra = 120;
    final double approximateTop =
        (index * collapsedHeight).clamp(0, double.infinity);
    final double approximateBottom =
        approximateTop + collapsedHeight + expandedExtra;

    final position = _scrollController.position;
    final visibleTop = position.pixels;
    final visibleBottom = position.pixels + position.viewportDimension;

    double? targetOffset;

    if (approximateBottom > visibleBottom - 16) {
      targetOffset = (approximateBottom - position.viewportDimension + 24)
          .clamp(0.0, position.maxScrollExtent);
    } else if (approximateTop < visibleTop + 8) {
      targetOffset =
          (approximateTop - 12).clamp(0.0, position.maxScrollExtent);
    }

    if (targetOffset == null) {
      return;
    }

    AppLogger.action(
      'BookPickerAutoScrollAdjusted',
      detail:
          'mode=${_mode.name}, index=$index, from=${position.pixels.toStringAsFixed(1)}, to=${targetOffset.toStringAsFixed(1)}',
    );
    debugPrint(
      '[CreateMeetingScreen] auto scroll adjusted mode=${_mode.name} '
      'index=$index from=${position.pixels.toStringAsFixed(1)} '
      'to=${targetOffset.toStringAsFixed(1)}',
    );

    await _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _searchBooks() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      showToast(context, '검색어를 입력하세요.');
      return;
    }

    _dismissKeyboard(source: 'search');

    AppLogger.action(
      'SearchBooksFromPicker',
      detail: 'mode=${_mode.name}, query=$query',
    );
    debugPrint(
      '[CreateMeetingScreen] searchBooks mode=${_mode.name} query=$query',
    );

    setState(() {
      _searching = true;
      _searched = true;
      _searchResults = <BookSearchResult>[];
      _clearSelectionUi();
    });
    _logCtaState('newSearch');

    try {
      final results = await _booksService.searchBooks(query);
      if (!mounted) return;

      setState(() {
        _searchResults = results;
      });

      AppLogger.action(
        'SearchBooksFromPickerSuccess',
        detail: 'mode=${_mode.name}, query=$query, count=${results.length}',
      );
      debugPrint(
        '[CreateMeetingScreen] searchBooks success mode=${_mode.name} '
        'query=$query count=${results.length}',
      );

      if (results.isEmpty) {
        AppLogger.action(
          'BookPickerEmptySearchResult',
          detail: 'mode=${_mode.name}, query=$query',
        );
        debugPrint(
          '[CreateMeetingScreen] empty search result mode=${_mode.name} query=$query',
        );
      }
    } catch (e, st) {
      AppLogger.apiError('searchBooksFromPicker', e, stackTrace: st);
      debugPrint('[CreateMeetingScreen] searchBooks error: $e');
      if (!mounted) return;
      showToast(context, '책 검색 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _selectBook(BookSearchResult book) async {
    _dismissKeyboard(source: 'selectBook');

    setState(() {
      _applySelectedBook(book);
    });
    _logCtaState('selectBook');
    await _ensureSelectedCardVisible();
  }

  Future<int?> _ensureBookId() async {
    if (_selectedBook == null) {
      return null;
    }

    final isbn = _isbn.text.trim();
    final title = _bookTitle.text.trim();

    if (title.isEmpty) {
      return null;
    }

    return _booksService.findOrCreateBook(
      isbn: isbn,
      title: title,
      author: _author.text.trim(),
      description: _description.text.trim(),
      coverUrl: _selectedBook?.coverUrl,
    );
  }

  LibraryTabType _mapStatusToLibraryTab(LibraryBookStatus status) {
    switch (status) {
      case LibraryBookStatus.wishlist:
        return LibraryTabType.wishlist;
      case LibraryBookStatus.selected:
      case LibraryBookStatus.reading:
        return LibraryTabType.reading;
      case LibraryBookStatus.done:
        return LibraryTabType.done;
      case LibraryBookStatus.none:
        return LibraryTabType.wishlist;
    }
  }

  String _duplicateMessage(LibraryBookStatus status) {
    switch (status) {
      case LibraryBookStatus.wishlist:
        return '이미 읽고 싶은 책에 저장되어 있습니다.';
      case LibraryBookStatus.selected:
      case LibraryBookStatus.reading:
        return '이미 내 라이브러리의 독서중 책입니다.';
      case LibraryBookStatus.done:
        return '이미 완료한 책에 저장되어 있습니다.';
      case LibraryBookStatus.none:
        return '';
    }
  }

  Future<void> _moveToLibrary({
    required LibraryTabType tab,
    required int bookId,
    required String logSource,
  }) async {
    AppLogger.action(
      'MoveBookPickerToLibrary',
      detail:
          'mode=${_mode.name}, source=$logSource, tab=${tab.name}, bookId=$bookId',
    );
    debugPrint(
      '[CreateMeetingScreen] moveToLibrary mode=${_mode.name} '
      'source=$logSource tab=${tab.name} bookId=$bookId',
    );

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MyLibraryScreen(
          initialTab: tab,
          targetBookId: bookId,
        ),
      ),
    );
  }

  Future<void> _startReading() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      showToast(context, '로그인이 필요합니다.');
      return;
    }

    if (!_canSubmit) {
      showToast(context, '책을 먼저 선택하세요.');
      return;
    }

    AppLogger.action(
      'TapStartReadingFromPicker',
      detail: 'mode=${_mode.name}, title=${_bookTitle.text.trim()}',
    );
    debugPrint(
      '[CreateMeetingScreen] tapStartReading mode=${_mode.name} '
      'title=${_bookTitle.text.trim()}',
    );

    setState(() => _loading = true);

    try {
      final bookId = await _ensureBookId();
      if (bookId == null) {
        if (!mounted) return;
        showToast(context, '책 정보가 올바르지 않습니다.');
        return;
      }

      final currentStatus = await _libraryService.getBookStatus(bookId);

      if (currentStatus == LibraryBookStatus.wishlist) {
        AppLogger.action(
          'UpdateBookStatusWishlistToReading',
          detail: 'bookId=$bookId',
        );
        debugPrint(
          '[CreateMeetingScreen] update status wishlist -> reading bookId=$bookId',
        );

        await _libraryService.moveWishlistToReading(bookId);

        await _bookSelectionsService.createSelection(
          userId: uid,
          bookId: bookId,
          bookDescription: _description.text.trim(),
          selectionReason: '책 고르기에서 독서 시작',
          visibility: 'public',
        );

        if (!mounted) return;
        showToast(context, '독서중 책으로 추가되었습니다.');

        await _moveToLibrary(
          tab: LibraryTabType.reading,
          bookId: bookId,
          logSource: 'wishlistToReading',
        );
        return;
      }

      if (currentStatus == LibraryBookStatus.selected ||
          currentStatus == LibraryBookStatus.reading) {
        AppLogger.action(
          'DetectDuplicateBookBeforeStartReading',
          detail: 'bookId=$bookId, status=${currentStatus.name}',
        );
        debugPrint(
          '[CreateMeetingScreen] duplicate before startReading '
          'bookId=$bookId status=${currentStatus.name}',
        );

        if (!mounted) return;
        showToast(context, '이미 내 라이브러리의 독서중 책입니다.');

        await _moveToLibrary(
          tab: LibraryTabType.reading,
          bookId: bookId,
          logSource: 'duplicateStartReading',
        );
        return;
      }

      if (currentStatus == LibraryBookStatus.done) {
        AppLogger.action(
          'RereadStartRequestedButUnsupported',
          detail: 'bookId=$bookId',
        );
        debugPrint(
          '[CreateMeetingScreen] reread requested but done source is unsupported '
          'bookId=$bookId',
        );

        if (!mounted) return;
        showToast(context, '현재 완료 상태 재독 전환 기준이 아직 연결되지 않았습니다.');
        return;
      }

      await _bookSelectionsService.createSelection(
        userId: uid,
        bookId: bookId,
        bookDescription: _description.text.trim(),
        selectionReason: '책 고르기에서 독서 시작',
        visibility: 'public',
      );

      if (_isPreselectedMode) {
        await _libraryService.removeWishlistBook(bookId);
      }

      AppLogger.action(
        'StartReadingFromPickerSuccess',
        detail: 'bookId=$bookId, title=${_bookTitle.text.trim()}',
      );
      debugPrint(
        '[CreateMeetingScreen] startReading success '
        'bookId=$bookId title=${_bookTitle.text.trim()}',
      );

      if (!mounted) return;
      showToast(context, '독서중 책으로 추가되었습니다.');

      await _moveToLibrary(
        tab: LibraryTabType.reading,
        bookId: bookId,
        logSource: 'newStartReading',
      );
    } catch (e, st) {
      AppLogger.apiError('startReadingFromPicker', e, stackTrace: st);
      debugPrint('[CreateMeetingScreen] startReading error: $e');
      if (!mounted) return;
      showToast(context, '독서 시작 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveWishlist() async {
    if (!_canSubmit) {
      showToast(context, '책을 먼저 선택하세요.');
      return;
    }

    AppLogger.action(
      'TapSaveWishlistFromPicker',
      detail: 'mode=${_mode.name}, title=${_bookTitle.text.trim()}',
    );
    debugPrint(
      '[CreateMeetingScreen] tapSaveWishlist mode=${_mode.name} '
      'title=${_bookTitle.text.trim()}',
    );

    setState(() => _loading = true);

    try {
      final bookId = await _ensureBookId();
      if (bookId == null) {
        if (!mounted) return;
        showToast(context, '책 정보가 올바르지 않습니다.');
        return;
      }

      final currentStatus = await _libraryService.getBookStatus(bookId);

      if (currentStatus == LibraryBookStatus.none) {
        await _libraryService.ensureWishlistState(bookId);

        AppLogger.action(
          'SaveWishlistFromPickerSuccess',
          detail: 'bookId=$bookId, title=${_bookTitle.text.trim()}',
        );
        debugPrint(
          '[CreateMeetingScreen] saveWishlist success '
          'bookId=$bookId title=${_bookTitle.text.trim()}',
        );

        if (!mounted) return;
        showToast(context, '읽고 싶은 책에 저장되었습니다.');

        await _moveToLibrary(
          tab: LibraryTabType.wishlist,
          bookId: bookId,
          logSource: 'newWishlist',
        );
        return;
      }

      AppLogger.action(
        'DetectDuplicateBookBeforeWishlistSave',
        detail: 'bookId=$bookId, status=${currentStatus.name}',
      );
      debugPrint(
        '[CreateMeetingScreen] duplicate before wishlist save '
        'bookId=$bookId status=${currentStatus.name}',
      );

      if (!mounted) return;
      showToast(context, _duplicateMessage(currentStatus));

      await _moveToLibrary(
        tab: _mapStatusToLibraryTab(currentStatus),
        bookId: bookId,
        logSource: 'duplicateWishlist',
      );
    } catch (e, st) {
      AppLogger.apiError('saveWishlistFromPicker', e, stackTrace: st);
      debugPrint('[CreateMeetingScreen] saveWishlist error: $e');
      if (!mounted) return;
      showToast(context, '읽고 싶은 책 저장 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openMeetingCreateScreen() async {
    if (!_canSubmit || _selectedBook == null) {
      showToast(context, '책을 먼저 선택하세요.');
      return;
    }

    AppLogger.action(
      'TapOpenMeetingCreateScreenFromPicker',
      detail: 'title=${_bookTitle.text.trim()}, isbn=${_isbn.text.trim()}',
    );
    debugPrint(
      '[CreateMeetingScreen] openMeetingCreateScreen '
      'title=${_bookTitle.text.trim()} isbn=${_isbn.text.trim()}',
    );

    final book = BookModel(
      id: 0,
      isbn: _isbn.text.trim(),
      title: _bookTitle.text.trim(),
      author: _author.text.trim().isEmpty ? null : _author.text.trim(),
      coverUrl: _selectedBook?.coverUrl,
      category: null,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingCreateScreen(book: book),
      ),
    );
  }

  @override
  void dispose() {
    _saveSessionState();
    _searchController.dispose();
    _isbn.dispose();
    _bookTitle.dispose();
    _author.dispose();
    _description.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildIntroCard() {
    final String text = _mode == BookPickerMode.meeting
        ? '먼저 모임에 사용할 책을 고르세요. 선택한 책으로 바로 모임 만들기로 이어집니다.'
        : '책을 먼저 고른 뒤, 독서를 시작하거나 읽고 싶은 책에 저장할 수 있습니다.';

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

  Widget _buildBookResultCard(BookSearchResult book) {
    final bool selected = _selectedBook?.googleBookId == book.googleBookId;
    final String description = book.description.trim();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? Colors.blue.shade50 : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? Colors.blue.shade400 : Colors.grey.shade300,
          width: selected ? 1.6 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selectBook(book),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (book.coverUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          book.coverUrl,
                          width: 44,
                          height: 62,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 44,
                            height: 62,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.menu_book),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 44,
                        height: 62,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.menu_book),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  book.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              if (selected) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.check_circle,
                                  size: 20,
                                  color: Colors.blue,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            book.author.isEmpty ? '저자 정보 없음' : book.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ISBN: ${book.isbn}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  crossFadeState: selected
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(
                        description.isEmpty ? '책 소개 정보가 없습니다.' : description,
                        style: const TextStyle(
                          height: 1.45,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        const Text(
          '1. 책 검색',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _searching ? null : _searchBooks(),
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
        if (_showEmptySearchResult)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '검색 결과가 없습니다',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  '다른 키워드로 검색해보세요.',
                  style: TextStyle(height: 1.4),
                ),
              ],
            ),
          ),
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text(
            '검색 결과',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ..._searchResults.map(_buildBookResultCard),
        ],
      ],
    );
  }

  ButtonStyle _filledCtaStyle(bool enabled) {
    return FilledButton.styleFrom(
      backgroundColor: enabled ? null : Colors.grey.shade400,
      foregroundColor: enabled ? null : Colors.white70,
      disabledBackgroundColor: Colors.grey.shade400,
      disabledForegroundColor: Colors.white70,
      minimumSize: const Size.fromHeight(52),
    );
  }

  ButtonStyle _outlinedCtaStyle(bool enabled) {
    return OutlinedButton.styleFrom(
      foregroundColor: enabled ? null : Colors.grey.shade500,
      side: BorderSide(
        color: enabled ? Colors.grey.shade400 : Colors.grey.shade300,
      ),
      minimumSize: const Size.fromHeight(52),
    );
  }

  Widget _buildCtaSection() {
    final bool enabled = _canSubmit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: enabled ? Colors.green.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled ? Colors.green.shade200 : Colors.grey.shade300,
            ),
          ),
          child: Text(
            enabled ? '선택한 책으로 다음 단계를 진행할 수 있습니다.' : '책을 먼저 선택하세요',
            style: TextStyle(
              fontSize: 13,
              color: enabled ? Colors.green.shade800 : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        if (_mode == BookPickerMode.reading) ...[
          FilledButton(
            onPressed: enabled ? _startReading : null,
            style: _filledCtaStyle(enabled),
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('독서 시작'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: enabled ? _saveWishlist : null,
            style: _outlinedCtaStyle(enabled),
            child: const Text('읽고 싶은 책'),
          ),
        ] else ...[
          FilledButton(
            onPressed: enabled ? _openMeetingCreateScreen : null,
            style: _filledCtaStyle(enabled),
            child: const Text('이 책으로 모임 만들기'),
          ),
        ],
      ],
    );
  }

  Widget _buildPickerView() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_mode == BookPickerMode.meeting ? '책 고르기' : '읽을 책 고르기'),
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          _buildIntroCard(),
          const SizedBox(height: 20),
          _buildSearchSection(),
          const SizedBox(height: 24),
          _buildCtaSection(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildPickerView();
  }
}

class MeetingCreateScreen extends StatefulWidget {
  final BookModel book;

  const MeetingCreateScreen({
    super.key,
    required this.book,
  });

  @override
  State<MeetingCreateScreen> createState() => _MeetingCreateScreenState();
}

class _MeetingCreateScreenState extends State<MeetingCreateScreen>
    with LoggedStateMixin<MeetingCreateScreen> {
  final BooksService _booksService = BooksService();
  final MeetingsService _meetingsService = MeetingsService();

  final TextEditingController _meetingTitle = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _maxParticipants =
      TextEditingController(text: '5');
  final TextEditingController _meetingDescription = TextEditingController();

  bool _loading = false;
  DateTime _meetingDate = DateTime.now().add(const Duration(days: 1));

  @override
  String get screenName => 'MeetingCreateScreen';

  @override
  void initState() {
    super.initState();
    _meetingTitle.text = widget.book.title;
  }

  Future<int> _ensureBookId() async {
    return _booksService.findOrCreateBook(
      isbn: widget.book.isbn,
      title: widget.book.title,
      author: widget.book.author ?? '',
      description: '',
      coverUrl: widget.book.coverUrl,
    );
  }

  Future<void> _pickMeetingDateTime() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: _meetingDate.isBefore(now) ? now : _meetingDate,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );

    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_meetingDate),
    );

    if (time == null) return;

    final next = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    AppLogger.action(
      'PickMeetingDateTime',
      detail: 'meetingDate=${next.toIso8601String()}',
    );
    debugPrint(
      '[MeetingCreateScreen] pickMeetingDateTime ${next.toIso8601String()}',
    );

    setState(() {
      _meetingDate = next;
    });
  }

  String _formatMeetingDateTime(DateTime dt) {
    final v = dt.toLocal();
    final y = v.year.toString().padLeft(4, '0');
    final m = v.month.toString().padLeft(2, '0');
    final d = v.day.toString().padLeft(2, '0');
    final hh = v.hour.toString().padLeft(2, '0');
    final mm = v.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Future<void> _saveMeeting() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      showToast(context, '로그인이 필요합니다.');
      return;
    }

    final title = _meetingTitle.text.trim();
    if (title.isEmpty) {
      showToast(context, '모임 제목을 입력하세요.');
      return;
    }

    final maxParticipants = int.tryParse(_maxParticipants.text.trim());
    if (maxParticipants == null || maxParticipants <= 0) {
      showToast(context, '최대 인원을 올바르게 입력하세요.');
      return;
    }

    AppLogger.action(
      'SaveMeeting',
      detail:
          'title=$title, meetingDate=${_meetingDate.toIso8601String()}, maxParticipants=$maxParticipants',
    );
    debugPrint(
      '[MeetingCreateScreen] saveMeeting '
      'title=$title meetingDate=${_meetingDate.toIso8601String()} '
      'maxParticipants=$maxParticipants',
    );

    setState(() => _loading = true);

    try {
      final bookId = await _ensureBookId();

      await _meetingsService.createMeeting(
        hostId: uid,
        bookId: bookId,
        title: title,
        meetingDate: _meetingDate,
        location: _location.text.trim(),
        maxParticipants: maxParticipants,
        hostReason: _meetingDescription.text.trim(),
      );

      final items = await _meetingsService.loadMeetings();
      MeetingModel? created;

      for (final item in items) {
        if (item.hostId == uid &&
            item.bookId == bookId &&
            item.title == title) {
          created = item;
          break;
        }
      }

      AppLogger.action(
        'SaveMeetingSuccess',
        detail: 'bookId=$bookId, title=$title',
      );
      debugPrint(
        '[MeetingCreateScreen] saveMeeting success bookId=$bookId title=$title',
      );

      if (!mounted) return;
      showToast(context, '모임이 개설되었습니다.');

      if (created != null) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MeetingDetailScreen(meeting: created!),
          ),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e, st) {
      AppLogger.apiError('saveMeeting', e, stackTrace: st);
      debugPrint('[MeetingCreateScreen] saveMeeting error: $e');
      if (!mounted) return;
      showToast(context, '모임 개설 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _meetingTitle.dispose();
    _location.dispose();
    _maxParticipants.dispose();
    _meetingDescription.dispose();
    super.dispose();
  }

  Widget _buildBookInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((widget.book.coverUrl ?? '').trim().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                widget.book.coverUrl!,
                width: 72,
                height: 104,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 72,
                  height: 104,
                  color: Colors.grey.shade300,
                  alignment: Alignment.center,
                  child: const Icon(Icons.menu_book),
                ),
              ),
            )
          else
            Container(
              width: 72,
              height: 104,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.menu_book),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '선택된 책',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.book.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  (widget.book.author ?? '').trim().isEmpty
                      ? '저자 정보 없음'
                      : widget.book.author!,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (widget.book.isbn.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'ISBN: ${widget.book.isbn}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('모임 만들기'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          _buildBookInfoCard(),
          const SizedBox(height: 24),
          TextField(
            controller: _meetingTitle,
            decoration: const InputDecoration(
              labelText: '모임 제목',
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _location,
            decoration: const InputDecoration(
              labelText: '장소',
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _maxParticipants,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '최대 인원',
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: _pickMeetingDateTime,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '모임 일시',
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(
                _formatMeetingDateTime(_meetingDate),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _meetingDescription,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '모임 설명',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _loading ? null : _saveMeeting,
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('모임 개설하기'),
            ),
          ),
        ],
      ),
    );
  }
}