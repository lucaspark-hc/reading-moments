import 'package:flutter/material.dart';
import 'package:reading_moments_app/models/my_record_item.dart';
import 'package:reading_moments_app/screens/records/edit_record_screen.dart';
import 'package:reading_moments_app/services/my_records_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class RecordDetailScreen extends StatefulWidget {
  final MyRecordItem item;

  const RecordDetailScreen({
    super.key,
    required this.item,
  });

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  final MyRecordsService _myRecordsService = MyRecordsService();

  late MyRecordItem _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
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

  Future<void> _editRecord() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditRecordScreen(item: _item),
      ),
    );

    if (updated == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _deleteRecord() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('기록 삭제'),
          content: const Text('이 기록을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _myRecordsService.deleteNote(_item.id);

      if (!mounted) return;
      showToast(context, '기록이 삭제되었습니다.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, '기록 삭제 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAuthor = (_item.bookAuthor ?? '').trim().isNotEmpty;
    final hasQuote = (_item.quoteText ?? '').trim().isNotEmpty;
    final hasNote = (_item.noteText ?? '').trim().isNotEmpty;
    final isPublic = _item.visibility == 'public';

    return Scaffold(
      appBar: AppBar(
        title: const Text('기록 상세'),
        actions: [
          IconButton(
            onPressed: _editRecord,
            icon: const Icon(Icons.edit),
            tooltip: '수정',
          ),
          IconButton(
            onPressed: _deleteRecord,
            icon: const Icon(Icons.delete_outline),
            tooltip: '삭제',
          ),
        ],
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (hasAuthor) ...[
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
                            Chip(label: Text(isPublic ? '공개' : '비공개')),
                            if (_item.page != null)
                              Chip(label: Text('p.${_item.page}')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _item.createdAt.toLocal().toString().substring(0, 16),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasQuote) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '기록 내용',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '“${_item.quoteText!}”',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (hasNote) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '내 생각',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _item.noteText!,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (!hasQuote && !hasNote) ...[
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('표시할 내용이 없습니다.'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _editRecord,
              icon: const Icon(Icons.edit),
              label: const Text('기록 수정'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _deleteRecord,
              icon: const Icon(Icons.delete_outline),
              label: const Text('기록 삭제'),
            ),
          ),
        ],
      ),
    );
  }
}