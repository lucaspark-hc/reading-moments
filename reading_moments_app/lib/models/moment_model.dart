class MomentModel {
  final int id;
  final String userId;
  final int bookId;
  final int? meetingId;
  final String? quoteText;
  final String? explainText;
  final String? noteText;
  final int? page;
  final String visibility;
  final String type;
  final String inputMethod;
  final int likeCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MomentModel({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.meetingId,
    required this.quoteText,
    required this.explainText,
    required this.noteText,
    required this.page,
    required this.visibility,
    required this.type,
    required this.inputMethod,
    required this.likeCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MomentModel.fromJson(Map<String, dynamic> json) {
    return MomentModel(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      bookId: json['book_id'] as int,
      meetingId: json['meeting_id'] as int?,
      quoteText: json['quote_text'] as String?,
      explainText: json['explain_text'] as String?,
      noteText: json['note_text'] as String?,
      page: json['page'] as int?,
      visibility: (json['visibility'] ?? 'private') as String,
      type: (json['type'] ?? 'quote') as String,
      inputMethod: (json['input_method'] ?? 'manual') as String,
      likeCount: (json['like_count'] ?? 0) as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}