import 'package:flutter/material.dart';
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

class _MomentsListScreenState extends State<MomentsListScreen> {
  final MomentsService _momentsService = MomentsService();

  bool _loading = true;
  List<MomentModel> _items = [];

  @override
  void initState() {
    super.initState();
    _loadMoments();
  }

  Future<void> _loadMoments() async {
    setState(() => _loading = true);

    try {
      final items = await _momentsService.loadMomentsByBook(widget.bookId);

      if (!mounted) return;
      setState(() {
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      showToast(context, '문장 목록 조회 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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

  String _typeLabel(String type) {
    switch (type) {
      case 'thought':
        return '생각';
      case 'question':
        return '질문';
      case 'summary':
        return '요약';
      case 'word':
        return '단어';
      case 'quote':
      default:
        return '문장';
    }
  }

  Future<void> _openMomentDetail(MomentModel item) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MomentDetailScreen(moment: item)),
    );

    if (changed == true) {
      await _loadMoments();
    }
  }

  Widget _buildMomentCard(MomentModel item) {
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
              Row(
                children: [
                  Chip(label: Text(_typeLabel(item.type))),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(_visibilityLabel(item.visibility)),
                    backgroundColor: _visibilityColor(
                      item.visibility,
                    ).withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      color: _visibilityColor(item.visibility),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.page != null) ...[
                    const SizedBox(width: 8),
                    Text('p.${item.page}'),
                  ],
                ],
              ),
              const SizedBox(height: 10),
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
              if ((item.noteText ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  item.noteText!,
                  maxLines: 3,
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return const Center(child: Text('저장된 문장이 없습니다.'));
    }

    return RefreshIndicator(
      onRefresh: _loadMoments,
      child: ListView(
        children: [
          const SizedBox(height: 8),
          ..._items.map(_buildMomentCard),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.bookTitle)),
      body: _buildBody(),
    );
  }
}
