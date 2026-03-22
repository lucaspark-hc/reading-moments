import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/log/app_logger.dart';
import 'package:reading_moments_app/core/log/logged_state_mixin.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/book_model.dart';
import 'package:reading_moments_app/models/book_selection_item.dart';
import 'package:reading_moments_app/models/my_book_record_group_item.dart';
import 'package:reading_moments_app/models/wishlist_book_item.dart';
import 'package:reading_moments_app/screens/meetings/create_meeting_screen.dart';
import 'package:reading_moments_app/screens/records/book_records_screen.dart';
import 'package:reading_moments_app/screens/selections/book_selection_detail_screen.dart';
import 'package:reading_moments_app/services/book_selections_service.dart';
import 'package:reading_moments_app/services/library_service.dart';
import 'package:reading_moments_app/services/my_records_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';
import 'package:reading_moments_app/widgets/current_user_banner.dart';

enum LibraryTabType { wishlist, reading, done }

class MyLibraryScreen extends StatefulWidget {
  final LibraryTabType initialTab;
  final int? targetBookId;

  const MyLibraryScreen({
    super.key,
    this.initialTab = LibraryTabType.wishlist,
    this.targetBookId,
  });

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen>
    with LoggedStateMixin<MyLibraryScreen> {
  final LibraryService _libraryService = LibraryService();
  final BookSelectionsService _bookSelectionsService = BookSelectionsService();
  final MyRecordsService _myRecordsService = MyRecordsService();

  bool _loading = true;
  bool _openingBookPicker = false;
  late LibraryTabType _tab;

  List<WishlistBookItem> _wishlistBooks = [];
  List<BookSelectionItem> _selections = [];
  List<MyBookRecordGroupItem> _recordGroups = [];
  Map<int, LibraryBookStatus> _selectionStatuses = <int, LibraryBookStatus>{};

  final Map<int, GlobalKey> _bookCardKeys = <int, GlobalKey>{};
  final Set<int> _processingMeetingBookIds = <int>{};
  final Set<int> _processingDoneBookIds = <int>{};
  final Set<int> _processingRestartBookIds = <int>{};

  int? _highlightBookId;
  bool _initialTargetHandled = false;
  int _autoScrollRetryCount = 0;
  static const int _maxAutoScrollRetry = 8;

  @override
  String get screenName => 'MyLibraryScreen';

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _highlightBookId = widget.targetBookId;
    _loadLibraryData();
  }

  GlobalKey _keyForBook(int bookId) {
    return _bookCardKeys.putIfAbsent(bookId, () => GlobalKey());
  }

