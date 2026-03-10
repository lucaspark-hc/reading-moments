import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/meeting_model.dart';
import 'package:reading_moments_app/screens/library/library_meeting_detail_screen.dart';
import 'package:reading_moments_app/services/meetings_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class MyLibraryScreen extends StatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  final MeetingsService _meetingsService = MeetingsService();
  bool _loading = true;
  List<MeetingModel> _meetings = [];

  @override
  void initState() {
    super.initState();
    _loadLibraryMeetings();
  }

  Future<void> _loadLibraryMeetings() async {
    setState(() => _loading = true);
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        showToast(context, '로그인이 필요합니다.');
        return;
      }

      _meetings = await _meetingsService.loadLibraryMeetings(uid);
    } catch (e) {
      if (!mounted) return;
      showToast(context, '내 라이브러리 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 라이브러리'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _meetings.isEmpty
              ? const Center(child: Text('참여 중이거나 호스트인 모임이 없습니다.'))
              : RefreshIndicator(
                  onRefresh: _loadLibraryMeetings,
                  child: ListView.builder(
                    itemCount: _meetings.length,
                    itemBuilder: (context, i) {
                      final m = _meetings[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(m.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (m.book != null)
                                Text('책: ${m.book!.title} / ${m.book!.author ?? "-"}'),
                              Text('일시: ${formatDateTime(m.meetingDate)}'),
                              Text('상태: ${m.status}'),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LibraryMeetingDetailScreen(meeting: m),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}