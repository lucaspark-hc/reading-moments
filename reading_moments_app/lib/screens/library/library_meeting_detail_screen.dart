import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/answer_item.dart';
import 'package:reading_moments_app/models/meeting_model.dart';
import 'package:reading_moments_app/models/recap_item.dart';
import 'package:reading_moments_app/screens/recaps/recap_detail_screen.dart';
import 'package:reading_moments_app/services/questions_service.dart';
import 'package:reading_moments_app/services/recaps_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class LibraryMeetingDetailScreen extends StatefulWidget {
  final MeetingModel meeting;

  const LibraryMeetingDetailScreen({
    super.key,
    required this.meeting,
  });

  @override
  State<LibraryMeetingDetailScreen> createState() =>
      _LibraryMeetingDetailScreenState();
}

class _LibraryMeetingDetailScreenState extends State<LibraryMeetingDetailScreen> {
  final QuestionsService _questionsService = QuestionsService();
  final RecapsService _recapsService = RecapsService();

  bool _loading = true;
  List<AnswerItem> _myAnswers = [];
  List<RecapItem> _recaps = [];

  @override
  void initState() {
    super.initState();
    _loadLibraryData();
  }

  Future<void> _loadLibraryData() async {
    setState(() => _loading = true);

    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        showToast(context, '로그인이 필요합니다.');
        return;
      }

      _myAnswers = await _questionsService.loadMyAnswersForMeeting(
        meetingId: widget.meeting.id,
        userId: uid,
      );

      _recaps = await _recapsService.loadRecaps(widget.meeting.id);
    } catch (e) {
      if (!mounted) return;
      showToast(context, '라이브러리 상세 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meeting;
    final book = m.book;

    return Scaffold(
      appBar: AppBar(
        title: Text(m.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (book != null) ...[
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('저자: ${book.author ?? "-"}'),
                  const SizedBox(height: 16),
                ],
                const Text(
                  '내 답변',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_myAnswers.isEmpty)
                  const Text('내가 작성한 답변이 없습니다.')
                else
                  ..._myAnswers.map(
                    (a) => Card(
                      child: ListTile(
                        title: Text(a.questionText ?? '질문'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.answer),
                            if (a.createdAt != null)
                              Text(
                                formatDateTime(a.createdAt!),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                const Text(
                  'AI 요약 리스트',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_recaps.isEmpty)
                  const Text('아직 생성된 요약이 없습니다.')
                else
                  ..._recaps.map(
                    (r) => Card(
                      child: ListTile(
                        title: Text(
                          r.content.length > 60
                              ? '${r.content.substring(0, 60)}...'
                              : r.content,
                        ),
                        subtitle: r.createdAt != null
                            ? Text(formatDateTime(r.createdAt!))
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecapDetailScreen(recap: r),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}