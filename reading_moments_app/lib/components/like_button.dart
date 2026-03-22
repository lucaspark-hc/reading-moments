import 'package:flutter/material.dart';

class LikeButton extends StatelessWidget {
  final bool liked;
  final int likeCount;
  final bool processing;
  final VoidCallback? onTap;

  const LikeButton({
    super.key,
    required this.liked,
    required this.likeCount,
    required this.processing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = liked ? Colors.red : Colors.grey.shade700;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: processing ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              liked ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              '$likeCount',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}