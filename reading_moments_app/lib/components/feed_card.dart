import 'package:flutter/material.dart';
import 'package:reading_moments_app/components/like_button.dart';
import 'package:reading_moments_app/components/save_button.dart';
import 'package:reading_moments_app/models/feed_moment_item.dart';

class FeedCard extends StatelessWidget {
  final FeedMomentItem item;
  final bool processingLike;
  final bool processingSave;
  final String relativeTimeText;
  final VoidCallback onTapBook;
  final VoidCallback onTapMoment;
  final VoidCallback onTapLike;
  final VoidCallback onTapSave;

  const FeedCard({
    super.key,
    required this.item,
    required this.processingLike,
    required this.processingSave,
    required this.relativeTimeText,
    required this.onTapBook,
    required this.onTapMoment,
    required this.onTapLike,
    required this.onTapSave,
  });

  Widget _buildCover() {
    if ((item.coverUrl ?? '').trim().isNotEmpty) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTapBook,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            item.coverUrl!,
            width: 48,
            height: 68,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 48,
              height: 68,
              color: Colors.grey.shade300,
              alignment: Alignment.center,
              child: const Text(
                '표지\n없음',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTapBook,
      child: Container(
        width: 48,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Text(
          '표지\n없음',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuote = (item.quoteText ?? '').trim().isNotEmpty;
    final hasThought = (item.thoughtText ?? '').trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0.8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCover(),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onTapBook,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.bookTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          if ((item.bookAuthor ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.bookAuthor!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (hasQuote) ...[
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onTapMoment,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '“${item.quoteText!}”',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
            if (hasThought) ...[
              const SizedBox(height: 10),
              Text(
                item.thoughtText!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '${item.nickname} · $relativeTimeText',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                LikeButton(
                  liked: item.userLiked,
                  likeCount: item.likeCount,
                  processing: processingLike,
                  onTap: onTapLike,
                ),
                SaveButton(
                  saved: item.isBookWishlisted,
                  processing: processingSave,
                  onTap: onTapSave,
                ),
                TextButton(
                  onPressed: onTapBook,
                  child: const Text('책 보기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}