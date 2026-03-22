import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/log/app_logger.dart';
import 'package:reading_moments_app/core/log/logged_state_mixin.dart';
import 'package:reading_moments_app/models/feed_moment_item.dart';
import 'package:reading_moments_app/services/feed_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class FeedMomentDetailScreen extends StatefulWidget {
  final FeedMomentItem item;

  const FeedMomentDetailScreen({
    super.key,
    required this.item,
  });

  @override
  State<FeedMomentDetailScreen> createState() => _FeedMomentDetailScreenState();
}

class _FeedMomentDetailScreenState extends State<FeedMomentDetailScreen>
    with LoggedStateMixin<FeedMomentDetailScreen> {
  final FeedService _feedService = FeedService();

  late FeedMomentItem _item;
  bool _processingLike = false;

  @override
  String get screenName => 'FeedMomentDetailScreen';

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'thought':
        return '생각';
      case 'question':
        return '질문';
      case 'summary':
        return '요약';
      case 'word':
        return '단어';
      case 'quote':
      default:
        return '문장';
    }
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

  Future<void> _toggleLike() async {
    if (_processingLike) return;

    final previous = _item;

    setState(() {
      _processingLike = true;
      _item = _item.copyWith(
        userLiked: !_item.userLiked,
        likeCount: _item.userLiked
            ? (_item.likeCount > 0 ? _item.likeCount - 1 : 0)
            : _item.likeCount + 1,
      );
    });

    AppLogger.action(
      'ToggleLikeFromFeedMomentDetail',
      detail: 'momentId=${_item.id}, nextLiked=${_item.userLiked}',
    );

    try {
      if (_item.userLiked) {
        await _feedService.likeMoment(_item.id);
      } else {
        await _feedService.unlikeMoment(_item.id);
      }

      if (!mounted) return;
      Navigator.pop(context, _item);
    } catch (e, st) {
      AppLogger.apiError('toggleLikeFromFeedMomentDetail', e, stackTrace: st);

      if (!mounted) return;
      setState(() {
        _item = previous;
      });
      showToast(context, '좋아요 처리 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _processingLike = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasThought = (_item.thoughtText ?? '').trim().isNotEmpty;
    final hasQuote = (_item.quoteText ?? '').trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('모먼트 상세'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((_item.coverUrl ?? '').trim().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _item.coverUrl!,
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
                      _item.bookTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if ((_item.bookAuthor ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _item.bookAuthor!,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(_typeLabel(_item.type))),
                        Chip(label: Text(_item.nickname)),
                        if (_item.page != null) Chip(label: Text('p.${_item.page}')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (hasQuote) ...[
            const Text(
              '문장',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '“${_item.quoteText!}”',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.7,
              ),
            ),
          ],
          if (hasThought) ...[
            const SizedBox(height: 28),
            const Text(
              '생각',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _item.thoughtText!.trim(),
              style: const TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _processingLike ? null : _toggleLike,
                icon: Icon(
                  _item.userLiked ? Icons.favorite : Icons.favorite_border,
                ),
                label: Text('좋아요 ${_item.likeCount}'),
              ),
              const Spacer(),
              Text(
                _formatDate(_item.createdAt),
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}