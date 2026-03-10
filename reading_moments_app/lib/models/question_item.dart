class QuestionItem {
  final int id;
  final int? meetingId;
  final String? createdBy;
  final String question;
  final DateTime? createdAt;

  QuestionItem({
    required this.id,
    required this.meetingId,
    required this.createdBy,
    required this.question,
    required this.createdAt,
  });

  factory QuestionItem.fromJson(Map<String, dynamic> json) {
    return QuestionItem(
      id: json['id'] as int,
      meetingId: json['meeting_id'] as int?,
      createdBy: json['created_by'] as String?,
      question: (json['question'] ?? '') as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}