import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/book_selection_item.dart';
import 'package:reading_moments_app/services/meetings_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class CreateMeetingFromSelectionScreen extends StatefulWidget {
  final BookSelectionItem selection;

  const CreateMeetingFromSelectionScreen({
    super.key,
    required this.selection,
  });

  @override
  State<CreateMeetingFromSelectionScreen> createState() =>
      _CreateMeetingFromSelectionScreenState();
}

class _CreateMeetingFromSelectionScreenState
    extends State<CreateMeetingFromSelectionScreen> {
  final MeetingsService _meetingsService = MeetingsService();

  late final TextEditingController _meetingTitle;
  final TextEditingController _location = TextEditingController();
  final TextEditingController _maxParticipants =
      TextEditingController(text: '5');
  late final TextEditingController _hostReason;

  bool _loading = false;
  DateTime _meetingDate = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    _meetingTitle = TextEditingController(text: widget.selection.bookTitle);
    _hostReason = TextEditingController(text: widget.selection.selectionReason);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _meetingDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_meetingDate),
    );
    if (time == null || !mounted) return;

    setState(() {
      _meetingDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _saveMeeting() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      showToast(context, '로그인이 필요합니다.');
      return;
    }

    final meetingTitle = _meetingTitle.text.trim();
    final location = _location.text.trim();
    final maxParticipants = int.tryParse(_maxParticipants.text.trim()) ?? 5;
    final hostReason = _hostReason.text.trim();

    if (meetingTitle.isEmpty) {
      showToast(context, '모임 제목을 입력하세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      await _meetingsService.createMeeting(
        hostId: uid,
        bookId: widget.selection.bookId,
        title: meetingTitle,
        meetingDate: _meetingDate,
        location: location,
        maxParticipants: maxParticipants,
        hostReason: hostReason,
      );

      if (!mounted) return;
      showToast(context, '모임이 생성되었습니다.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, '모임 생성 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _meetingTitle.dispose();
    _location.dispose();
    _maxParticipants.dispose();
    _hostReason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.selection;

    return Scaffold(
      appBar: AppBar(
        title: const Text('모임 만들기'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            s.bookTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if ((s.bookAuthor ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              s.bookAuthor!,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _meetingTitle,
            decoration: const InputDecoration(
              labelText: '모임 제목',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            decoration: const InputDecoration(
              labelText: '장소',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _maxParticipants,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '최대 인원',
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('모임 일시'),
            subtitle: Text(formatDateTime(_meetingDate)),
            trailing: const Icon(Icons.calendar_month),
            onTap: _pickDateTime,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hostReason,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '선정 이유',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _saveMeeting,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('모임 개설하기'),
            ),
          ),
        ],
      ),
    );
  }
}