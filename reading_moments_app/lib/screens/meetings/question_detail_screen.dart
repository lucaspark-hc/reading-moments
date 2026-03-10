import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/answer_item.dart';
import 'package:reading_moments_app/models/meeting_model.dart';
import 'package:reading_moments_app/models/question_item.dart';
import 'package:reading_moments_app/services/questions_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class QuestionDetailScreen extends StatefulWidget {
  final MeetingModel meeting;
  final QuestionItem question;
  final bool isHost;
  final bool canAnswer;

  const QuestionDetailScreen({
    super.key,
    required this.meeting,
    required this.question,
    required this.isHost,
    required this.canAnswer,
  });

  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen> {
  final QuestionsService _questionsService = QuestionsService();
  final _answerController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  List<AnswerItem> _answers = [];
  AnswerItem? _myAnswer;

  @override
  void initState() {
    super.initState();
    _loadAnswers();
  }

  Future<void> _loadAnswers() async {
    setState(() => _loading = true);
    try {
      final answers = await _questionsService.loadAnswers(widget.question.id);
      final myUid = supabase.auth.currentUser?.id;
      final myAnswer = answers
          .where((a) => a.userId == myUid)
          .cast<AnswerItem?>()
          .firstWhere((a) => a != null, orElse: () => null);

      _answers = answers;
      _myAnswer = myAnswer;
      _answerController.text = myAnswer?.answer ?? '';
    } catch (e) {
      if (!mounted) return;
      showToast(context, '답변 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAnswer() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      showToast(context, '로그인이 필요합니다.');
      return;
    }

    /// 호스트 또는 승인 참여자만 답변 가능
    if (!(widget.isHost || widget.canAnswer)) {
      showToast(context, '호스트 또는 승인된 참여자만 답변을 작성할 수 있습니다.');
      return;
    }

    final text = _answerController.text.trim();
    if (text.isEmpty) {
      showToast(context, '답변을 입력하세요.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _questionsService.saveAnswer(
        myAnswer: _myAnswer,
        questionId: widget.question.id,
        meetingId: widget.meeting.id,
        userId: uid,
        answer: text,
      );

      if (!mounted) return;
      showToast(context, '답변 저장 완료');
      await _loadAnswers();
    } catch (e) {
      if (!mounted) return;
      showToast(context, '답변 저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = widget.isHost || widget.canAnswer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('질문 상세'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  widget.question.question,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                if (canWrite) ...[
                  TextField(
                    controller: _answerController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '답변',
                      border: OutlineInputBorder(),
                      hintText: '답변을 입력하세요.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _saving ? null : _saveAnswer,
                      child: _saving
                          ? const CircularProgressIndicator()
                          : const Text('답변 저장'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  const Text('답변 작성 권한이 없습니다.'),
                  const SizedBox(height: 24),
                ],
                const Text(
                  '답변 목록',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_answers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('아직 등록된 답변이 없습니다.'),
                  )
                else
                  ..._answers.map(
                    (a) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(a.nickname ?? a.userId),
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
              ],
            ),
    );
  }
}