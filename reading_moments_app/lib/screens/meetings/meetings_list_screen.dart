import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/meeting_model.dart';
import 'package:reading_moments_app/models/test_account.dart';
import 'package:reading_moments_app/screens/auth/login_screen.dart';
import 'package:reading_moments_app/screens/auth/profile_bootstrap_screen.dart';
import 'package:reading_moments_app/screens/feed/feed_screen.dart';
import 'package:reading_moments_app/screens/library/my_library_screen.dart';
import 'package:reading_moments_app/screens/meetings/create_meeting_screen.dart';
import 'package:reading_moments_app/screens/meetings/edit_meeting_screen.dart';
import 'package:reading_moments_app/screens/meetings/meeting_detail_screen.dart';
import 'package:reading_moments_app/screens/records/my_records_screen.dart';
import 'package:reading_moments_app/services/meetings_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';
import 'package:reading_moments_app/widgets/current_user_banner.dart';

enum MeetingsFilterType { activeAll, hostedByMe, archived }

class MeetingsListScreen extends StatefulWidget {
  const MeetingsListScreen({super.key});

  @override
  State<MeetingsListScreen> createState() => _MeetingsListScreenState();
}

class _MeetingsListScreenState extends State<MeetingsListScreen> {
  final MeetingsService _meetingsService = MeetingsService();

  bool _loading = true;
  List<MeetingModel> _meetings = [];
  MeetingsFilterType _filterType = MeetingsFilterType.activeAll;

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

  bool _isArchivedStatus(String status) {
    return status == 'closed' || status == 'finished';
  }

  bool _isActiveStatus(String status) {
    return status == 'open' || status == 'in_progress';
  }

  List<MeetingModel> _getFilteredMeetings(String? currentUid) {
    switch (_filterType) {
      case MeetingsFilterType.activeAll:
        return _meetings.where((m) => _isActiveStatus(m.status)).toList();

      case MeetingsFilterType.hostedByMe:
        if (currentUid == null) return [];
        return _meetings.where((m) => m.hostId == currentUid).toList();

      case MeetingsFilterType.archived:
        return _meetings.where((m) => _isArchivedStatus(m.status)).toList();
    }
  }

  String _getEmptyMessage() {
    switch (_filterType) {
      case MeetingsFilterType.activeAll:
        return '진행 중인 모임이 없습니다.';
      case MeetingsFilterType.hostedByMe:
        return '내가 만든 모임이 없습니다.';
      case MeetingsFilterType.archived:
        return '종료되었거나 마감된 모임이 없습니다.';
    }
  }

  Color? _getCardColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;

    switch (status) {
      case 'closed':
        return scheme.surfaceContainerHighest;
      case 'finished':
        return scheme.secondaryContainer.withValues(alpha: 0.7);
      case 'open':
      case 'in_progress':
      default:
        return null;
    }
  }

  Color _getStatusColor(MeetingModel meeting) {
    final badge = meeting.badgeText ?? '';

    switch (badge) {
      case '신청중':
        return Colors.orange;
      case '참여중':
        return Colors.green;
      case '거절됨':
        return Colors.red;
    }

    switch (meeting.status) {
      case 'closed':
        return Colors.orange;
      case 'finished':
        return Colors.green;
      case 'in_progress':
        return Colors.teal;
      case 'open':
      default:
        return Colors.blue;
    }
  }

  String _getStatusLabel(MeetingModel meeting) {
    if (meeting.badgeText != null && meeting.badgeText!.trim().isNotEmpty) {
      return meeting.badgeText!;
    }

    switch (meeting.status) {
      case 'closed':
        return '마감';
      case 'finished':
        return '종료';
      case 'in_progress':
        return '진행중';
      case 'open':
      default:
        return '모집중';
    }
  }

  Widget _buildStatusChip(MeetingModel meeting) {
    final color = _getStatusColor(meeting);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _getStatusLabel(meeting),
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SegmentedButton<MeetingsFilterType>(
        segments: const [
          ButtonSegment<MeetingsFilterType>(
            value: MeetingsFilterType.activeAll,
            label: Text('전체 모임'),
            icon: Icon(Icons.list),
          ),
          ButtonSegment<MeetingsFilterType>(
            value: MeetingsFilterType.hostedByMe,
            label: Text('내가 만든 모임'),
            icon: Icon(Icons.person),
          ),
          ButtonSegment<MeetingsFilterType>(
            value: MeetingsFilterType.archived,
            label: Text('종료/마감'),
            icon: Icon(Icons.archive_outlined),
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

  Future<void> _editMeeting(MeetingModel meeting) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditMeetingScreen(meeting: meeting)),
    );

    if (updated == true) {
      await _loadMeetings();
    }
  }

  Future<void> _deleteMeeting(MeetingModel meeting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('모임 삭제'),
          content: Text('정말 "${meeting.title}" 모임을 삭제하시겠습니까?'),
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

    try {
      await _meetingsService.deleteMeeting(meeting.id);
      if (!mounted) return;
      showToast(context, '모임이 삭제되었습니다.');
      await _loadMeetings();
    } catch (e) {
      if (!mounted) return;
      showToast(context, '모임 삭제 실패: $e');
    }
  }

  PopupMenuButton<String>? _buildHostMenu(MeetingModel meeting, bool isHost) {
    if (!isHost) return null;

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      onSelected: (value) async {
        if (value == 'edit') {
          await _editMeeting(meeting);
          return;
        }
        if (value == 'delete') {
          await _deleteMeeting(meeting);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'edit', child: Text('수정')),
        PopupMenuItem(value: 'delete', child: Text('삭제')),
      ],
    );
  }

  Widget _buildMeetingCard(
    BuildContext context,
    MeetingModel meeting,
    bool isHost,
  ) {
    return Card(
      color: _getCardColor(context, meeting.status),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MeetingDetailScreen(meeting: meeting),
            ),
          );
          _loadMeetings();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      meeting.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(meeting),
                  if (isHost) ...[
                    const SizedBox(width: 4),
                    _buildHostMenu(meeting, isHost)!,
                  ],
                ],
              ),
              const SizedBox(height: 10),
              if (meeting.book != null)
                Text(
                  '책: ${meeting.book!.title} / ${meeting.book!.author ?? "-"}',
                ),
              Text('일시: ${formatDateTime(meeting.meetingDate)}'),
              Text('장소: ${meeting.location ?? "-"}'),
              if (meeting.hostReason != null &&
                  meeting.hostReason!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('선정 이유: ${meeting.hostReason!}'),
              ],
              if (isHost) ...[
                const SizedBox(height: 6),
                const Text(
                  '호스트',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
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
                MaterialPageRoute(builder: (_) => const FeedScreen()),
              );
            },
            icon: const Icon(Icons.dynamic_feed),
            tooltip: '공개 피드',
          ),
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyRecordsScreen()),
              );
            },
            icon: const Icon(Icons.edit_note),
            tooltip: '내 기록',
          ),
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
                (a) => PopupMenuItem(
                  value: a.label,
                  child: Text('${a.label}로 전환'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const CurrentUserBanner(),
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
                        final meeting = filteredMeetings[i];
                        final isHost =
                            meeting.isHost ||
                            (currentUid != null &&
                                currentUid == meeting.hostId);

                        return _buildMeetingCard(context, meeting, isHost);
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
        label: const Text('책 고르기'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
