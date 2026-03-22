class FeedMomentItem {
  final int id;
  final String userId;
  final String nickname;
  final int bookId;
  final String bookTitle;
  final String? bookAuthor;
  final String? coverUrl;
  final String type;
  final String? quoteText;
  final String? thoughtText;
  final String visibility;
  final int? page;
  final DateTime createdAt;
  final bool userLiked;
  final int likeCount;
  final bool isBookWishlisted;

  FeedMomentItem({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.coverUrl,
    required this.type,
    required this.quoteText,
    required this.thoughtText,
    required this.visibility,
    required this.page,
    required this.createdAt,
    required this.userLiked,
    required this.likeCount,
    required this.isBookWishlisted,
  });

  factory FeedMomentItem.fromMap(
    Map<String, dynamic> map, {
    Set<int> likedMomentIds = const <int>{},
    Set<int> wishlistedBookIds = const <int>{},
  }) {
    final userMap = map['users'] as Map<String, dynamic>?;
    final bookMap = map['books'] as Map<String, dynamic>?;
    final id = (map['id'] as num).toInt();
    final bookId = (map['book_id'] as num).toInt();

    return FeedMomentItem(
      id: id,
      userId: map['user_id'] as String,
      nickname: (userMap?['nickname'] ?? '알 수 없음') as String,
      bookId: bookId,
      bookTitle: (bookMap?['title'] ?? '-') as String,
      bookAuthor: bookMap?['author'] as String?,
      coverUrl: bookMap?['cover_url'] as String?,
      type: (map['type'] ?? 'quote') as String,
      quoteText: map['quote_text'] as String?,
      thoughtText: map['note_text'] as String?,
      visibility: (map['visibility'] ?? 'private') as String,
      page: map['page'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      userLiked: likedMomentIds.contains(id),
      likeCount: ((map['like_count'] ?? 0) as num).toInt(),
      isBookWishlisted: wishlistedBookIds.contains(bookId),
    );
  }

  FeedMomentItem copyWith({
    bool? userLiked,
    int? likeCount,
    bool? isBookWishlisted,
  }) {
    return FeedMomentItem(
      id: id,
      userId: userId,
      nickname: nickname,
      bookId: bookId,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      coverUrl: coverUrl,
      type: type,
      quoteText: quoteText,
      thoughtText: thoughtText,
      visibility: visibility,
      page: page,
      createdAt: createdAt,
      userLiked: userLiked ?? this.userLiked,
      likeCount: likeCount ?? this.likeCount,
      isBookWishlisted: isBookWishlisted ?? this.isBookWishlisted,
    );
  }
}