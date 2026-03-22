import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/log/app_logger.dart';
import 'package:reading_moments_app/core/log/logged_state_mixin.dart';
import 'package:reading_moments_app/models/my_book_record_group_item.dart';
import 'package:reading_moments_app/models/my_record_item.dart';
import 'package:reading_moments_app/screens/moments/moment_create_screen.dart';
import 'package:reading_moments_app/screens/moments/moment_scan_screen.dart';
import 'package:reading_moments_app/screens/records/book_records_list_screen.dart';
import 'package:reading_moments_app/services/library_service.dart';
import 'package:reading_moments_app/services/my_records_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class BookRecordsScreen extends StatefulWidget {
  final MyBookRecordGroupItem group;

  const BookRecordsScreen({
    super.key,
    required this.group,
  });

  @override
  State<BookRecordsScreen> createState() => _BookRecordsScreenState();
}

class _BookRecordsScreenState extends State<BookRecordsScreen>
    with LoggedStateMixin<BookRecordsScreen> {
  final MyRecordsService _myRecordsService = MyRecordsService();
  final LibraryService _libraryService = LibraryService();

  late MyBookRecordGroupItem _group;
  bool _loading = true;
  bool _emptyStateLogged = false;
  bool _markingDone = false;
  LibraryBookStatus _bookStatus = LibraryBookStatus.none;
  List<MyRecordItem> _todayItems = [];

  @override
  String get screenName => 'BookRecordsScreen';

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _reloadScreen();
  }

  Future<void> _reloadScreen() async {
    setState(() => _loading = true);

    AppLogger.apiStart(
      'reloadBookRecordsScreen',
      detail: 'bookId=${_group.bookId}, title=${_group.bookTitle}',
    );
    print(
      '📘 reloadBookRecordsScreen START | bookId=${_group.bookId} | title=${_group.bookTitle}',
    );

    try {
      final groups = await _myRecordsService.loadMyBookRecordGroups();
      final todayItems = await _myRecordsService.loadTodayMomentsByBook(
        _group.bookId,
      );
      final bookStatus = await _libraryService.getBookStatus(_group.bookId);

      final matched = groups.where((e) => e.bookId == _group.bookId).toList();
      if (matched.isNotEmpty) {
        _group = matched.first;
      } else {
        _group = MyBookRecordGroupItem(
          bookId: _group.bookId,
          bookTitle: _group.bookTitle,
          bookAuthor: _group.bookAuthor,
          coverUrl: _group.coverUrl,
          totalCount: 0,
          publicCount: 0,
          privateCount: 0,
          latestCreatedAt: DateTime.now(),
        );
      }

      if (!mounted) return;

      setState(() {
        _todayItems = todayItems;
        _bookStatus = bookStatus;
        _emptyStateLogged = false;
      });

      AppLogger.apiSuccess(
        'reloadBookRecordsScreen',
        detail:
            'summaryCount=${_group.totalCount}, todayCount=${_todayItems.length}, status=${_bookStatus.name}',
      );
      print(
        '✅ reloadBookRecordsScreen SUCCESS | summaryCount=${_group.totalCount} | todayCount=${_todayItems.length} | status=${_bookStatus.name}',
      );
    } catch (e, st) {
      AppLogger.apiError('reloadBookRecordsScreen', e, stackTrace: st);
      print('❌ reloadBookRecordsScreen FAIL | $e');
      if (!mounted) return;
      showToast(context, '화면 갱신 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
      print('🏁 reloadBookRecordsScreen END');
    }
  }

  Future<void> _markBookAsDone() async {
    if (_markingDone) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('독서 완료'),
          content: Text('"${_group.bookTitle}" 을(를) 완료한 책으로 전환하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('완료'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    AppLogger.action(
      'MarkBookAsDoneFromRecords',
      detail: 'bookId=${_group.bookId}, title=${_group.bookTitle}',
    );
    print(
      '🏁 MarkBookAsDoneFromRecords | bookId=${_group.bookId} | title=${_group.bookTitle}',
    );

    setState(() {
      _markingDone = true;
    });

    try {
      await _libraryService.markBookAsDone(_group.bookId);

      if (!mounted) return;

      showToast(context, '독서 완료 처리되었습니다.');

      Navigator.pop(context, {
        'action': 'mark_done',
        'bookId': _group.bookId,
      });
    } catch (e, st) {
      AppLogger.apiError('markBookAsDone(from records)', e, stackTrace: st);
      print('❌ MarkBookAsDoneFromRecords FAIL | $e');
      if (!mounted) return;
      showToast(context, '독서 완료 처리 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _markingDone = false;
        });
      }
    }
  }

  Future<void> _openRecordsList() async {
    AppLogger.action(
      'OpenBookRecordsList',
      detail: 'bookId=${_group.bookId}, title=${_group.bookTitle}',
    );
    print(
      '📚 OpenBookRecordsList | bookId=${_group.bookId} | title=${_group.bookTitle}',
    );

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BookRecordsListScreen(group: _group),
      ),
    );

    if (changed == true) {
      await _reloadScreen();
    }
  }

  Future<void> _openMomentCreate() async {
    AppLogger.action(
      'OpenMomentCreate',
      detail: 'bookId=${_group.bookId}, title=${_group.bookTitle}',
    );
    print(
      '✍️ OpenMomentCreate | bookId=${_group.bookId} | title=${_group.bookTitle}',
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MomentCreateScreen(bookId: _group.bookId),
      ),
    );

    if (result != null) {
      await _reloadScreen();
    }
  }

  Future<void> _openMomentScan() async {
    AppLogger.action(
      'OpenMomentScan',
      detail: 'bookId=${_group.bookId}, title=${_group.bookTitle}',
    );
    print(
      '📷 OpenMomentScan | bookId=${_group.bookId} | title=${_group.bookTitle}',
    );

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MomentScanScreen(
          bookId: _group.bookId,
          bookTitle: _group.bookTitle,
        ),
      ),
    );

    if (result == true) {
      await _reloadScreen();
    }
  }

  Widget _buildHeaderCard() {
    final hasAuthor = (_group.bookAuthor ?? '').trim().isNotEmpty;
    final canMarkDone = _bookStatus == LibraryBookStatus.reading ||
        _bookStatus == LibraryBookStatus.selected;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((_group.coverUrl ?? '').trim().isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  _group.coverUrl!,
                  width: 86,
                  height: 122,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 86,
                    height: 122,
                    color: Colors.grey.shade300,
                    alignment: Alignment.center,
                    child: const Text('표지 없음'),
                  ),
                ),
              )
            else
              Container(
                width: 86,
                height: 122,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text('표지 없음'),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _group.bookTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasAuthor) ...[
                    const SizedBox(height: 8),
                    Text(
                      _group.bookAuthor!,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    '내 기록 ${_group.totalCount}개',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '공개 ${_group.publicCount}개 · 비공개 ${_group.privateCount}개',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_group.totalCount > 0)
                        ElevatedButton.icon(
                          onPressed: _openRecordsList,
                          icon: const Icon(Icons.menu_book),
                          label: const Text('내 기록 보기'),
                        ),
                      if (canMarkDone)
                        FilledButton.icon(
                          onPressed: _markingDone ? null : _markBookAsDone,
                          icon: _markingDone
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: const Text('독서 완료'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isCompactTodayCard(
    MyRecordItem item,
    bool hasExplain,
    bool hasThought,
  ) {
    final quoteLength = (item.quoteText ?? '').trim().length;
    return !hasExplain && !hasThought && quoteLength <= 40;
  }

  Widget _buildCompactTodayCard(MyRecordItem item, bool isPublic) {
    return Row(
      children: [
        Chip(
          label: Text(isPublic ? '공개' : '비공개'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '“${item.quoteText ?? ''}”',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          item.createdAt.toLocal().toString().substring(11, 16),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFullTodayCard(
    MyRecordItem item,
    bool isPublic,
    bool hasExplain,
    bool hasThought,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(label: Text(isPublic ? '공개' : '비공개')),
        const SizedBox(height: 10),
        const Text(
          '문장',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '“${item.quoteText ?? ''}”',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        if (hasExplain) ...[
          const SizedBox(height: 12),
          const Text(
            '쉽게 풀어보기',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Text(
              item.explainText!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
        ],
        if (hasThought) ...[
          const SizedBox(height: 12),
          const Text(
            '내 생각',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.noteText!.trim(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          item.createdAt.toLocal().toString().substring(0, 16),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTodayCard(MyRecordItem item) {
    final isPublic = item.visibility == 'public';
    final hasExplain = (item.explainText ?? '').trim().isNotEmpty;
    final hasThought = (item.noteText ?? '').trim().isNotEmpty;
    final isCompact = _isCompactTodayCard(item, hasExplain, hasThought);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: isCompact
            ? _buildCompactTodayCard(item, isPublic)
            : _buildFullTodayCard(
                item,
                isPublic,
                hasExplain,
                hasThought,
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (!_emptyStateLogged) {
      _emptyStateLogged = true;
      AppLogger.action(
        'BookRecordsEmptyStateViewed',
        detail: 'bookId=${_group.bookId}, title=${_group.bookTitle}',
      );
      print(
        '🫙 BookRecordsEmptyStateViewed | bookId=${_group.bookId} | title=${_group.bookTitle}',
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '아직 기록이 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '첫 번째 생각을 남겨보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () async {
                AppLogger.action(
                  'OpenMomentCreateFromEmptyState',
                  detail: 'bookId=${_group.bookId}, title=${_group.bookTitle}',
                );
                print(
                  '✍️ OpenMomentCreateFromEmptyState | bookId=${_group.bookId} | title=${_group.bookTitle}',
                );
                await _openMomentCreate();
              },
              icon: const Icon(Icons.edit_note),
              label: const Text('기록 남기기'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySectionHeader() {
    final count = _todayItems.length;
    final countText = count == 0 ? '오늘 아직 기록이 없어요' : '오늘 $count개 기록했어요';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘 독서 기록',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            countText,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySection() {
    if (_group.totalCount == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTodaySectionHeader(),
          _buildEmptyState(),
        ],
      );
    }

    if (_todayItems.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTodaySectionHeader(),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('오늘 기록은 아직 없습니다. 문장 스캔 또는 문장 기록으로 이어가 보세요.'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTodaySectionHeader(),
        ..._todayItems.map(_buildTodayCard),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _reloadScreen,
      child: ListView(
        children: [
          _buildHeaderCard(),
          _buildTodaySection(),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('책별 내 기록'),
      ),
      body: _buildBody(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'moment_scan_summary',
            onPressed: _openMomentScan,
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('문장 스캔'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'moment_add_summary',
            onPressed: _openMomentCreate,
            icon: const Icon(Icons.format_quote),
            label: const Text('문장 기록'),
          ),
        ],
      ),
    );
  }
}