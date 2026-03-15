class FeedNoteItem {
  final int id;
  final String userId;
  final String nickname;
  final int bookId;
  final String bookTitle;
  final String? bookAuthor;
  final String type;
  final String? quoteText;
  final String? noteText;
  final String visibility;
  final int? page;
  final DateTime createdAt;
  final bool isSaved;
  final bool isLiked;
  final int likeCount;

  FeedNoteItem({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.type,
    required this.quoteText,
    required this.noteText,
    required this.visibility,
    required this.page,
    required this.createdAt,
    required this.isSaved,
    required this.isLiked,
    required this.likeCount,
  });

  factory FeedNoteItem.fromMap(
    Map<String, dynamic> map, {
    Set<int> savedNoteIds = const <int>{},
    Set<int> likedNoteIds = const <int>{},
    Map<int, int> likeCountMap = const <int, int>{},
  }) {
    final userMap = map['users'] as Map<String, dynamic>?;
    final bookMap = map['books'] as Map<String, dynamic>?;
    final id = map['id'] as int;

    return FeedNoteItem(
      id: id,
      userId: map['user_id'] as String,
      nickname: (userMap?['nickname'] ?? '알 수 없음') as String,
      bookId: map['book_id'] as int,
      bookTitle: (bookMap?['title'] ?? '-') as String,
      bookAuthor: bookMap?['author'] as String?,
      type: (map['type'] ?? 'quote') as String,
      quoteText: map['quote_text'] as String?,
      noteText: map['note_text'] as String?,
      visibility: (map['visibility'] ?? 'private') as String,
      page: map['page'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      isSaved: savedNoteIds.contains(id),
      isLiked: likedNoteIds.contains(id),
      likeCount: likeCountMap[id] ?? 0,
    );
  }

  FeedNoteItem copyWith({
    bool? isSaved,
    bool? isLiked,
    int? likeCount,
  }) {
    return FeedNoteItem(
      id: id,
      userId: userId,
      nickname: nickname,
      bookId: bookId,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      type: type,
      quoteText: quoteText,
      noteText: noteText,
      visibility: visibility,
      page: page,
      createdAt: createdAt,
      isSaved: isSaved ?? this.isSaved,
      isLiked: isLiked ?? this.isLiked,
      likeCount: likeCount ?? this.likeCount,
    );
  }
}