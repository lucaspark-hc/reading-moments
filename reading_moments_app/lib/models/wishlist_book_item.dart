class WishlistBookItem {
  final int id;
  final int bookId;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? isbn;
  final DateTime createdAt;

  WishlistBookItem({
    required this.id,
    required this.bookId,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.isbn,
    required this.createdAt,
  });

  factory WishlistBookItem.fromMap(Map<String, dynamic> map) {
    final bookMap = map['books'] as Map<String, dynamic>?;

    return WishlistBookItem(
      id: map['id'] as int,
      bookId: map['book_id'] as int,
      title: (bookMap?['title'] ?? '-') as String,
      author: bookMap?['author'] as String?,
      coverUrl: bookMap?['cover_url'] as String?,
      isbn: bookMap?['isbn'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}