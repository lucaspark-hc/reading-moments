import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/meeting_model.dart';
import 'package:reading_moments_app/models/participant_item.dart';

class MeetingsService {
  Future<List<MeetingModel>> loadMeetings() async {
    final rows = await supabase
        .from('meetings')
        .select('''
          id,
          host_id,
          book_id,
          title,
          meeting_date,
          location,
          max_participants,
          status,
          host_reason,
          created_at,
          books (
            id,
            isbn,
            title,
            author,
            cover_url,
            category
          )
        ''')
        .order('meeting_date', ascending: true);

    return (rows as List)
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
    await supabase.from('meetings').update({
      'title': title,
      'meeting_date': meetingDate.toUtc().toIso8601String(),
      'location': location.isEmpty ? null : location,
      'max_participants': maxParticipants,
      'host_reason': hostReason.isEmpty ? null : hostReason,
      'status': status,
    }).eq('id', meetingId);
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
    await supabase.from('meeting_participants').upsert({
      'meeting_id': meetingId,
      'user_id': userId,
      'status': 'requested',
      'requested_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> approveParticipant(int participantId) async {
    await supabase.from('meeting_participants').update({
      'status': 'approved',
      'approved_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', participantId);
  }

  Future<void> rejectParticipant(int participantId) async {
    await supabase.from('meeting_participants').update({
      'status': 'rejected',
    }).eq('id', participantId);
  }

  Future<List<MeetingModel>> loadLibraryMeetings(String userId) async {
    final hostedRows = await supabase
        .from('meetings')
        .select('''
          id,
          host_id,
          book_id,
          title,
          meeting_date,
          location,
          max_participants,
          status,
          host_reason,
          created_at,
          books (
            id,
            isbn,
            title,
            author,
            cover_url,
            category
          )
        ''')
        .eq('host_id', userId);

    final participantRows = await supabase
        .from('meeting_participants')
        .select('meeting_id')
        .eq('user_id', userId)
        .eq('status', 'approved');

    final participantMeetingIds =
        (participantRows as List).map((e) => e['meeting_id'] as int).toSet().toList();

    List<dynamic> approvedRows = [];
    if (participantMeetingIds.isNotEmpty) {
      approvedRows = await supabase
          .from('meetings')
          .select('''
            id,
            host_id,
            book_id,
            title,
            meeting_date,
            location,
            max_participants,
            status,
            host_reason,
            created_at,
            books (
              id,
              isbn,
              title,
              author,
              cover_url,
              category
            )
          ''')
          .inFilter('id', participantMeetingIds);
    }

    final map = <int, MeetingModel>{};

    for (final row in hostedRows as List) {
      final m = MeetingModel.fromJson(Map<String, dynamic>.from(row));
      map[m.id] = m;
    }

    for (final row in approvedRows) {
      final m = MeetingModel.fromJson(Map<String, dynamic>.from(row));
      map[m.id] = m;
    }

    final list = map.values.toList()
      ..sort((a, b) => b.meetingDate.compareTo(a.meetingDate));

    return list;
  }
}