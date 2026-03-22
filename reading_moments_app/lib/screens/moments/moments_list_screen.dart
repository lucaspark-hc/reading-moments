import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/log/app_logger.dart';
import 'package:reading_moments_app/core/log/logged_state_mixin.dart';
import 'package:reading_moments_app/models/moment_model.dart';
import 'package:reading_moments_app/screens/moments/moment_detail_screen.dart';
import 'package:reading_moments_app/services/moments_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class MomentsListScreen extends StatefulWidget {
  final int bookId;
  final String bookTitle;

  const MomentsListScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  State<MomentsListScreen> createState() => _MomentsListScreenState();
}

class _MomentsListScreenState extends State<MomentsListScreen>
    with LoggedStateMixin<MomentsListScreen> {
  final MomentsService _momentsService = MomentsService();

  bool _loading = true;
  List<MomentModel> _items = [];

  @override
  String get screenName => 'MomentsListScreen';

  @override
  void initState() {
    super.initState();
    _loadMoments();
  }

  Future<void> _loadMoments() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    AppLogger.apiStart(
      'loadMomentsByBook',
      detail: 'bookId=${widget.bookId}, title=${widget.bookTitle}',
    );

    try {
      final items = await _momentsService.loadMomentsByBook(widget.bookId);

      if (!mounted) return;

      setState(() {
        _items = items;
      });

      AppLogger.apiSuccess(
        'loadMomentsByBook',
        detail: 'count=${items.length}',
      );
    } catch (e, st) {
      AppLogger.apiError('loadMomentsByBook', e, stackTrace: st);
      if (!mounted) return;
      showToast(context, '문장 목록 조회 실패: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _visibilityLabel(String visibility) {
    switch (visibility) {
      case 'public':
        return '전체공개';
      case 'meeting':
        return '모임공유';
      case 'private':
      default:
        return '나만보기';
    }
  }

  Color _visibilityColor(String visibility) {
    switch (visibility) {
      case 'public':
        return Colors.green;
      case 'meeting':
        return Colors.orange;
      case 'private':
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Future<void> _openMomentDetail(MomentModel item) async {
    AppLogger.action(
      'OpenMomentDetail',
      detail: 'momentId=${item.id}, bookId=${widget.bookId}',
    );

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MomentDetailScreen(moment: item),
      ),
    );

    if (changed == true) {
      AppLogger.info('Moment detail changed -> reload list');
      await _loadMoments();
    }
  }

  Widget _buildMomentCard(MomentModel item) {
    final hasThought = (item.noteText ?? '').trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await _openMomentDetail(item);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(_visibilityLabel(item.visibility)),
                    backgroundColor:
                        _visibilityColor(item.visibility).withOpacity(0.12),
                    labelStyle: TextStyle(
                      color: _visibilityColor(item.visibility),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.page != null) Text('p.${item.page}'),
                ],
              ),
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
                '“${item.quoteText}”',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
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
              Row(
                children: [
                  Text(
                    _formatDate(item.createdAt),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return RefreshIndicator(
      onRefresh: _loadMoments,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(
            child: Text(
              '저장된 문장이 없습니다.',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadMoments,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) return const SizedBox(height: 8);
          if (index == _items.length + 1) return const SizedBox(height: 32);
          final item = _items[index - 1];
          return _buildMomentCard(item);
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return _buildEmpty();
    }

    return _buildList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookTitle),
      ),
      body: _buildBody(),
    );
  }
}