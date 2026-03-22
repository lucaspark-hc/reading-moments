import 'package:flutter/material.dart';

class SaveButton extends StatelessWidget {
  final bool saved;
  final bool processing;
  final VoidCallback? onTap;

  const SaveButton({
    super.key,
    required this.saved,
    required this.processing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: processing ? null : onTap,
      icon: Icon(
        saved ? Icons.bookmark : Icons.bookmark_add_outlined,
        size: 18,
      ),
      label: Text(saved ? '읽고 싶어요' : '+ 내 서재'),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}