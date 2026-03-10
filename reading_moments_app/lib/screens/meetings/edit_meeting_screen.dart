import 'package:flutter/material.dart';
import 'package:reading_moments_app/models/meeting_model.dart';
import 'package:reading_moments_app/services/meetings_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class EditMeetingScreen extends StatefulWidget {
  final MeetingModel meeting;

  const EditMeetingScreen({
    super.key,
    required this.meeting,
  });

  @override
  State<EditMeetingScreen> createState() => _EditMeetingScreenState();
}

class _EditMeetingScreenState extends State<EditMeetingScreen> {
  final MeetingsService _meetingsService = MeetingsService();

  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _maxParticipantsController;
  late final TextEditingController _hostReasonController;

  bool _saving = false;
  late DateTime _meetingDate;
  late String _status;

  final List<String> _statusOptions = ['open', 'closed', 'finished'];

  @override
  void initState() {
    super.initState();
    final meeting = widget.meeting;

    _titleController = TextEditingController(text: meeting.title);
    _locationController = TextEditingController(text: meeting.location ?? '');
    _maxParticipantsController =
        TextEditingController(text: meeting.maxParticipants.toString());
    _hostReasonController = TextEditingController(text: meeting.hostReason ?? '');
    _meetingDate = meeting.meetingDate.toLocal();
    _status = meeting.status;
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _meetingDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
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

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final location = _locationController.text.trim();
    final maxParticipants = int.tryParse(_maxParticipantsController.text.trim()) ?? 0;
    final hostReason = _hostReasonController.text.trim();

    if (title.isEmpty) {
      showToast(context, '모임 제목을 입력하세요.');
      return;
    }

    if (maxParticipants <= 0) {
      showToast(context, '최대 인원은 1명 이상이어야 합니다.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _meetingsService.updateMeeting(
        meetingId: widget.meeting.id,
        title: title,
        meetingDate: _meetingDate,
        location: location,
        maxParticipants: maxParticipants,
        hostReason: hostReason,
        status: _status,
      );

      if (!mounted) return;
      showToast(context, '모임이 수정되었습니다.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, '모임 수정 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _maxParticipantsController.dispose();
    _hostReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.meeting.book;

    return Scaffold(
      appBar: AppBar(
        title: const Text('모임 수정'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (book != null) ...[
            Text(
              book.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('저자: ${book.author ?? "-"}'),
            const SizedBox(height: 20),
          ],
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '모임 제목'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            decoration: const InputDecoration(labelText: '장소'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _maxParticipantsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '최대 인원'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _status,
            items: _statusOptions
                .map(
                  (status) => DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _status = value;
              });
            },
            decoration: const InputDecoration(labelText: '상태'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('모임 일시'),
            subtitle: Text(formatDateTime(_meetingDate)),
            trailing: const Icon(Icons.calendar_month),
            onTap: _pickDateTime,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hostReasonController,
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
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('수정 저장'),
            ),
          ),
        ],
      ),
    );
  }
}