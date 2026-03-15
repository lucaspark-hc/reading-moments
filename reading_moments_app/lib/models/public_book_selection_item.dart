class PublicBookSelectionItem {
  final int id;
  final String userId;
  final String nickname;
  final int bookId;
  final String bookTitle;
  final String? bookAuthor;
  final String? coverUrl;
  final String? isbn;
  final String? bookDescription;
  final String selectionReason;
  final String visibility;
  final int? meetingId;
  final DateTime createdAt;

  PublicBookSelectionItem({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.coverUrl,
    required this.isbn,
    required this.bookDescription,
    required this.selectionReason,
    required this.visibility,
    required this.meetingId,
    required this.createdAt,
  });

  factory PublicBookSelectionItem.fromMap(Map<String, dynamic> map) {
    final userMap = map['users'] as Map<String, dynamic>?;
    final bookMap = map['books'] as Map<String, dynamic>?;

    return PublicBookSelectionItem(
      id: map['id'] as int,
      userId: map['user_id'] as String,
      nickname: (userMap?['nickname'] ?? '알 수 없음') as String,
      bookId: map['book_id'] as int,
      bookTitle: (bookMap?['title'] ?? '-') as String,
      bookAuthor: bookMap?['author'] as String?,
      coverUrl: bookMap?['cover_url'] as String?,
      isbn: bookMap?['isbn'] as String?,
      bookDescription: map['book_description'] as String?,
      selectionReason: (map['selection_reason'] ?? '') as String,
      visibility: (map['visibility'] ?? 'private') as String,
      meetingId: map['meeting_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}