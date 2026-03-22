import 'package:flutter/material.dart';

import '../../components/feed_card.dart';
import '../../components/snackbar_message.dart';
import '../../core/log/app_logger.dart';
import '../../core/log/logged_state_mixin.dart';
import '../../core/supabase_client.dart';
import '../../models/feed_moment_item.dart';
import '../../models/my_book_record_group_item.dart';
import '../../screens/library/my_library_screen.dart';
import '../../screens/meetings/create_meeting_screen.dart';
import '../../screens/records/book_records_screen.dart';
import '../../services/feed_service.dart';
import '../../services/library_service.dart';
import '../../utils/app_utils.dart';
import '../../widgets/current_user_banner.dart';
import 'book_detail_screen.dart';
import 'feed_moment_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with LoggedStateMixin<FeedScreen> {
  final FeedService _feedService = FeedService();
  final LibraryService _libraryService = LibraryService();

  bool _isLoading = true;
  bool _isLoadingContinueReading = false;
  final Set<int> _processingMomentIds = <int>{};
  final Set<int> _processingBookIds = <int>{};
  List<FeedMomentItem> _items = [];
  _ContinueReadingCardData? _continueReading;

  @override
  String get screenName => 'FeedScreen';

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _isLoadingContinueReading = true;
    });

    AppLogger.apiStart('loadFeedScreen');

    try {
      final results = await Future.wait<dynamic>([
        _feedService.loadPublicMoments(),
        _loadContinueReadingCard(),
      ]);

      final items = results[0] as List<FeedMomentItem>;
      final continueReading = results[1] as _ContinueReadingCardData?;

      if (!mounted) return;

      setState(() {
        _items = items;
        _continueReading = continueReading;
      });

      AppLogger.apiSuccess(
        'loadFeedScreen',
        detail:
            'count=${items.length}, hasContinueReading=${continueReading != null}',
      );
    } catch (e, st) {
      AppLogger.apiError('loadFeedScreen', e, stackTrace: st);
      if (!mounted) return;
      showToast(context, '공개피드 조회 실패: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingContinueReading = false;
      });
    }
  }

  Future<_ContinueReadingCardData?> _loadContinueReadingCard() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      AppLogger.warn('FeedContinueReading skipped: currentUser is null');
      return null;
    }

    AppLogger.apiStart(
      'loadFeedContinueReading',
      detail: 'userId=${user.id}',
    );

    try {
      final selectionRows = await supabase
          .from('book_selections')
          .select('''
            id,
            book_id,
            created_at,
            updated_at,
            books:book_id (
              id,
              title,
              author,
              cover_url
            )
          ''')
          .eq('user_id', user.id)
          .eq('status', 'reading')
          .order('updated_at', ascending: false)
          .order('created_at', ascending: false)
          .limit(1);

      final selections = (selectionRows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (selections.isEmpty) {
        AppLogger.apiSuccess(
          'loadFeedContinueReading',
          detail: 'empty=true',
        );
        return null;
      }

      final selection = selections.first;
      final bookId = (selection['book_id'] as num).toInt();
      final bookMap = Map<String, dynamic>.from(
        (selection['books'] as Map?) ?? <String, dynamic>{},
      );

      final momentRows = await supabase
          .from('reading_moments')
          .select('id, visibility, created_at')
          .eq('user_id', user.id)
          .eq('book_id', bookId)
          .order('created_at', ascending: false);

      final moments = (momentRows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final latestMomentAt = moments.isNotEmpty && moments.first['created_at'] != null
          ? DateTime.tryParse(moments.first['created_at'] as String)?.toLocal()
          : null;

      final totalCount = moments.length;
      final publicCount =
          moments.where((e) => (e['visibility'] ?? 'private') == 'public').length;
      final privateCount = totalCount - publicCount;

      final latestAt = latestMomentAt ??
          DateTime.tryParse(
                (selection['updated_at'] ?? selection['created_at']) as String,
              )?.toLocal() ??
          DateTime.now().toLocal();

      final group = MyBookRecordGroupItem(
        bookId: bookId,
        bookTitle: (bookMap['title'] ?? '-') as String,
        bookAuthor: bookMap['author'] as String?,
        coverUrl: bookMap['cover_url'] as String?,
        totalCount: totalCount,
        publicCount: publicCount,
        privateCount: privateCount,
        latestCreatedAt: latestAt,
      );

      final result = _ContinueReadingCardData(
        group: group,
        lastMomentAt: latestMomentAt,
      );

      AppLogger.apiSuccess(
        'loadFeedContinueReading',
        detail:
            'bookId=$bookId, totalCount=$totalCount, hasLastMoment=${latestMomentAt != null}',
      );

      return result;
    } catch (e, st) {
      AppLogger.apiError('loadFeedContinueReading', e, stackTrace: st);
      return null;
    }
  }

  Future<void> _openMomentDetail(FeedMomentItem item) async {
    AppLogger.action(
      'OpenFeedMomentDetail',
      detail: 'momentId=${item.id}',
    );

    final result = await Navigator.push<FeedMomentItem>(
      context,
      MaterialPageRoute(
        builder: (_) => FeedMomentDetailScreen(item: item),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _items = _items.map((e) => e.id == result.id ? result : e).toList();
    });
  }

  Future<void> _openBookDetail(FeedMomentItem item) async {
    AppLogger.action(
      'OpenBookDetailFromFlowFeed',
      detail: 'bookId=${item.bookId}, momentId=${item.id}',
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookDetailScreen(bookId: item.bookId),
      ),
    );

    if (!mounted) return;
    await _loadFeed();
  }

  Future<void> _openLibrary({
    required LibraryTabType tab,
    required int? targetBookId,
  }) async {
    AppLogger.action(
      'OpenLibraryFromFlowFeed',
      detail: 'tab=${tab.name}, targetBookId=$targetBookId',
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('내 라이브러리')),
          body: MyLibraryScreen(
            initialTab: tab,
            targetBookId: targetBookId,
          ),
        ),
      ),
    );

    if (!mounted) return;
    await _loadFeed();
  }

  Future<void> _openContinueReading() async {
    final data = _continueReading;
    if (data == null) return;

    AppLogger.action(
      'OpenContinueReadingFromFeedTopCard',
      detail: 'bookId=${data.group.bookId}',
    );

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BookRecordsScreen(group: data.group),
      ),
    );

    if (!mounted) return;
    await _loadFeed();
  }

  Future<void> _openBookPickerFromEmptyState() async {
    AppLogger.action('OpenBookPickerFromFeedContinueReadingEmpty');

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateMeetingScreen(),
      ),
    );

    if (!mounted) return;
    await _loadFeed();
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

  Future<void> _showLibraryActionMessage({
    required String message,
    required LibraryTabType tab,
    required int targetBookId,
  }) async {
    AppLogger.action(
      'ShowLibraryActionMessage',
      detail: 'message=$message, tab=${tab.name}, targetBookId=$targetBookId',
    );

    await showActionMessage(
      context: context,
      message: message,
      actionLabel: '내 라이브러리',
      onAction: () {
        AppLogger.action(
          'LibraryActionTappedFromFlowFeedMessage',
          detail: 'tab=${tab.name}, targetBookId=$targetBookId',
        );

        _openLibrary(
          tab: tab,
          targetBookId: targetBookId,
        );
      },
    );
  }

  Future<void> _toggleLike(FeedMomentItem item) async {
    if (_processingMomentIds.contains(item.id)) return;

    final previousItem = item;
    final optimistic = item.copyWith(
      userLiked: !item.userLiked,
      likeCount: item.userLiked
          ? (item.likeCount > 0 ? item.likeCount - 1 : 0)
          : item.likeCount + 1,
    );

    setState(() {
      _processingMomentIds.add(item.id);
      _items = _items.map((e) => e.id == item.id ? optimistic : e).toList();
    });

    AppLogger.action(
      'ToggleLikeFromFlowFeed',
      detail: 'momentId=${item.id}, nextLiked=${optimistic.userLiked}',
    );

    try {
      if (optimistic.userLiked) {
        await _feedService.likeMoment(item.id);
      } else {
        await _feedService.unlikeMoment(item.id);
      }
    } catch (e, st) {
      AppLogger.apiError('toggleLikeFromFlowFeed', e, stackTrace: st);

      if (!mounted) return;
      setState(() {
        _items = _items.map((e) => e.id == item.id ? previousItem : e).toList();
      });
      showToast(context, '좋아요 처리 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _processingMomentIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _saveBook(FeedMomentItem item) async {
    if (_processingBookIds.contains(item.bookId)) return;

    setState(() {
      _processingBookIds.add(item.bookId);
    });

    AppLogger.action(
      'FlowFeed_SaveButton_Click',
      detail: 'bookId=${item.bookId}',
    );

    try {
      final status = await _libraryService.getBookStatus(item.bookId);

      AppLogger.info(
        'FlowFeed_SaveBook_Status | bookId=${item.bookId}, status=${status.name}',
      );

      if (!mounted) return;

      if (status != LibraryBookStatus.none) {
        String message = '이미 내 라이브러리에 있습니다.';

        switch (status) {
          case LibraryBookStatus.wishlist:
            message = '이미 읽고 싶은 책에 저장되어 있습니다.';
            break;
          case LibraryBookStatus.selected:
          case LibraryBookStatus.reading:
            message = '이미 내 라이브러리의 독서중 책입니다.';
            break;
          case LibraryBookStatus.done:
            message = '이미 완료한 책에 저장되어 있습니다.';
            break;
          case LibraryBookStatus.none:
            break;
        }

        await _showLibraryActionMessage(
          message: message,
          tab: _mapStatusToLibraryTab(status),
          targetBookId: item.bookId,
        );
        return;
      }

      setState(() {
        _items = _items
            .map(
              (e) => e.bookId == item.bookId
                  ? e.copyWith(isBookWishlisted: true)
                  : e,
            )
            .toList();
      });

      await _libraryService.addWishlistBook(item.bookId);

      if (!mounted) return;

      await showActionMessage(
        context: context,
        message: '읽고 싶은 책에 저장되었습니다.',
      );
    } catch (e, st) {
      AppLogger.apiError('saveBookFromFlowFeed', e, stackTrace: st);

      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (e) => e.bookId == item.bookId
                  ? e.copyWith(isBookWishlisted: false)
                  : e,
            )
            .toList();
      });
      showToast(context, '책 저장 처리 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _processingBookIds.remove(item.bookId);
        });
      }
    }
  }

  Widget _buildContinueReadingSection() {
    if (_isLoadingContinueReading) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    final data = _continueReading;

    if (data == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: _openBookPickerFromEmptyState,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '읽고 있는 책이 없습니다',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  '책 고르기',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final group = data.group;
    final hasCover = (group.coverUrl ?? '').trim().isNotEmpty;
    final lastRecordText = data.lastMomentAt != null
        ? formatRelativeDateTime(data.lastMomentAt!)
        : '기록 없음';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _openContinueReading,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (hasCover)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    group.coverUrl!,
                    width: 32,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 32,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 32,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '마지막 기록 · $lastRecordText',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '이어읽기',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        '사람들의 생각이 모여 흐르는 공간 · 마음에 드는 책은 바로 내 서재에 담아보세요. (${_items.length}개)',
        style: TextStyle(
          color: Colors.grey.shade700,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('아직 공개된 기록이 없습니다.'),
      );
    }

    return Column(
      children: _items.map((item) {
        return FeedCard(
          item: item,
          processingLike: _processingMomentIds.contains(item.id),
          processingSave: _processingBookIds.contains(item.bookId),
          relativeTimeText: formatRelativeDateTime(item.createdAt),
          onTapBook: () => _openBookDetail(item),
          onTapMoment: () => _openMomentDetail(item),
          onTapLike: () => _toggleLike(item),
          onTapSave: () => _saveBook(item),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CurrentUserBanner(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFeed,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildContinueReadingSection(),
                _buildDescriptionSection(),
                _buildContent(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ContinueReadingCardData {
  final MyBookRecordGroupItem group;
  final DateTime? lastMomentAt;

  const _ContinueReadingCardData({
    required this.group,
    required this.lastMomentAt,
  });
}