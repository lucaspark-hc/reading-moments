class RecapItem {
  final int id;
  final int meetingId;
  final String createdBy;
  final String content;
  final bool isPublic;
  final DateTime? createdAt;

  RecapItem({
    required this.id,
    required this.meetingId,
    required this.createdBy,
    required this.content,
    required this.isPublic,
    required this.createdAt,
  });

  factory RecapItem.fromJson(Map<String, dynamic> json) {
    return RecapItem(
      id: json['id'] as int,
      meetingId: json['meeting_id'] as int,
      createdBy: json['created_by'] as String,
      content: (json['content'] ?? '') as String,
      isPublic: (json['is_public'] ?? false) as bool,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}