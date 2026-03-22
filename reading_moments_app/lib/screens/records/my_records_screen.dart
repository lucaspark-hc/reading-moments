import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/log/app_logger.dart';
import 'package:reading_moments_app/core/log/logged_state_mixin.dart';
import 'package:reading_moments_app/models/my_book_record_group_item.dart';
import 'package:reading_moments_app/screens/records/book_records_screen.dart';
import 'package:reading_moments_app/services/my_records_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';
import 'package:reading_moments_app/widgets/current_user_banner.dart';

class MyRecordsScreen extends StatefulWidget {
  const MyRecordsScreen({super.key});

  @override
  State<MyRecordsScreen> createState() => _MyRecordsScreenState();
}

class _MyRecordsScreenState extends State<MyRecordsScreen>
    with LoggedStateMixin<MyRecordsScreen> {
  final MyRecordsService _myRecordsService = MyRecordsService();

  bool _loading = true;
  List<MyBookRecordGroupItem> _items = [];

  @override
  String get screenName => 'MyRecordsScreen';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);

    AppLogger.apiStart('loadMyBookRecordGroups(from MyRecordsScreen)');

    try {
      final items = await _myRecordsService.loadMyBookRecordGroups();

      if (!mounted) return;

      setState(() {
        _items = items;
      });

      AppLogger.apiSuccess(
        'loadMyBookRecordGroups(from MyRecordsScreen)',
        detail: 'count=${items.length}',
      );
    } catch (e, st) {
      AppLogger.apiError(
        'loadMyBookRecordGroups(from MyRecordsScreen)',
        e,
        stackTrace: st,
      );
      if (!mounted) return;
      showToast(context, '내 기록 조회 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildBookCard(MyBookRecordGroupItem item) {
    final hasAuthor = (item.bookAuthor ?? '').trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          AppLogger.action(
            'OpenBookRecordsScreenFromMyRecords',
            detail: 'bookId=${item.bookId}, title=${item.bookTitle}',
          );

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookRecordsScreen(group: item),
            ),
          );

          await _loadItems();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((item.coverUrl ?? '').trim().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.coverUrl!,
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
                      item.bookTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (hasAuthor) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.bookAuthor!,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text('내 기록 ${item.totalCount}개'),
                    Text('공개 ${item.publicCount}개 · 비공개 ${item.privateCount}개'),
                    const SizedBox(height: 8),
                    Text(
                      '최근 기록 ${item.latestCreatedAt.toLocal().toString().substring(0, 16)}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text('아직 작성한 기록이 없습니다.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadItems,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          
          Text(
            '내가 남긴 기록을 책별로 모아봅니다. 공개와 비공개 기록이 모두 포함됩니다. (${_items.length}권)',
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          ..._items.map(_buildBookCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CurrentUserBanner(),
        Expanded(child: _buildBody()),
      ],
    );
  }
}