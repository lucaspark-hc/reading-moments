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
}