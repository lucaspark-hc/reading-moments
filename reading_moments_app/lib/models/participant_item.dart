class ParticipantItem {
  final int id;
  final int meetingId;
  final String userId;
  final String status;
  final DateTime? requestedAt;
  final DateTime? approvedAt;
  final String? nickname;

  ParticipantItem({
    required this.id,
    required this.meetingId,
    required this.userId,
    required this.status,
    required this.requestedAt,
    required this.approvedAt,
    required this.nickname,
  });

  factory ParticipantItem.fromJson(Map<String, dynamic> json) {
    final usersJson = json['users'];

    return ParticipantItem(
      id: json['id'] as int,
      meetingId: json['meeting_id'] as int,
      userId: json['user_id'] as String,
      status: (json['status'] ?? '') as String,
      requestedAt: json['requested_at'] != null
          ? DateTime.tryParse(json['requested_at'])
          : null,
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'])
          : null,
      nickname: usersJson is Map<String, dynamic>
          ? usersJson['nickname'] as String?
          : null,
    );
  }
}