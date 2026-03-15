class MyRecordItem {
  final int id;
  final String userId;
  final int bookId;
  final String bookTitle;
  final String? bookAuthor;
  final String? coverUrl;
  final String type;
  final String? quoteText;
  final String? noteText;
  final String visibility;
  final int? page;
  final DateTime createdAt;

  MyRecordItem({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.coverUrl,
    required this.type,
    required this.quoteText,
    required this.noteText,
    required this.visibility,
    required this.page,
    required this.createdAt,
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
      noteText: map['note_text'] as String?,
      visibility: (map['visibility'] ?? 'private') as String,
      page: map['page'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  MyRecordItem copyWith({
    String? type,
    String? quoteText,
    String? noteText,
    String? visibility,
    int? page,
  }) {
    return MyRecordItem(
      id: id,
      userId: userId,
      bookId: bookId,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      coverUrl: coverUrl,
      type: type ?? this.type,
      quoteText: quoteText ?? this.quoteText,
      noteText: noteText ?? this.noteText,
      visibility: visibility ?? this.visibility,
      page: page ?? this.page,
      createdAt: createdAt,
    );
  }
}