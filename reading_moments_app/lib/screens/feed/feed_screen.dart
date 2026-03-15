import 'package:flutter/material.dart';

import '../../models/book_feed_summary_item.dart';
import '../../services/feed_service.dart';
import '../../services/library_service.dart';
import '../../utils/app_utils.dart';
import '../../widgets/current_user_banner.dart';
import 'book_feed_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FeedService _feedService = FeedService();
  final LibraryService _libraryService = LibraryService();

  bool _isLoading = true;
  bool _processingBookId = false;

  List<BookFeedSummaryItem> _books = [];

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final items = await _feedService.loadBookFeedSummaries();

      if (!mounted) return;

      setState(() {
        _books = items;
      });
    } catch (e) {
      if (!mounted) return;
      showToast(context, '피드 조회 실패: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openBookFeed(BookFeedSummaryItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookFeedDetailScreen(summary: item),
      ),
    );

    await _loadFeed();
  }

  Future<void> _toggleWishlist(BookFeedSummaryItem item) async {
    if (_processingBookId) return;

    setState(() {
      _processingBookId = true;
    });

    try {
      if (item.isWishlisted) {
        await _libraryService.removeWishlistBook(item.bookId);
        if (!mounted) return;

        setState(() {
          _books = _books
              .map(
                (e) => e.bookId == item.bookId
                    ? e.copyWith(isWishlisted: false)
                    : e,
              )
              .toList();
        });

        showToast(context, '읽고 싶은 책에서 제거되었습니다.');
      } else {
        await _libraryService.addWishlistBook(item.bookId);
        if (!mounted) return;

        setState(() {
          _books = _books
              .map(
                (e) => e.bookId == item.bookId
                    ? e.copyWith(isWishlisted: true)
                    : e,
              )
              .toList();
        });

        showToast(context, '읽고 싶은 책에 추가되었습니다.');
      }
    } catch (e) {
      if (!mounted) return;
      showToast(context, '처리 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _processingBookId = false;
        });
      }
    }
  }

  Widget _buildBookCard(BookFeedSummaryItem item) {
    final hasAuthor = (item.bookAuthor ?? '').trim().isNotEmpty;
    final hasPreviewText = (item.previewText ?? '').trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openBookFeed(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((item.coverUrl ?? '').trim().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.coverUrl!,
                        width: 72,
                        height: 102,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 72,
                          height: 102,
                          color: Colors.grey.shade300,
                          alignment: Alignment.center,
                          child: const Text('표지 없음'),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 72,
                      height: 102,
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
                          item.bookTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (hasAuthor) ...[
                          const SizedBox(height: 6),
                          Text(
                            item.bookAuthor!,
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text('공개 책 선정 ${item.publicSelectionCount}개'),
                        Text('공개 기록 ${item.publicNoteCount}개'),
                        Text(
                          '최근 활동 ${item.latestCreatedAt.toLocal().toString().substring(0, 10)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (hasPreviewText) ...[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.previewText!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _processingBookId ? null : () => _toggleWishlist(item),
                      icon: Icon(
                        item.isWishlisted ? Icons.bookmark : Icons.bookmark_add_outlined,
                      ),
                      label: Text(
                        item.isWishlisted ? '읽고 싶은 책 저장됨' : '읽고 싶은 책',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openBookFeed(item),
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('책 피드 보기'),
                    ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('공개 피드'),
      ),
      body: Column(
        children: [
          const CurrentUserBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadFeed,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    '책 중심 공개 피드',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '공개 책 선정과 공개 기록이 있는 책을 중심으로 탐색합니다. (${_books.length}권)',
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
                  else if (_books.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('아직 공개된 책 선정이나 기록이 없습니다.'),
                    )
                  else
                    ..._books.map(_buildBookCard),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}