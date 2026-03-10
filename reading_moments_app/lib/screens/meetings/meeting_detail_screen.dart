import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/meeting_model.dart';
import 'package:reading_moments_app/models/participant_item.dart';
import 'package:reading_moments_app/models/question_item.dart';
import 'package:reading_moments_app/models/recap_item.dart';
import 'package:reading_moments_app/screens/meetings/question_detail_screen.dart';
import 'package:reading_moments_app/screens/recaps/recap_detail_screen.dart';
import 'package:reading_moments_app/services/meetings_service.dart';
import 'package:reading_moments_app/services/questions_service.dart';
import 'package:reading_moments_app/services/recaps_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class MeetingDetailScreen extends StatefulWidget {
  final MeetingModel meeting;

  const MeetingDetailScreen({super.key, required this.meeting});

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  final MeetingsService _meetingsService = MeetingsService();
  final QuestionsService _questionsService = QuestionsService();
  final RecapsService _recapsService = RecapsService();

  bool _loadingQuestions = false;
  bool _loadingParticipants = false;
  bool _loadingRecap = false;
  bool _loadingRecaps = false;

  List<QuestionItem> _questions = [];
  List<ParticipantItem> _requestedParticipants = [];
  List<RecapItem> _recaps = [];
  String? _myParticipantStatus;

  bool get _isHost => supabase.auth.currentUser?.id == widget.meeting.hostId;
  bool get _isApprovedParticipant => _myParticipantStatus == 'approved';
  bool get _canViewQuestions => _isHost || _isApprovedParticipant;
  bool get _canAnswerQuestions => _isHost || _isApprovedParticipant;
  bool get _canRequestJoin =>
      !_isHost && (_myParticipantStatus == null || _myParticipantStatus == 'rejected');

  bool get _canGenerateMeetingRecap => _isHost && widget.meeting.status == 'finished';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadMyParticipantStatus(),
      _loadQuestions(),
      _loadRecaps(),
      if (_isHost) _loadRequestedParticipants(),
    ]);
  }

  Future<void> _loadMyParticipantStatus() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;

      final status = await _meetingsService.loadMyParticipantStatus(widget.meeting.id, uid);
      if (!mounted) return;
      setState(() {
        _myParticipantStatus = status;
      });
    } catch (e) {
      if (!mounted) return;
      showToast(context, '참여 상태 조회 실패: $e');
    }
  }

  Future<void> _loadRequestedParticipants() async {
    setState(() => _loadingParticipants = true);
    try {
      _requestedParticipants =
          await _meetingsService.loadRequestedParticipants(widget.meeting.id);
    } catch (e) {
      if (!mounted) return;
      showToast(context, '신청자 목록 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingParticipants = false);
    }
  }

  Future<void> _loadQuestions() async {
    setState(() => _loadingQuestions = true);
    try {
      _questions = await _questionsService.loadQuestions(widget.meeting.id);
    } catch (e) {
      if (!mounted) return;
      showToast(context, '질문 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingQuestions = false);
    }
  }

  Future<void> _loadRecaps() async {
    setState(() => _loadingRecaps = true);
    try {
      _recaps = await _recapsService.loadRecaps(widget.meeting.id);
    } catch (e) {
      if (!mounted) return;
      showToast(context, '모임요약 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingRecaps = false);
    }
  }

  Future<void> _requestJoin() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      showToast(context, '로그인이 필요합니다.');
      return;
    }

    try {
      await _meetingsService.requestJoin(meetingId: widget.meeting.id, userId: uid);
      if (!mounted) return;
      showToast(context, '참여 신청이 완료되었습니다.');
      await _loadMyParticipantStatus();
    } catch (e) {
      if (!mounted) return;
      showToast(context, '참여 신청 실패: $e');
    }
  }

  Future<void> _approveParticipant(ParticipantItem p) async {
    try {
      await _meetingsService.approveParticipant(p.id);
      if (!mounted) return;
      showToast(context, '승인 완료');
      await _loadRequestedParticipants();
    } catch (e) {
      if (!mounted) return;
      showToast(context, '승인 실패: $e');
    }
  }

  Future<void> _rejectParticipant(ParticipantItem p) async {
    try {
      await _meetingsService.rejectParticipant(p.id);
      if (!mounted) return;
      showToast(context, '거절 완료');
      await _loadRequestedParticipants();
    } catch (e) {
      if (!mounted) return;
      showToast(context, '거절 실패: $e');
    }
  }

  Future<void> _generateQuestions() async {
    if (!_isHost) {
      showToast(context, '호스트만 질문을 생성할 수 있습니다.');
      return;
    }

    final book = widget.meeting.book;
    if (book == null) {
      showToast(context, '책 정보가 없습니다.');
      return;
    }

    setState(() => _loadingQuestions = true);
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        showToast(context, '로그인이 필요합니다.');
        return;
      }

      await _questionsService.generateQuestions(
        meetingId: widget.meeting.id,
        bookTitle: book.title,
        author: book.author ?? '',
        hostUserId: currentUser.id,
      );

      if (!mounted) return;
      showToast(context, '질문 생성 완료');
      await _loadQuestions();
    } catch (e) {
      if (!mounted) return;
      showToast(context, '질문 생성 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingQuestions = false);
    }
  }

  Future<void> _addQuestion() async {
    if (!_isHost) {
      showToast(context, '호스트만 질문을 추가할 수 있습니다.');
      return;
    }

    final controller = TextEditingController();

    final questionText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('질문 추가'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '추가할 질문을 입력하세요.',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    if (questionText == null) return;
    if (questionText.isEmpty) {
      if (!mounted) return;
      showToast(context, '질문을 입력하세요.');
      return;
    }

    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        showToast(context, '로그인이 필요합니다.');
        return;
      }

      await _questionsService.addQuestion(
        meetingId: widget.meeting.id,
        userId: uid,
        question: questionText,
      );

      if (!mounted) return;
      showToast(context, '질문이 추가되었습니다.');
      await _loadQuestions();
    } catch (e) {
      if (!mounted) return;
      showToast(context, '질문 추가 실패: $e');
    }
  }

  Future<void> _editQuestion(QuestionItem q) async {
    if (!_isHost) {
      showToast(context, '호스트만 질문을 수정할 수 있습니다.');
      return;
    }

    final controller = TextEditingController(text: q.question);

    final updatedText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('질문 수정'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '질문을 입력하세요.',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    if (updatedText == null) return;
    if (updatedText.isEmpty) {
      if (!mounted) return;
      showToast(context, '질문을 입력하세요.');
      return;
    }

    try {
      await _questionsService.editQuestion(questionId: q.id, question: updatedText);
      if (!mounted) return;
      showToast(context, '질문 수정 완료');
      await _loadQuestions();
    } catch (e) {
      if (!mounted) return;
      showToast(context, '질문 수정 실패: $e');
    }
  }

  Future<void> _generateRecap() async {
    if (!_canGenerateMeetingRecap) {
      showToast(context, '모임 완료(finished) 상태에서만 모임요약을 생성할 수 있습니다.');
      return;
    }

    setState(() => _loadingRecap = true);
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        showToast(context, '로그인이 필요합니다.');
        return;
      }

      final recap = await _recapsService.generateRecap(
        meetingId: widget.meeting.id,
        hostUserId: currentUser.id,
      );

      if (!mounted) return;
      showToast(context, '모임요약 생성 완료');
      await _loadRecaps();

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecapDetailScreen(recap: recap),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showToast(context, '모임요약 생성 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingRecap = false);
    }
  }

  Future<void> _openLatestRecap() async {
    await _loadRecaps();
    if (_recaps.isEmpty) {
      if (!mounted) return;
      showToast(context, '생성된 모임요약이 없습니다.');
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecapDetailScreen(recap: _recaps.first),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meeting;
    final book = m.book;

    return Scaffold(
      appBar: AppBar(
        title: Text(m.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (book != null) ...[
            Text(
              book.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('저자: ${book.author ?? "-"}'),
            Text('ISBN: ${book.isbn}'),
            const SizedBox(height: 16),
          ],
          Text('모임 제목: ${m.title}'),
          const SizedBox(height: 4),
          Text('일시: ${formatDateTime(m.meetingDate)}'),
          if (m.hostReason != null && m.hostReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('선정 이유: ${m.hostReason!}'),
          ],
          Text('장소: ${m.location ?? "-"}'),
          Text('상태: ${m.status}'),
          const SizedBox(height: 8),
          if (_isHost)
            const Text(
              '현재 로그인 사용자는 이 모임의 호스트입니다.',
              style: TextStyle(fontWeight: FontWeight.bold),
            )
          else
            Text('내 참여 상태: ${_myParticipantStatus ?? "미신청"}'),
          const SizedBox(height: 16),
          if (!_isHost) ...[
            if (_canRequestJoin)
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _requestJoin,
                  child: const Text('참여 신청'),
                ),
              )
            else if (_myParticipantStatus == 'requested')
              const Text('승인 대기중입니다.')
            else if (_myParticipantStatus == 'approved')
              const Text('이 모임에 참여 중입니다.'),
            const SizedBox(height: 24),
          ],
          if (_isHost) ...[
            const Text(
              '참여 신청자',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_loadingParticipants)
              const Center(child: CircularProgressIndicator())
            else if (_requestedParticipants.isEmpty)
              const Text('대기 중인 신청자가 없습니다.')
            else
              ..._requestedParticipants.map(
                (p) => Card(
                  child: ListTile(
                    title: Text(p.nickname ?? p.userId),
                    subtitle: Text(
                      '신청일: ${p.requestedAt != null ? formatDateTime(p.requestedAt!) : "-"}',
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => _approveParticipant(p),
                          child: const Text('승인'),
                        ),
                        TextButton(
                          onPressed: () => _rejectParticipant(p),
                          child: const Text('거절'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
          Row(
            children: [
              const Expanded(
                child: Text(
                  '모임요약',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isHost && !_canGenerateMeetingRecap) ...[
            const Text(
              '모임요약은 모임 상태가 finished 일 때 생성할 수 있습니다.',
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _loadingRecap ? null : (_canGenerateMeetingRecap ? _generateRecap : null),
                    icon: const Icon(Icons.auto_awesome),
                    label: _loadingRecap
                        ? const Text('생성 중...')
                        : const Text('생성'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _loadingRecaps ? null : _openLatestRecap,
                    icon: const Icon(Icons.article),
                    label: Text(_recaps.isEmpty ? '보기' : '보기 (${_recaps.length})'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '토론 질문',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: _loadingQuestions ? null : _loadQuestions,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_canViewQuestions)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('질문은 승인된 참여자와 호스트만 볼 수 있습니다.'),
            )
          else if (_loadingQuestions)
            const Center(child: CircularProgressIndicator())
          else if (_questions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('등록된 질문이 없습니다.')),
            )
          else
            ..._questions.map(
              (q) => Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: Text(q.question),
                  subtitle: q.createdAt != null
                      ? Text('생성일: ${formatDateTime(q.createdAt!)}')
                      : null,
                  trailing: _isHost
                      ? IconButton(
                          onPressed: () => _editQuestion(q),
                          icon: const Icon(Icons.edit),
                          tooltip: '질문 수정',
                        )
                      : null,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuestionDetailScreen(
                          meeting: m,
                          question: q,
                          isHost: _isHost,
                          canAnswer: _canAnswerQuestions,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isHost
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'generate_questions',
                  onPressed: _loadingQuestions ? null : _generateQuestions,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI 질문 생성'),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'add_question',
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add),
                  label: const Text('질문 추가'),
                ),
              ],
            )
          : null,
    );
  }
}