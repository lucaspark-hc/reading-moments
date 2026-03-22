class MyRecordItem {
  final int id;
  final String userId;
  final int bookId;

  final String bookTitle;
  final String? bookAuthor;
  final String? coverUrl;

  final String type;

  final String? quoteText;
  final String? explainText;
  final String? noteText;
  final String visibility;
  final int? page;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MyRecordItem({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.coverUrl,
    required this.type,
    required this.quoteText,
    required this.explainText,
    required this.noteText,
    required this.visibility,
    required this.page,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MyRecordItem.fromMap(Map<String, dynamic> map) {
    final bookMap = map['books'] as Map<String, dynamic>?;

    return MyRecordItem(
      id: map['id'] as int,
      userId: map['user_id'] as String,
      bookId: map['book_id'] as int,
      bookTitle: (bookMap?['title'] ?? '-') as String,
      bookAuthor: bookMap?['author'] as String?,
      coverUrl: bookMap?['cover_url'] as String?,
      type: (map['type'] ?? 'quote') as String,
      quoteText: map['quote_text'] as String?,
      explainText: map['explain_text'] as String?,
      noteText: map['note_text'] as String?,
      visibility: (map['visibility'] ?? 'private') as String,
      page: map['page'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  MyRecordItem copyWith({
    String? quoteText,
    String? explainText,
    String? noteText,
    String? visibility,
    int? page,
    DateTime? updatedAt,
  }) {
    return MyRecordItem(
      id: id,
      userId: userId,
      bookId: bookId,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      coverUrl: coverUrl,
      type: type,
      quoteText: quoteText ?? this.quoteText,
      explainText: explainText ?? this.explainText,
      noteText: noteText ?? this.noteText,
      visibility: visibility ?? this.visibility,
      page: page ?? this.page,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}