import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/meeting_model.dart';
import 'package:reading_moments_app/models/test_account.dart';
import 'package:reading_moments_app/screens/auth/login_screen.dart';
import 'package:reading_moments_app/screens/auth/profile_bootstrap_screen.dart';
import 'package:reading_moments_app/screens/library/my_library_screen.dart';
import 'package:reading_moments_app/screens/meetings/create_meeting_screen.dart';
import 'package:reading_moments_app/screens/meetings/meeting_detail_screen.dart';
import 'package:reading_moments_app/services/meetings_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

enum MeetingsFilterType {
  all,
  hostedByMe,
}

class MeetingsListScreen extends StatefulWidget {
  const MeetingsListScreen({super.key});

  @override
  State<MeetingsListScreen> createState() => _MeetingsListScreenState();
}

class _MeetingsListScreenState extends State<MeetingsListScreen> {
  final MeetingsService _meetingsService = MeetingsService();

  bool _loading = true;
  List<MeetingModel> _meetings = [];
  MeetingsFilterType _filterType = MeetingsFilterType.all;

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  Future<void> _loadMeetings() async {
    setState(() => _loading = true);
    try {
      _meetings = await _meetingsService.loadMeetings();
    } catch (e) {
      if (!mounted) return;
      showToast(context, '모임 목록 조회 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _switchTo(TestAccount acc) async {
    try {
      await supabase.auth.signOut();
      await supabase.auth.signInWithPassword(
        email: acc.email.trim().toLowerCase(),
        password: acc.password.trim(),
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ProfileBootstrapScreen()),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      showToast(context, '계정 전환 실패: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      showToast(context, '계정 전환 실패: $e');
    }
  }

  List<MeetingModel> _getFilteredMeetings(String? currentUid) {
    switch (_filterType) {
      case MeetingsFilterType.hostedByMe:
        if (currentUid == null) return [];
        return _meetings.where((m) => m.hostId == currentUid).toList();
      case MeetingsFilterType.all:
        return _meetings;
    }
  }

  String _getEmptyMessage() {
    switch (_filterType) {
      case MeetingsFilterType.hostedByMe:
        return '내가 만든 모임이 없습니다.';
      case MeetingsFilterType.all:
        return '등록된 모임이 없습니다. 호스트가 모임을 만들어 주세요.';
    }
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SegmentedButton<MeetingsFilterType>(
        segments: const [
          ButtonSegment<MeetingsFilterType>(
            value: MeetingsFilterType.all,
            label: Text('전체 모임'),
            icon: Icon(Icons.list),
          ),
          ButtonSegment<MeetingsFilterType>(
            value: MeetingsFilterType.hostedByMe,
            label: Text('내가 만든 모임'),
            icon: Icon(Icons.person),
          ),
        ],
        selected: {_filterType},
        onSelectionChanged: (selected) {
          setState(() {
            _filterType = selected.first;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = supabase.auth.currentUser?.id;
    final filteredMeetings = _getFilteredMeetings(currentUid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('독서모임 리스트'),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyLibraryScreen()),
              );
            },
            icon: const Icon(Icons.library_books),
            tooltip: '내 라이브러리',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.switch_account),
            onSelected: (v) async {
              if (v == 'logout') {
                await _signOut();
                return;
              }
              final acc = kTestAccounts.firstWhere((a) => a.label == v);
              await _switchTo(acc);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Text('로그아웃')),
              const PopupMenuDivider(),
              ...kTestAccounts.map(
                (a) => PopupMenuItem(value: a.label, child: Text('${a.label}로 전환')),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filteredMeetings.isEmpty
                    ? Center(child: Text(_getEmptyMessage()))
                    : RefreshIndicator(
                        onRefresh: _loadMeetings,
                        child: ListView.builder(
                          itemCount: filteredMeetings.length,
                          itemBuilder: (context, i) {
                            final m = filteredMeetings[i];
                            final isHost = currentUid != null && currentUid == m.hostId;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                title: Text(m.title),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (m.book != null)
                                      Text('책: ${m.book!.title} / ${m.book!.author ?? "-"}'),
                                    Text('일시: ${formatDateTime(m.meetingDate)}'),
                                    Text('장소: ${m.location ?? "-"}'),
                                    Text('상태: ${m.status}'),
                                    if (m.hostReason != null &&
                                        m.hostReason!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text('선정 이유: ${m.hostReason!}'),
                                    ],
                                    if (isHost)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Text(
                                          '호스트',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MeetingDetailScreen(meeting: m),
                                    ),
                                  );
                                  _loadMeetings();
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateMeetingScreen()),
          );
          _loadMeetings();
        },
        label: const Text('모임 만들기'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}