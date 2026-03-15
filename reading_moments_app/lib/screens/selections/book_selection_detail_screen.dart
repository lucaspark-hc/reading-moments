import 'package:flutter/material.dart';
import 'package:reading_moments_app/models/book_model.dart';
import 'package:reading_moments_app/models/book_selection_item.dart';
import 'package:reading_moments_app/models/my_book_record_group_item.dart';
import 'package:reading_moments_app/screens/books/add_note_screen.dart';
import 'package:reading_moments_app/screens/meetings/create_meeting_from_selection_screen.dart';
import 'package:reading_moments_app/screens/records/book_records_screen.dart';
import 'package:reading_moments_app/services/my_records_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class BookSelectionDetailScreen extends StatelessWidget {
  final BookSelectionItem selection;

  const BookSelectionDetailScreen({
    super.key,
    required this.selection,
  });

  Future<MyBookRecordGroupItem?> _findBookRecordGroup(int bookId) async {
    final service = MyRecordsService();
    final groups = await service.loadMyBookRecordGroups();
    for (final group in groups) {
      if (group.bookId == bookId) {
        return group;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasAuthor = (selection.bookAuthor ?? '').trim().isNotEmpty;
    final hasDescription = (selection.bookDescription ?? '').trim().isNotEmpty;
    final isPublic = selection.visibility == 'public';

    final book = BookModel(
      id: selection.bookId,
      isbn: selection.isbn ?? '',
      title: selection.bookTitle,
      author: selection.bookAuthor,
      coverUrl: selection.coverUrl,
      category: null,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('책 선정 기록'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((selection.coverUrl ?? '').trim().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        selection.coverUrl!,
                        width: 80,
                        height: 112,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 112,
                          color: Colors.grey.shade300,
                          alignment: Alignment.center,
                          child: const Text('표지 없음'),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 80,
                      height: 112,
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
                          selection.bookTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (hasAuthor) ...[
                          const SizedBox(height: 6),
                          Text(
                            selection.bookAuthor!,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text(isPublic ? '공개' : '비공개')),
                            Chip(
                              label: Text(
                                selection.createdAt
                                    .toLocal()
                                    .toString()
                                    .substring(0, 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasDescription) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '책 소개',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      selection.bookDescription!,
                      style: const TextStyle(height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '이 책을 고른 이유',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selection.selectionReason,
                    style: const TextStyle(height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddNoteScreen(book: book),
                  ),
                );

                if (!context.mounted) return;
                if (saved != true) return;

                try {
                  final group = await _findBookRecordGroup(selection.bookId);
                  if (!context.mounted) return;

                  if (group != null) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookRecordsScreen(group: group),
                      ),
                    );
                  } else {
                    showToast(context, '아직 저장된 기록이 없습니다.');
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  showToast(context, '내 기록 화면 이동 실패: $e');
                }
              },
              icon: const Icon(Icons.edit_note),
              label: const Text('기록 남기기'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CreateMeetingFromSelectionScreen(selection: selection),
                  ),
                );
              },
              child: const Text('이 책으로 모임 만들기'),
            ),
          ),
        ],
      ),
    );
  }
}