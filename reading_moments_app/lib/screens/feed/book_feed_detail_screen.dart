import 'package:flutter/material.dart';

import '../../core/log/app_logger.dart';
import '../../core/log/logged_state_mixin.dart';
import '../../models/book_feed_summary_item.dart';
import '../../models/book_selection_item.dart';
import '../../models/feed_note_item.dart';
import '../../models/my_book_record_group_item.dart';
import '../../models/public_book_selection_item.dart';
import '../../models/wishlist_book_item.dart';
import '../../screens/library/my_library_screen.dart';
import '../../screens/records/book_records_screen.dart';
import '../../screens/selections/book_selection_detail_screen.dart';
import '../../services/book_selections_service.dart';
import '../../services/feed_service.dart';
import '../../services/library_service.dart';
import '../../services/my_records_service.dart';
import '../../utils/app_utils.dart';
import 'feed_note_detail_screen.dart';

enum _LibraryBookStatus { none, wishlist, selected, reading, done }

class BookFeedDetailScreen extends StatefulWidget {
  final BookFeedSummaryItem summary;

  const BookFeedDetailScreen({
    super.key,
    required this.summary,
  });

  @override
  State<BookFeedDetailScreen> createState() => _BookFeedDetailScreenState();
}

class _BookFeedDetailScreenState extends State<BookFeedDetailScreen>
    with LoggedStateMixin<BookFeedDetailScreen> {
  final FeedService _feedService = FeedService();
  final LibraryService _libraryService = LibraryService();
  final BookSelectionsService _bookSelectionsService = BookSelectionsService();
  final MyRecordsService _myRecordsService = MyRecordsService();

  bool _loading = true;
  bool _savingBook = false;
  bool _processingLike = false;
  bool _isWishlisted = false;

  List<PublicBookSelectionItem> _selectionItems = [];
  List<FeedNoteItem> _noteItems = [];

  @override
  String get screenName => 'BookFeedDetailScreen';

  @override
  void initState() {
    super.initState();
    _isWishlisted = widget.summary.isWishlisted;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    AppLogger.apiStart(
      'loadBookFeedDetail',
      detail: 'bookId=${widget.summary.bookId}, title=${widget.summary.bookTitle}',
    );

    try {
      final results = await Future.wait([
        _feedService.loadPublicSelectionsByBook(widget.summary.bookId),
        _feedService.loadPublicFeedByBook(widget.summary.bookId),
      ]);

      if (!mounted) return;

      setState(() {
        _selectionItems = results[0] as List<PublicBookSelectionItem>;
        _noteItems = results[1] as List<FeedNoteItem>;
      });

      AppLogger.apiSuccess(
        'loadBookFeedDetail',
        detail:
            'selectionCount=${_selectionItems.length}, momentCount=${_noteItems.length}',
      );
    } catch (e, st) {
      AppLogger.apiError('loadBookFeedDetail', e, stackTrace: st);
      if (!mounted) return;
      showToast(context, '책 피드 조회 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openMyLibrary() async {
    AppLogger.action(
      'OpenMyLibraryFromBookFeedDetail',
      detail: 'bookId=${widget.summary.bookId}, title=${widget.summary.bookTitle}',
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const _MyLibraryPage(),
      ),
    );
  }

  Future<void> _openLatestSelection() async {
    AppLogger.action(
      'OpenLatestSelectionFromBookFeedDetail',
      detail: 'bookId=${widget.summary.bookId}, title=${widget.summary.bookTitle}',
    );

    final selections = await _bookSelectionsService.loadMySelections();
    if (!mounted) return;

    final matched = selections
        .where((e) => e.bookId == widget.summary.bookId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (matched.isEmpty) {
      showToast(context, '책 선정 기록을 찾지 못했습니다.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookSelectionDetailScreen(selection: matched.first),
      ),
    );
  }

  Future<void> _openBookRecords() async {
    AppLogger.action(
      'OpenBookRecordsFromBookFeedDetail',
      detail: 'bookId=${widget.summary.bookId}, title=${widget.summary.bookTitle}',
    );

    final groups = await _myRecordsService.loadMyBookRecordGroups();
    if (!mounted) return;

    final matched = groups.where((e) => e.bookId == widget.summary.bookId).toList();

    if (matched.isEmpty) {
      showToast(context, '내 기록을 찾지 못했습니다.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookRecordsScreen(group: matched.first),
      ),
    );
  }

  Future<WishlistBookItem?> _findWishlistBook() async {
    final wishlist = await _libraryService.loadWishlistBooks();
    for (final item in wishlist) {
      if (item.bookId == widget.summary.bookId) {
        return item;
      }
    }
    return null;
  }

  Future<BookSelectionItem?> _findLatestSelection() async {
    final selections = await _bookSelectionsService.loadMySelections();
    final matched = selections
        .where((e) => e.bookId == widget.summary.bookId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (matched.isEmpty) return null;
    return matched.first;
  }

  Future<MyBookRecordGroupItem?> _findRecordGroup() async {
    final groups = await _myRecordsService.loadMyBookRecordGroups();
    for (final group in groups) {
      if (group.bookId == widget.summary.bookId) {
        return group;
      }
    }
    return null;
  }

  Future<_LibraryBookStatus> _detectLibraryStatus() async {
    final recordGroup = await _findRecordGroup();
    if (recordGroup != null) {
      return _LibraryBookStatus.reading;
    }

    final selection = await _findLatestSelection();
    if (selection != null) {
      return _LibraryBookStatus.selected;
    }

    final wishlist = await _findWishlistBook();
    if (wishlist != null) {
      return _LibraryBookStatus.wishlist;
    }

    return _LibraryBookStatus.none;
  }

  Future<void> _handleWishlistSmartFlow() async {
    if (_savingBook) return;

    setState(() => _savingBook = true);

    AppLogger.action(
      'HandleWishlistSmartFlow',
      detail: 'bookId=${widget.summary.bookId}, title=${widget.summary.bookTitle}',
    );

    try {
      final status = await _detectLibraryStatus();

      if (!mounted) return;

      switch (status) {
        case _LibraryBookStatus.none:
          await _libraryService.addWishlistBook(widget.summary.bookId);

          if (!mounted) return;

          setState(() {
            _isWishlisted = true;
          });

          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('읽고 싶은 책에 추가되었습니다.'),
              action: SnackBarAction(
                label: '내 라이브러리',
                onPressed: _openMyLibrary,
              ),
            ),
          );
          break;

        case _LibraryBookStatus.wishlist:
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('이미 읽고 싶은 책에 있습니다.'),
              action: SnackBarAction(
                label: '내 라이브러리',
                onPressed: _openMyLibrary,
              ),
            ),
          );
          break;

        case _LibraryBookStatus.selected:
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('이미 책 선정이 완료된 책입니다.'),
              action: SnackBarAction(
                label: '책 선정 보기',
                onPressed: _openLatestSelection,
              ),
            ),
          );
          break;

        case _LibraryBookStatus.reading:
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('이미 독서중인 책입니다.'),
              action: SnackBarAction(
                label: '내 기록 보기',
                onPressed: _openBookRecords,
              ),
            ),
          );
          break;

        case _LibraryBookStatus.done:
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('완료된 책입니다.'),
              action: SnackBarAction(
                label: '내 라이브러리',
                onPressed: _openMyLibrary,
              ),
            ),
          );
          break;
      }
    } catch (e, st) {
      AppLogger.apiError(
        'handleWishlistSmartFlow',
        e,
        stackTrace: st,
      );
      if (!mounted) return;
      showToast(context, '처리 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _savingBook = false);
      }
    }
  }

  Future<void> _toggleLike(FeedNoteItem item) async {
    if (_processingLike) return;

    setState(() => _processingLike = true);

    AppLogger.action(
      'ToggleMomentLikeFromBookFeedDetail',
      detail: 'momentId=${item.id}, current=${item.isLiked}',
    );

    try {
      if (item.isLiked) {
        await _feedService.unlikeNote(item.id);
        if (!mounted) return;

        setState(() {
          _noteItems = _noteItems.map((e) {
            if (e.id != item.id) return e;
            return e.copyWith(
              isLiked: false,
              likeCount: e.likeCount > 0 ? e.likeCount - 1 : 0,
            );
          }).toList();
        });
      } else {
        await _feedService.likeNote(item.id);
        if (!mounted) return;

        setState(() {
          _noteItems = _noteItems.map((e) {
            if (e.id != item.id) return e;
            return e.copyWith(
              isLiked: true,
              likeCount: e.likeCount + 1,
            );
          }).toList();
        });
      }
    } catch (e, st) {
      AppLogger.apiError(
        'toggleMomentLikeFromBookFeedDetail',
        e,
        stackTrace: st,
      );
      if (!mounted) return;
      showToast(context, '공감 처리 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _processingLike = false);
      }
    }
  }

  Widget _buildSelectionCard(PublicBookSelectionItem item) {
    final hasDescription = (item.bookDescription ?? '').trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(label: Text(item.nickname)),
                const Spacer(),
                Text(
                  item.createdAt.toLocal().toString().substring(0, 16),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.selectionReason,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
              ),
            ),
            if (hasDescription) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.bookDescription!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(FeedNoteItem item) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          AppLogger.action(
            'OpenFeedMomentDetail',
            detail: 'momentId=${item.id}, bookId=${widget.summary.bookId}',
          );

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FeedNoteDetailScreen(item: item),
            ),
          );

          await _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Chip(label: Text('문장')),
                  const SizedBox(width: 8),
                  if (item.page != null) Text('p.${item.page}'),
                  const Spacer(),
                  Text(
                    item.nickname,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if ((item.quoteText ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '“${item.quoteText!}”',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if ((item.noteText ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  item.noteText!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  InkWell(
                    onTap: () => _toggleLike(item),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: item.isLiked ? Colors.red : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text('${item.likeCount}'),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.createdAt.toLocal().toString().substring(0, 16),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final hasAuthor = (summary.bookAuthor ?? '').trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('책 피드'),
        actions: [
          IconButton(
            onPressed: _openMyLibrary,
            icon: const Icon(Icons.library_books_outlined),
            tooltip: '내 라이브러리',
          ),
          IconButton(
            onPressed: _savingBook ? null : _handleWishlistSmartFlow,
            icon: _savingBook
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isWishlisted ? Icons.bookmark : Icons.bookmark_add_outlined,
                  ),
            tooltip: '읽고 싶은 책',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((summary.coverUrl ?? '').trim().isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          summary.coverUrl!,
                          width: 80,
                          height: 112,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 112,
                            color: Colors.grey.shade300,
                            alignment: Alignment.center,
                            child: const Text('표지 없음'),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 80,
                        height: 112,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: const Text('표지 없음'),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.bookTitle,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (hasAuthor) ...[
                            const SizedBox(height: 6),
                            Text(
                              summary.bookAuthor!,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text('공개 책 선정 ${summary.publicSelectionCount}개'),
                          Text('공개 기록 ${summary.publicNoteCount}개'),
                          Text(
                            '최근 활동: ${summary.latestCreatedAt.toLocal().toString().substring(0, 16)}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '이 책을 고른 이유',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_selectionItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('이 책의 공개 책 선정 기록이 없습니다.'),
              )
            else
              ..._selectionItems.map(_buildSelectionCard),
            const SizedBox(height: 24),
            const Text(
              '이 책의 공개 기록',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const SizedBox()
            else if (_noteItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('이 책의 공개 문장 기록이 없습니다.'),
              )
            else
              ..._noteItems.map(_buildNoteCard),
          ],
        ),
      ),
    );
  }
}

class _MyLibraryPage extends StatelessWidget {
  const _MyLibraryPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 라이브러리'),
      ),
      body: const MyLibraryScreen(),
    );
  }
}