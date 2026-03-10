class AnswerItem {
  final int id;
  final int questionId;
  final int meetingId;
  final String userId;
  final String answer;
  final DateTime? createdAt;
  final String? nickname;
  final String? questionText;

  AnswerItem({
    required this.id,
    required this.questionId,
    required this.meetingId,
    required this.userId,
    required this.answer,
    required this.createdAt,
    required this.nickname,
    required this.questionText,
  });

  factory AnswerItem.fromJson(Map<String, dynamic> json) {
    final users = json['users'];
    final questions = json['questions'];

    return AnswerItem(
      id: json['id'] as int,
      questionId: json['question_id'] as int,
      meetingId: json['meeting_id'] as int,
      userId: json['user_id'] as String,
      answer: (json['answer'] ?? '') as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      nickname: users is Map<String, dynamic>
          ? users['nickname'] as String?
          : null,
      questionText: questions is Map<String, dynamic>
          ? questions['question'] as String?
          : null,
    );
  }
}