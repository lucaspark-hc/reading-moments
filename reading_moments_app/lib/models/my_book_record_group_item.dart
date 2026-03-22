class MyBookRecordGroupItem {
  final int bookId;
  final String bookTitle;
  final String? bookAuthor;
  final String? coverUrl;
  final int totalCount;
  final int publicCount;
  final int privateCount;
  final DateTime latestCreatedAt;

  MyBookRecordGroupItem({
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.coverUrl,
    required this.totalCount,
    required this.publicCount,
    required this.privateCount,
    required this.latestCreatedAt,
  });

  MyBookRecordGroupItem copyWith({
    int? bookId,
    String? bookTitle,
    String? bookAuthor,
    String? coverUrl,
    int? totalCount,
    int? publicCount,
    int? privateCount,
    DateTime? latestCreatedAt,
  }) {
    return MyBookRecordGroupItem(
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      bookAuthor: bookAuthor ?? this.bookAuthor,
      coverUrl: coverUrl ?? this.coverUrl,
      totalCount: totalCount ?? this.totalCount,
      publicCount: publicCount ?? this.publicCount,
      privateCount: privateCount ?? this.privateCount,
      latestCreatedAt: latestCreatedAt ?? this.latestCreatedAt,
    );
  }
}