  Future<void> _loadLibraryData() async {
    setState(() => _loading = true);

    final uid = supabase.auth.currentUser?.id;
    AppLogger.apiStart(
      'loadLibraryData',
      detail:
          'userId=${uid ?? 'null'}, tab=${_tab.name}, targetBookId=${widget.targetBookId}',
    );
    print(
      '📚 loadLibraryData START | userId=${uid ?? 'null'} | tab=${_tab.name} | targetBookId=${widget.targetBookId}',
    );

    try {
      if (uid == null) {
        if (!mounted) return;
        showToast(context, '로그인이 필요합니다.');
        return;
      }

      final wishlist = await _libraryService.loadWishlistBooks();
      final selections = await _bookSelectionsService.loadMySelections();
      final recordGroups = await _myRecordsService.loadMyBookRecordGroups();
      final selectionStatuses = await _libraryService.loadSelectionStatuses();

      if (!mounted) return;

      setState(() {
        _wishlistBooks = wishlist;
        _selections = selections;
        _recordGroups = recordGroups;
        _selectionStatuses = selectionStatuses;
      });

      AppLogger.apiSuccess(
        'loadLibraryData',
        detail:
            'wishlist=${_wishlistBooks.length}, selections=${_selections.length}, records=${_recordGroups.length}, statuses=${_selectionStatuses.length}',
      );
      print(
        '✅ loadLibraryData SUCCESS | wishlist=${_wishlistBooks.length} | selections=${_selections.length} | records=${_recordGroups.length} | statuses=${_selectionStatuses.length}',
      );

      _autoScrollRetryCount = 0;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTargetBookIfNeeded();
      });
    } catch (e, st) {
      AppLogger.apiError('loadLibraryData', e, stackTrace: st);
      print('❌ loadLibraryData FAIL | $e');
      if (!mounted) return;
      showToast(context, '내 라이브러리 조회 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
      print('🏁 loadLibraryData END');
    }
  }

  void _retryScrollToTargetBook() {
    if (!mounted) return;
    if (_highlightBookId == null && widget.targetBookId == null) return;
    if (_autoScrollRetryCount >= _maxAutoScrollRetry) {
      final targetBookId = _highlightBookId ?? widget.targetBookId;
      AppLogger.warn(
        'Library_AutoScroll_RetryExhausted | targetBookId=$targetBookId, tab=${_tab.name}',
      );
      print(
        '⛔ Library_AutoScroll_RetryExhausted | targetBookId=$targetBookId | tab=${_tab.name}',
      );
      _initialTargetHandled = true;
      return;
    }

    _autoScrollRetryCount += 1;
    final targetBookId = _highlightBookId ?? widget.targetBookId;

    AppLogger.info(
      'Library_AutoScroll_Retry | retry=$_autoScrollRetryCount, targetBookId=$targetBookId, tab=${_tab.name}',
    );
    print(
      '🔁 Library_AutoScroll_Retry | retry=$_autoScrollRetryCount | targetBookId=$targetBookId | tab=${_tab.name}',
    );

    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTargetBookIfNeeded();
      });
    });
  }

  void _startHighlight(int bookId) {
    AppLogger.action(
      'Library_Highlight_Start',
      detail: 'targetBookId=$bookId, tab=${_tab.name}',
    );
    print('✨ Library_Highlight_Start | targetBookId=$bookId | tab=${_tab.name}');

    setState(() {
      _highlightBookId = bookId;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_highlightBookId != bookId) return;

      AppLogger.action(
        'Library_Highlight_Clear',
        detail: 'targetBookId=$bookId',
      );
      print('✨ Library_Highlight_Clear | targetBookId=$bookId');

      setState(() {
        _highlightBookId = null;
      });
    });
  }

  void _scrollToTargetBookIfNeeded() {
    if (!mounted) return;
    if (_initialTargetHandled) return;

    final targetBookId = _highlightBookId ?? widget.targetBookId;
    if (targetBookId == null) return;

    final items = _filteredItems();
    final exists = items.any((e) => e.bookId == targetBookId);

    AppLogger.info(
      'Library_AutoScroll_Check | tab=${_tab.name}, targetBookId=$targetBookId, exists=$exists, retry=$_autoScrollRetryCount',
    );
    print(
      '🔎 Library_AutoScroll_Check | tab=${_tab.name} | targetBookId=$targetBookId | exists=$exists | retry=$_autoScrollRetryCount',
    );

    if (!exists) {
      _retryScrollToTargetBook();
      return;
    }

    final key = _keyForBook(targetBookId);
    final ctx = key.currentContext;

    if (ctx == null) {
      AppLogger.warn(
        'Library_AutoScroll_ContextMissing | targetBookId=$targetBookId, retry=$_autoScrollRetryCount',
      );
      print(
        '⚠️ Library_AutoScroll_ContextMissing | targetBookId=$targetBookId | retry=$_autoScrollRetryCount',
      );
      _retryScrollToTargetBook();
      return;
    }

    _initialTargetHandled = true;

    AppLogger.action(
      'Library_AutoScroll_Start',
      detail: 'targetBookId=$targetBookId, tab=${_tab.name}',
    );
    print(
      '➡️ Library_AutoScroll_Start | targetBookId=$targetBookId | tab=${_tab.name}',
    );

    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.08,
    );

    _startHighlight(targetBookId);

    AppLogger.action(
      'Library_AutoScroll_HighlightComplete',
      detail: 'targetBookId=$targetBookId, tab=${_tab.name}',
    );
    print(
      '✅ Library_AutoScroll_HighlightComplete | targetBookId=$targetBookId | tab=${_tab.name}',
    );
  }

  List<_LibraryBookItem> _buildLibraryItems() {
    final Map<int, _LibraryBookItem> map = {};

    for (final book in _wishlistBooks) {
      map[book.bookId] = _LibraryBookItem(
        bookId: book.bookId,
        title: book.title,
        author: book.author,
        coverUrl: book.coverUrl,
        isbn: book.isbn,
        wishlistItem: book,
        selectionItem: null,
        recordGroup: null,
        status: LibraryBookStatus.wishlist,
        latestAt: book.createdAt,
      );
    }

    for (final selection in _selections) {
      final existing = map[selection.bookId];
      final selectionAt = selection.createdAt;
      final selectionStatus =
          _selectionStatuses[selection.bookId] ?? LibraryBookStatus.selected;

      if (existing == null) {
        map[selection.bookId] = _LibraryBookItem(
          bookId: selection.bookId,
          title: selection.bookTitle,
          author: selection.bookAuthor,
          coverUrl: selection.coverUrl,
          isbn: selection.isbn,
          wishlistItem: null,
          selectionItem: selection,
          recordGroup: null,
          status: selectionStatus,
          latestAt: selectionAt,
        );
      } else {
        map[selection.bookId] = existing.copyWith(
          selectionItem: selection,
          status: selectionStatus,
          latestAt: selectionAt.isAfter(existing.latestAt)
              ? selectionAt
              : existing.latestAt,
        );
      }
    }

    for (final group in _recordGroups) {
      final existing = map[group.bookId];
      final recordAt = group.latestCreatedAt;

      if (existing == null) {
        map[group.bookId] = _LibraryBookItem(
          bookId: group.bookId,
          title: group.bookTitle,
          author: group.bookAuthor,
          coverUrl: group.coverUrl,
          isbn: null,
          wishlistItem: null,
          selectionItem: null,
          recordGroup: group,
          status: LibraryBookStatus.reading,
          latestAt: recordAt,
        );
      } else {
        final nextStatus = existing.status == LibraryBookStatus.done
            ? LibraryBookStatus.done
            : existing.status == LibraryBookStatus.selected
                ? LibraryBookStatus.reading
                : existing.status == LibraryBookStatus.wishlist
                    ? LibraryBookStatus.reading
                    : existing.status;
        map[group.bookId] = existing.copyWith(
          recordGroup: group,
          status: nextStatus,
          latestAt:
              recordAt.isAfter(existing.latestAt) ? recordAt : existing.latestAt,
        );
      }
    }

    final items = map.values.toList();

    items.sort((a, b) {
      final aRank = _sortRank(a);
      final bRank = _sortRank(b);

      if (aRank != bRank) {
        return aRank.compareTo(bRank);
      }

      return b.latestAt.compareTo(a.latestAt);
    });

    return items;
  }

  int _sortRank(_LibraryBookItem item) {
    switch (item.status) {
      case LibraryBookStatus.reading:
      case LibraryBookStatus.selected:
        return 0;
      case LibraryBookStatus.done:
        return 1;
      case LibraryBookStatus.wishlist:
        return 2;
      case LibraryBookStatus.none:
        return 3;
    }
  }

  LibraryTabType _resolveStatus(_LibraryBookItem item) {
    switch (item.status) {
      case LibraryBookStatus.done:
        return LibraryTabType.done;
      case LibraryBookStatus.reading:
      case LibraryBookStatus.selected:
        return LibraryTabType.reading;
      case LibraryBookStatus.wishlist:
      case LibraryBookStatus.none:
        return LibraryTabType.wishlist;
    }
  }

  List<_LibraryBookItem> _filteredItems() {
    final all = _buildLibraryItems();
    return all.where((e) => _resolveStatus(e) == _tab).toList();
  }

  Future<void> _removeWishlistBook(WishlistBookItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('읽고 싶은 책 제거'),
          content: Text('"${item.title}" 을(를) 읽고 싶은 책에서 제거하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('제거'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    AppLogger.action(
      'RemoveWishlistBook',
      detail: 'bookId=${item.bookId}, title=${item.title}',
    );
    print(
      '🗑️ RemoveWishlistBook | bookId=${item.bookId} | title=${item.title}',
    );

    try {
      await _libraryService.removeWishlistBook(item.bookId);

      if (!mounted) return;

      showToast(context, '읽고 싶은 책에서 제거되었습니다.');
      await _loadLibraryData();
    } catch (e, st) {
      AppLogger.apiError('removeWishlistBook', e, stackTrace: st);
      print('❌ removeWishlistBook FAIL | $e');
      if (!mounted) return;
      showToast(context, '제거 실패: $e');
    }
  }

  Future<void> _markBookAsDone(_LibraryBookItem item) async {
    if (_processingDoneBookIds.contains(item.bookId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('독서 완료'),
          content: Text('"${item.title}" 을(를) 완료한 책으로 전환하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('완료'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    AppLogger.action(
      'MarkBookAsDoneFromLibrary',
      detail: 'bookId=${item.bookId}, title=${item.title}',
    );
    print('🏁 MarkBookAsDoneFromLibrary | bookId=${item.bookId} | title=${item.title}');

    setState(() {
      _processingDoneBookIds.add(item.bookId);
    });

    try {
      await _libraryService.markBookAsDone(item.bookId);

      if (!mounted) return;

      showToast(context, '독서 완료 처리되었습니다.');

      setState(() {
        _initialTargetHandled = true;
        if (_highlightBookId == item.bookId) {
          _highlightBookId = null;
        }
      });

      await _loadLibraryData();
    } catch (e, st) {
      AppLogger.apiError('markBookAsDone(from library)', e, stackTrace: st);
      print('❌ MarkBookAsDoneFromLibrary FAIL | $e');
      if (!mounted) return;
      showToast(context, '독서 완료 처리 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _processingDoneBookIds.remove(item.bookId);
        });
      }
    }
  }

  Future<void> _restartReading(_LibraryBookItem item) async {
    if (_processingRestartBookIds.contains(item.bookId)) return;

    AppLogger.action(
      'RestartReadingFromDone',
      detail: 'bookId=${item.bookId}, title=${item.title}',
    );
    print('🔄 RestartReadingFromDone | bookId=${item.bookId} | title=${item.title}');

    setState(() {
      _processingRestartBookIds.add(item.bookId);
    });

    try {
      await _libraryService.markBookAsReading(item.bookId);

      if (!mounted) return;

      showToast(context, '독서를 다시 시작합니다.');

      setState(() {
        _tab = LibraryTabType.reading;
        _initialTargetHandled = false;
        _autoScrollRetryCount = 0;
        _highlightBookId = item.bookId;
      });

      await _loadLibraryData();
    } catch (e, st) {
      AppLogger.apiError('restartReading(from done)', e, stackTrace: st);
      print('❌ RestartReadingFromDone FAIL | $e');
      if (!mounted) return;
      showToast(context, '다시 읽기 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _processingRestartBookIds.remove(item.bookId);
        });
      }
    }
  }

  Future<void> _openWishlistBook(WishlistBookItem item) async {
    AppLogger.action(
      'OpenWishlistBookToSelection',
      detail: 'bookId=${item.bookId}, title=${item.title}',
    );
    print(
      '📘 OpenWishlistBookToSelection | bookId=${item.bookId} | title=${item.title}',
    );

    final book = BookModel(
      id: item.bookId,
      isbn: item.isbn ?? '',
      title: item.title,
      author: item.author,
      coverUrl: item.coverUrl,
      category: null,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateMeetingScreen(initialBook: book),
      ),
    );

    await _loadLibraryData();
  }

  Future<void> _openLibraryItem(_LibraryBookItem item) async {
    AppLogger.action(
      'OpenLibraryItem',
      detail:
          'bookId=${item.bookId}, title=${item.title}, tab=${_tab.name}, status=${item.status.name}',
    );
    print(
      '📂 OpenLibraryItem | bookId=${item.bookId} | title=${item.title} | tab=${_tab.name} | status=${item.status.name}',
    );

    if (_resolveStatus(item) == LibraryTabType.reading) {
      await _openContinueReading(item);
      return;
    }

    if (_resolveStatus(item) == LibraryTabType.done) {
      await _openContinueReading(item);
      return;
    }

    if (item.selectionItem != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              BookSelectionDetailScreen(selection: item.selectionItem!),
        ),
      );
      await _loadLibraryData();
      return;
    }

    if (item.wishlistItem != null) {
      await _openWishlistBook(item.wishlistItem!);
    }
  }

  Future<void> _openContinueReading(_LibraryBookItem item) async {
    AppLogger.action(
      'ContinueReadingFromLibrary',
      detail: 'bookId=${item.bookId}, title=${item.title}',
    );
    print(
      '📖 ContinueReadingFromLibrary | bookId=${item.bookId} | title=${item.title}',
    );

    MyBookRecordGroupItem? group = item.recordGroup;

    if (group == null) {
      final groups = await _myRecordsService.loadMyBookRecordGroups();
      final matched = groups.where((e) => e.bookId == item.bookId).toList();
      if (matched.isNotEmpty) {
        group = matched.first;
      }
    }

    if (group == null) {
      group = MyBookRecordGroupItem(
        bookId: item.bookId,
        bookTitle: item.title,
        bookAuthor: item.author,
        coverUrl: item.coverUrl,
        totalCount: 0,
        publicCount: 0,
        privateCount: 0,
        latestCreatedAt: item.latestAt,
      );
    }

    if (!mounted) return;

    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => BookRecordsScreen(group: group!),
      ),
    );

    if (!mounted) return;

    if (result is Map<String, dynamic> &&
        result['action'] == 'mark_done' &&
        result['bookId'] is int) {
      final bookId = result['bookId'] as int;

      AppLogger.action(
        'HandleMarkDoneResultFromRecords',
        detail: 'bookId=$bookId',
      );
      print('🏁 HandleMarkDoneResultFromRecords | bookId=$bookId');

      setState(() {
        _initialTargetHandled = true;
        if (_highlightBookId == bookId) {
          _highlightBookId = null;
        }
      });
    }

    await _loadLibraryData();
  }

  Future<void> _openCreateMeeting(_LibraryBookItem item) async {
    if (_processingMeetingBookIds.contains(item.bookId)) return;

    AppLogger.action(
      'CreateMeetingFromReadingLibrary',
      detail: 'bookId=${item.bookId}, title=${item.title}',
    );
    print(
      '👥 CreateMeetingFromReadingLibrary | bookId=${item.bookId} | title=${item.title}',
    );

    setState(() {
      _processingMeetingBookIds.add(item.bookId);
    });

    try {
      final book = BookModel(
        id: item.bookId,
        isbn: item.isbn ?? '',
        title: item.title,
        author: item.author,
        coverUrl: item.coverUrl,
        category: null,
      );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateMeetingScreen(
            initialBook: book,
            startInMeetingMode: true,
          ),
        ),
      );

      await _loadLibraryData();
    } finally {
      if (mounted) {
        setState(() {
          _processingMeetingBookIds.remove(item.bookId);
        });
      }
      print(
        '🏁 CreateMeetingFromReadingLibrary END | bookId=${item.bookId}',
      );
    }
  }

  Future<void> _openBookPickerFromFab() async {
    if (_openingBookPicker) return;

    AppLogger.action(
      'OpenBookPickerFromLibraryFab',
      detail: 'tab=${_tab.name}',
    );
    print('➕ OpenBookPickerFromLibraryFab | tab=${_tab.name}');

    setState(() {
      _openingBookPicker = true;
    });

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CreateMeetingScreen(),
        ),
      );

      await _loadLibraryData();
    } finally {
      if (mounted) {
        setState(() {
          _openingBookPicker = false;
        });
      }
      print('🏁 OpenBookPickerFromLibraryFab END');
    }
  }

  Widget _buildTabSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: Theme(
        data: Theme.of(context).copyWith(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        ),
        child: SegmentedButton<LibraryTabType>(
          showSelectedIcon: true,
          style: ButtonStyle(
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            minimumSize: WidgetStateProperty.all(
              const Size(0, 40),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          ),
          segments: const [
            ButtonSegment<LibraryTabType>(
              value: LibraryTabType.wishlist,
              label: Text('읽고 싶은 책'),
              icon: Icon(Icons.bookmark_added_outlined, size: 18),
            ),
            ButtonSegment<LibraryTabType>(
              value: LibraryTabType.reading,
              label: Text('독서중'),
              icon: Icon(Icons.menu_book_outlined, size: 18),
            ),
            ButtonSegment<LibraryTabType>(
              value: LibraryTabType.done,
              label: Text('완료'),
              icon: Icon(Icons.inventory_2_outlined, size: 18),
            ),
          ],
          selected: {_tab},
          onSelectionChanged: (selected) {
            final next = selected.first;
            AppLogger.action(
              'ChangeLibraryTab',
              detail: 'from=${_tab.name}, to=${next.name}',
            );
            print('🔁 ChangeLibraryTab | from=${_tab.name} | to=${next.name}');
            setState(() {
              _tab = next;
              _initialTargetHandled = false;
              _autoScrollRetryCount = 0;
            });

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToTargetBookIfNeeded();
            });
          },
        ),
      ),
    );
  }

  Widget _buildReadingActionButtons(_LibraryBookItem item) {
    final processingMeeting = _processingMeetingBookIds.contains(item.bookId);

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: FilledButton(
              onPressed: () => _openContinueReading(item),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity:
                    const VisualDensity(horizontal: -1, vertical: -1),
              ),
              child: const Text('이어읽기'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed:
                  processingMeeting ? null : () => _openCreateMeeting(item),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity:
                    const VisualDensity(horizontal: -1, vertical: -1),
              ),
              child: processingMeeting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('모임 만들기'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDoneActionButtons(_LibraryBookItem item) {
    final processingRestart = _processingRestartBookIds.contains(item.bookId);

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: FilledButton(
              onPressed: () => _openContinueReading(item),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity:
                    const VisualDensity(horizontal: -1, vertical: -1),
              ),
              child: const Text('기록 보기'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: processingRestart ? null : () => _restartReading(item),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity:
                    const VisualDensity(horizontal: -1, vertical: -1),
              ),
              child: processingRestart
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('다시 읽기'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrailingMenu(_LibraryBookItem item) {
    if (_tab == LibraryTabType.wishlist && item.wishlistItem != null) {
      return PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36),
        onSelected: (value) async {
          if (value == 'remove') {
            await _removeWishlistBook(item.wishlistItem!);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem<String>(
            value: 'remove',
            child: Text('제거'),
          ),
        ],
      );
    }

    if (_tab == LibraryTabType.reading) {
      final processingDone = _processingDoneBookIds.contains(item.bookId);

      return PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36),
        enabled: !processingDone,
        onSelected: (value) async {
          if (value == 'done') {
            await _markBookAsDone(item);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem<String>(
            value: 'done',
            child: Text('독서 완료'),
          ),
        ],
        child: processingDone
            ? const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.more_vert, size: 20),
              ),
      );
    }

    if (_tab == LibraryTabType.done) {
      return const SizedBox.shrink();
    }

    return const Padding(
      padding: EdgeInsets.only(top: 2),
      child: Icon(Icons.chevron_right, size: 20),
    );
  }

  Widget _buildBookCard(_LibraryBookItem item) {
    final hasAuthor = (item.author ?? '').trim().isNotEmpty;
    final hasIsbn = (item.isbn ?? '').trim().isNotEmpty;
    final isReading = _resolveStatus(item) == LibraryTabType.reading;
    final isDone = _resolveStatus(item) == LibraryTabType.done;
    final isHighlighted = _highlightBookId == item.bookId;

    return AnimatedContainer(
      key: _keyForBook(item.bookId),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.amber.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? Colors.amber.shade300 : Colors.transparent,
          width: isHighlighted ? 1.4 : 1,
        ),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: isHighlighted ? 1.5 : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await _openLibraryItem(item);
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((item.coverUrl ?? '').trim().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.coverUrl!,
                      width: 64,
                      height: 92,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 64,
                        height: 92,
                        color: Colors.grey.shade300,
                        alignment: Alignment.center,
                        child: const Text(
                          '표지\n없음',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 64,
                    height: 92,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '표지\n없음',
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      if (hasAuthor) ...[
                        const SizedBox(height: 4),
                        Text(
                          '저자: ${item.author!}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (hasIsbn)
                        Text(
                          'ISBN: ${item.isbn!}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 6),
                      if (item.recordGroup != null) ...[
                        Text('내 기록 ${item.recordGroup!.totalCount}개'),
                        Text(
                          '공개 ${item.recordGroup!.publicCount}개 · 비공개 ${item.recordGroup!.privateCount}개',
                        ),
                      ] else if (item.selectionItem != null) ...[
                        Text(
                          item.status == LibraryBookStatus.done
                              ? '완료한 책입니다'
                              : '독서를 시작한 책입니다 · ${item.selectionItem!.visibility == 'public' ? '공개' : '비공개'}',
                        ),
                      ] else ...[
                        Text(
                          '추가일: ${formatDateTime(item.latestAt)}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (isReading) ...[
                        const Text(
                          '읽기 / 기록 / 모임으로 이어가세요.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildReadingActionButtons(item),
                      ] else if (isDone) ...[
                        const Text(
                          '기록을 돌아보거나 다시 읽기를 시작하세요.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildDoneActionButtons(item),
                      ] else ...[
                        const Text(
                          '탭하여 읽을 책 고르기로 이동',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildTrailingMenu(item),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWishlistView(List<_LibraryBookItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text('읽고 싶은 책이 없습니다. 생각의 흐름에서 책을 추가해 보세요.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLibraryData,
      child: ListView(
        padding: const EdgeInsets.only(top: 2, bottom: 24),
        children: [
          ...items.map(_buildBookCard),
        ],
      ),
    );
  }

  Widget _buildReadingView(List<_LibraryBookItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text('독서중인 책이 없습니다. 책 선정 또는 기록을 시작해 보세요.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLibraryData,
      child: ListView(
        padding: const EdgeInsets.only(top: 2, bottom: 24),
        children: [
          ...items.map(_buildBookCard),
        ],
      ),
    );
  }

  Widget _buildDoneView(List<_LibraryBookItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text('완료된 책이 없습니다.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLibraryData,
      child: ListView(
        padding: const EdgeInsets.only(top: 2, bottom: 24),
        children: [
          ...items.map(_buildBookCard),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _filteredItems();

    switch (_tab) {
      case LibraryTabType.wishlist:
        return _buildWishlistView(items);
      case LibraryTabType.reading:
        return _buildReadingView(items);
      case LibraryTabType.done:
        return _buildDoneView(items);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const CurrentUserBanner(),
          _buildTabSection(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openingBookPicker ? null : _openBookPickerFromFab,
        icon: _openingBookPicker
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add),
        label: const Text('책고르기'),
      ),
    );
  }
}

class _LibraryBookItem {
  final int bookId;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? isbn;
  final WishlistBookItem? wishlistItem;
  final BookSelectionItem? selectionItem;
  final MyBookRecordGroupItem? recordGroup;
  final LibraryBookStatus status;
  final DateTime latestAt;

  const _LibraryBookItem({
    required this.bookId,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.isbn,
    required this.wishlistItem,
    required this.selectionItem,
    required this.recordGroup,
    required this.status,
    required this.latestAt,
  });

  _LibraryBookItem copyWith({
    WishlistBookItem? wishlistItem,
    BookSelectionItem? selectionItem,
    MyBookRecordGroupItem? recordGroup,
    LibraryBookStatus? status,
    DateTime? latestAt,
  }) {
    return _LibraryBookItem(
      bookId: bookId,
      title: title,
      author: author,
      coverUrl: coverUrl,
      isbn: isbn,
      wishlistItem: wishlistItem ?? this.wishlistItem,
      selectionItem: selectionItem ?? this.selectionItem,
      recordGroup: recordGroup ?? this.recordGroup,
      status: status ?? this.status,
      latestAt: latestAt ?? this.latestAt,
    );
  }
}