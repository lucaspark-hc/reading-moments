import 'package:flutter/material.dart';
import 'package:reading_moments_app/models/moment_model.dart';
import 'package:reading_moments_app/services/moments_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class MomentDetailScreen extends StatefulWidget {
  final MomentModel moment;

  const MomentDetailScreen({
    super.key,
    required this.moment,
  });

  @override
  State<MomentDetailScreen> createState() => _MomentDetailScreenState();
}

class _MomentDetailScreenState extends State<MomentDetailScreen> {
  final MomentsService _momentsService = MomentsService();

  bool _deleting = false;

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

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Future<void> _deleteMoment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('문장 삭제'),
          content: const Text('이 문장을 삭제하시겠습니까?'),
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

    setState(() {
      _deleting = true;
    });

    try {
      await _momentsService.deleteMoment(widget.moment.id);

      if (!mounted) return;
      showToast(context, '문장이 삭제되었습니다.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, '문장 삭제 실패: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _deleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final moment = widget.moment;

    return Scaffold(
      appBar: AppBar(
        title: const Text('문장 상세'),
        actions: [
          IconButton(
            onPressed: _deleting ? null : _deleteMoment,
            tooltip: '삭제',
            icon: _deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(_typeLabel(moment.type))),
              Chip(label: Text(_visibilityLabel(moment.visibility))),
              if (moment.page != null) Text('p.${moment.page}'),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '“${moment.quoteText}”',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.7,
            ),
          ),
          if ((moment.noteText ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text(
              '내 생각',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              moment.noteText!.trim(),
              style: const TextStyle(
                fontSize: 15,
                height: 1.7,
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            '작성일: ${_formatDate(moment.createdAt)}',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
          if (moment.updatedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              '수정일: ${_formatDate(moment.updatedAt!)}',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}