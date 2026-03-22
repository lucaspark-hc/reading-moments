import 'package:flutter/material.dart';

void showToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg)),
  );
}

String formatDateTime(DateTime dt) {
  final v = dt.toLocal();
  return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')} '
      '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
}

String formatRelativeDateTime(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now().toLocal();
  final diff = now.difference(local);

  if (diff.inMinutes < 1) {
    return '방금 전';
  }

  if (diff.inHours < 1) {
    return '${diff.inMinutes}분 전';
  }

  if (diff.inDays < 1) {
    return '${diff.inHours}시간 전';
  }

  final yesterday = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 1));
  final targetDay = DateTime(local.year, local.month, local.day);

  if (targetDay == yesterday) {
    return '어제';
  }

  if (now.year == local.year) {
    return '${local.month}월 ${local.day}일';
  }

  return '${local.year}년 ${local.month}월 ${local.day}일';
}