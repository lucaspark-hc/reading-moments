import 'package:flutter/material.dart';

import '../../models/feed_note_item.dart';
import '../../services/feed_service.dart';
import '../../services/library_service.dart';

class FeedNoteDetailScreen extends StatefulWidget {
  final FeedNoteItem item;

  const FeedNoteDetailScreen({
    super.key,
    required this.item,
  });

  @override
  State<FeedNoteDetailScreen> createState() => _FeedNoteDetailScreenState();
}

class _FeedNoteDetailScreenState extends State<FeedNoteDetailScreen> {
  final LibraryService _libraryService = LibraryService();
  final FeedService _feedService = FeedService();

  bool _isSavingBook = false;
  bool _isBookSaved = false;
  bool _loadingSavedState = true;

  bool _isLiked = false;
  int _likeCount = 0;
  bool _processingLike = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.item.isLiked;
    _likeCount = widget.item.likeCount;
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    try {
      final isSaved = await _libraryService.isBookSaved(widget.item.bookId);

      if (!mounted) return;

      setState(() {
        _isBookSaved = isSaved;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 상태 조회 실패: $e')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _loadingSavedState = false;
      });
    }
  }

  Future<void> _toggleWishlistBook() async {
    if (_isSavingBook) return;

    setState(() {
      _isSavingBook = true;
    });

    try {
      if (_isBookSaved) {
        await _libraryService.removeWishlistBook(widget.item.bookId);

        if (!mounted) return;

        setState(() {
          _isBookSaved = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('읽고 싶은 책에서 제거되었습니다.')),
        );
      } else {
        await _libraryService.addWishlistBook(widget.item.bookId);

        if (!mounted) return;

        setState(() {
          _isBookSaved = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('읽고 싶은 책에 추가되었습니다.')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리 실패: $e')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isSavingBook = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_processingLike) return;

    setState(() {
      _processingLike = true;
    });

    try {
      if (_isLiked) {
        await _feedService.unlikeNote(widget.item.id);
        if (!mounted) return;
        setState(() {
          _isLiked = false;
          _likeCount = _likeCount > 0 ? _likeCount - 1 : 0;
        });
      } else {
        await _feedService.likeNote(widget.item.id);
        if (!mounted) return;
        setState(() {
          _isLiked = true;
          _likeCount = _likeCount + 1;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('공감 처리 실패: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _processingLike = false;
      });
    }
  }

  String _typeLabel(String type) {
    switch (type) {
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
    final item = widget.item;

    final hasQuote = (item.quoteText ?? '').trim().isNotEmpty;
    final hasNote = (item.noteText ?? '').trim().isNotEmpty;
    final hasAuthor = (item.bookAuthor ?? '').trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('기록 상세'),
        actions: [
          IconButton(
            onPressed: _loadingSavedState || _isSavingBook
                ? null
                : _toggleWishlistBook,
            icon: _loadingSavedState || _isSavingBook
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isBookSaved ? Icons.bookmark : Icons.bookmark_add_outlined,
                  ),
            tooltip: _isBookSaved ? '읽고 싶은 책에서 제거' : '읽고 싶은 책에 추가',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(label: Text(_typeLabel(item.type))),
                      Chip(label: Text(item.nickname)),
                      if (item.page != null) Chip(label: Text('p.${item.page}')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.bookTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasAuthor) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.bookAuthor!,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    item.createdAt.toLocal().toString().substring(0, 16),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (hasQuote)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '구절',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '“${item.quoteText!}”',
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (hasQuote) const SizedBox(height: 16),
          if (hasNote)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '내 생각',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.noteText!,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!hasQuote && !hasNote)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('표시할 내용이 없습니다.'),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  InkWell(
                    onTap: _processingLike ? null : _toggleLike,
                    borderRadius: BorderRadius.circular(20),
                    child: Row(
                      children: [
                        Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked ? Colors.red : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text('공감 $_likeCount'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: Colors.grey.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '출처: 공개된 독서 기록입니다. 원작성자의 기록을 기반으로 표시됩니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}