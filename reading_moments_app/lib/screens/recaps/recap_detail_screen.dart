import 'package:flutter/material.dart';
import 'package:reading_moments_app/models/recap_item.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class RecapDetailScreen extends StatelessWidget {
  final RecapItem recap;

  const RecapDetailScreen({super.key, required this.recap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 요약 상세'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            if (recap.createdAt != null)
              Text(
                formatDateTime(recap.createdAt!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            Text(recap.content),
          ],
        ),
      ),
    );
  }
}