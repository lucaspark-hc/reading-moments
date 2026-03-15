import 'package:flutter/material.dart';
import 'package:reading_moments_app/models/book_model.dart';
import 'package:reading_moments_app/models/my_book_record_group_item.dart';
import 'package:reading_moments_app/models/my_record_item.dart';
import 'package:reading_moments_app/screens/books/add_note_screen.dart';
import 'package:reading_moments_app/screens/moments/moment_create_screen.dart';
import 'package:reading_moments_app/screens/moments/moment_scan_screen.dart';
import 'package:reading_moments_app/screens/moments/moments_list_screen.dart';
import 'package:reading_moments_app/screens/records/edit_record_screen.dart';
import 'package:reading_moments_app/screens/records/record_detail_screen.dart';
import 'package:reading_moments_app/services/my_records_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

enum MyRecordFilterType { all, publicOnly, privateOnly }

class BookRecordsScreen extends StatefulWidget {
  final MyBookRecordGroupItem group;

  const BookRecordsScreen({super.key, required this.group});

  @override
  State<BookRecordsScreen> createState() => _BookRecordsScreenState();
}

class _BookRecordsScreenState extends State<BookRecordsScreen> {
  final MyRecordsService _myRecordsService = MyRecordsService();

  bool _loading = true;
  List<MyRecordItem> _items = [];
  MyRecordFilterType _filter = MyRecordFilterType.all;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  String _visibilityFilterValue() {
    switch (_filter) {
      case MyRecordFilterType.publicOnly:
        return 'public';
      case MyRecordFilterType.privateOnly:
        return 'private';
      case MyRecordFilterType.all:
        return 'all';
    }
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);

    try {
      final items = await _myRecordsService.loadMyNotesByBook(
        widget.group.bookId,
        visibility: _visibilityFilterValue(),
      );

      if (!mounted) return;

      setState(() {
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      showToast(context, '기록 조회 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteRecord(MyRecordItem item) async {
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
      await _myRecordsService.deleteNote(item.id);

      if (!mounted) return;
      showToast(context, '기록이 삭제되었습니다.');
      await _loadItems();
    } catch (e) {
      if (!mounted) return;
      showToast(context, '기록 삭제 실패: $e');
    }
  }

  Future<void> _editRecord(MyRecordItem item) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditRecordScreen(item: item)),
    );

    if (updated == true) {
      await _loadItems();
    }
  }

  Future<void> _openRecordDetail(MyRecordItem item) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RecordDetailScreen(item: item)),
    );

    if (changed == true) {
      await _loadItems();
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

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SegmentedButton<MyRecordFilterType>(
        segments: const [
          ButtonSegment<MyRecordFilterType>(
            value: MyRecordFilterType.all,
            label: Text('전체'),
            icon: Icon(Icons.list),
          ),
          ButtonSegment<MyRecordFilterType>(
            value: MyRecordFilterType.publicOnly,
            label: Text('공개'),
            icon: Icon(Icons.public),
          ),
          ButtonSegment<MyRecordFilterType>(
            value: MyRecordFilterType.privateOnly,
            label: Text('비공개'),
            icon: Icon(Icons.lock_outline),
          ),
        ],
        selected: {_filter},
        onSelectionChanged: (selected) async {
          setState(() {
            _filter = selected.first;
          });
          await _loadItems();
        },
      ),
    );
  }

  Widget _buildRecordCard(MyRecordItem item) {
    final isPublic = item.visibility == 'public';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openRecordDetail(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(label: Text(_typeLabel(item.type))),
                  const SizedBox(width: 8),
                  Chip(label: Text(isPublic ? '공개' : '비공개')),
                  if (item.page != null) ...[
                    const SizedBox(width: 8),
                    Text('p.${item.page}'),
                  ],
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'detail') {
                        await _openRecordDetail(item);
                      } else if (value == 'edit') {
                        await _editRecord(item);
                      } else if (value == 'delete') {
                        await _deleteRecord(item);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'detail',
                        child: Text('상세보기'),
                      ),
                      PopupMenuItem<String>(value: 'edit', child: Text('수정')),
                      PopupMenuItem<String>(value: 'delete', child: Text('삭제')),
                    ],
                  ),
                ],
              ),
              if ((item.quoteText ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '“${item.quoteText!}”',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
              if ((item.noteText ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  item.noteText!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, height: 1.6),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    item.createdAt.toLocal().toString().substring(0, 16),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final g = widget.group;
    final hasAuthor = (g.bookAuthor ?? '').trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((g.coverUrl ?? '').trim().isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  g.coverUrl!,
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
                    g.bookTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasAuthor) ...[
                    const SizedBox(height: 6),
                    Text(
                      g.bookAuthor!,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text('내 기록 ${g.totalCount}개'),
                  Text('공개 ${g.publicCount}개 · 비공개 ${g.privateCount}개'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.menu_book),
                    label: const Text('문장 보기'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MomentsListScreen(
                            bookId: widget.group.bookId,
                            bookTitle: widget.group.bookTitle,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddNote() async {
    final book = BookModel(
      id: widget.group.bookId,
      isbn: '',
      title: widget.group.bookTitle,
      author: widget.group.bookAuthor,
      coverUrl: widget.group.coverUrl,
      category: null,
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddNoteScreen(book: book)),
    );

    if (result != null) {
      await _loadItems();
    }
  }

  Future<void> _openMomentCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MomentCreateScreen(bookId: widget.group.bookId),
      ),
    );

    if (result != null) {
      await _loadItems();
    }
  }

  Future<void> _openMomentScan() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MomentScanScreen(
          bookId: widget.group.bookId,
          bookTitle: widget.group.bookTitle,
        ),
      ),
    );

    if (result == true) {
      await _loadItems();
    }
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return const Center(child: Text('조건에 맞는 기록이 없습니다.'));
    }

    return RefreshIndicator(
      onRefresh: _loadItems,
      child: ListView(
        children: [
          _buildHeader(),
          ..._items.map(_buildRecordCard),
          const SizedBox(height: 180),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('책별 내 기록')),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'moment_scan',
            onPressed: _openMomentScan,
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('문장 스캔'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'moment_add',
            onPressed: _openMomentCreate,
            icon: const Icon(Icons.format_quote),
            label: const Text('문장 기록'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'note_add',
            onPressed: _openAddNote,
            icon: const Icon(Icons.add),
            label: const Text('기록 추가'),
          ),
        ],
      ),
    );
  }
}
