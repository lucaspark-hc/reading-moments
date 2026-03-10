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