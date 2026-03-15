import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:reading_moments_app/core/env.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/meeting_model.dart';
import 'package:reading_moments_app/models/participant_item.dart';

class MeetingsService {
  String get _baseUrl => apiBaseUrl;

  Future<List<MeetingModel>> loadMeetings() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final uri = Uri.parse('$_baseUrl/meetings?userId=$userId');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('모임 목록 조회 실패 (${response.statusCode}) ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (decoded['items'] as List? ?? []);

    return items
        .map((e) => MeetingModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> createMeeting({
    required String hostId,
    required int bookId,
    required String title,
    required DateTime meetingDate,
    required String location,
    required int maxParticipants,
    required String hostReason,
  }) async {
    await supabase.from('meetings').insert({
      'host_id': hostId,
      'book_id': bookId,
      'title': title,
      'meeting_date': meetingDate.toUtc().toIso8601String(),
      'location': location.isEmpty ? null : location,
      'max_participants': maxParticipants,
      'status': 'open',
      'host_reason': hostReason.isEmpty ? null : hostReason,
    });
  }

  Future<void> updateMeeting({
    required int meetingId,
    required String title,
    required DateTime meetingDate,
    required String location,
    required int maxParticipants,
    required String hostReason,
    required String status,
  }) async {
    await supabase
        .from('meetings')
        .update({
          'title': title,
          'meeting_date': meetingDate.toUtc().toIso8601String(),
          'location': location.isEmpty ? null : location,
          'max_participants': maxParticipants,
          'host_reason': hostReason.isEmpty ? null : hostReason,
          'status': status,
        })
        .eq('id', meetingId);
  }

  Future<void> deleteMeeting(int meetingId) async {
    await supabase.from('meetings').delete().eq('id', meetingId);
  }

  Future<String?> loadMyParticipantStatus(int meetingId, String userId) async {
    final row = await supabase
        .from('meeting_participants')
        .select('status')
        .eq('meeting_id', meetingId)
        .eq('user_id', userId)
        .maybeSingle();

    return row?['status'] as String?;
  }

  Future<List<ParticipantItem>> loadRequestedParticipants(int meetingId) async {
    final rows = await supabase
        .from('meeting_participants')
        .select('''
          id,
          meeting_id,
          user_id,
          status,
          requested_at,
          approved_at,
          users (
            nickname
          )
        ''')
        .eq('meeting_id', meetingId)
        .eq('status', 'requested')
        .order('requested_at', ascending: true);

    return (rows as List)
        .map((e) => ParticipantItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> requestJoin({
    required int meetingId,
    required String userId,
  }) async {
    final uri = Uri.parse('$_baseUrl/meetings/$meetingId/apply');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );

    if (response.statusCode != 200) {
      throw Exception('참여 신청 실패 (${response.statusCode}) ${response.body}');
    }
  }

  Future<void> approveParticipant({
    required int meetingId,
    required String participantUserId,
    required String hostUserId,
  }) async {
    final uri = Uri.parse('$_baseUrl/meetings/$meetingId/approve');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'participantUserId': participantUserId,
        'hostUserId': hostUserId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('승인 실패 (${response.statusCode}) ${response.body}');
    }
  }

  Future<void> rejectParticipant({
    required int meetingId,
    required String participantUserId,
    required String hostUserId,
  }) async {
    final uri = Uri.parse('$_baseUrl/meetings/$meetingId/reject');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'participantUserId': participantUserId,
        'hostUserId': hostUserId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('거절 실패 (${response.statusCode}) ${response.body}');
    }
  }

  Future<List<MeetingModel>> loadLibraryMeetings(String userId) async {
    final uri = Uri.parse('$_baseUrl/meetings/my-active?userId=$userId');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        '진행중인 모임 조회 실패 (${response.statusCode}) ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (decoded['items'] as List? ?? []);

    return items
        .map((e) => MeetingModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
