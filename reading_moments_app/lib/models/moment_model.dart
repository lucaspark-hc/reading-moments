class MomentModel {
  final int id;
  final String userId;
  final int bookId;
  final int? meetingId;

  final String type;
  final String quoteText;
  final String? noteText;

  final int? page;
  final String visibility;
  final String inputMethod;

  final DateTime createdAt;
  final DateTime? updatedAt;

  MomentModel({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.meetingId,
    required this.type,
    required this.quoteText,
    required this.noteText,
    required this.page,
    required this.visibility,
    required this.inputMethod,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MomentModel.fromJson(Map<String, dynamic> json) {
    return MomentModel(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      bookId: json['book_id'] as int,
      meetingId: json['meeting_id'] as int?,
      type: (json['type'] ?? 'quote') as String,
      quoteText: (json['quote_text'] ?? '') as String,
      noteText: json['note_text'] as String?,
      page: json['page'] as int?,
      visibility: (json['visibility'] ?? 'private') as String,
      inputMethod: (json['input_method'] ?? 'manual') as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'meeting_id': meetingId,
      'type': type,
      'quote_text': quoteText,
      'note_text': noteText,
      'page': page,
      'visibility': visibility,
      'input_method': inputMethod,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  MomentModel copyWith({
    int? id,
    String? userId,
    int? bookId,
    int? meetingId,
    String? type,
    String? quoteText,
    String? noteText,
    int? page,
    String? visibility,
    String? inputMethod,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MomentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      meetingId: meetingId ?? this.meetingId,
      type: type ?? this.type,
      quoteText: quoteText ?? this.quoteText,
      noteText: noteText ?? this.noteText,
      page: page ?? this.page,
      visibility: visibility ?? this.visibility,
      inputMethod: inputMethod ?? this.inputMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
