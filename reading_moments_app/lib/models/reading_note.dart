class ReadingNote {
  final int id;
  final String userId;
  final int bookId;

  /// DB 호환용 (앱에서는 사용하지 않음)
  final String type;

  final String? quoteText;
  final String? noteText;

  final String visibility;
  final int? page;

  final DateTime createdAt;
  final DateTime updatedAt;

  ReadingNote({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.type,
    required this.quoteText,
    required this.noteText,
    required this.visibility,
    required this.page,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReadingNote.fromMap(Map<String, dynamic> map) {
    return ReadingNote(
      id: map['id'] as int,
      userId: map['user_id'] as String,
      bookId: map['book_id'] as int,

      /// DB 호환 (항상 quote)
      type: (map['type'] ?? 'quote') as String,

      quoteText: map['quote_text'] as String?,
      noteText: map['note_text'] as String?,
      visibility: (map['visibility'] ?? 'private') as String,
      page: map['page'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'book_id': bookId,

      /// DB 호환
      'type': 'quote',

      'quote_text': quoteText,
      'note_text': noteText,
      'visibility': visibility,
      'page': page,
    };
  }
}