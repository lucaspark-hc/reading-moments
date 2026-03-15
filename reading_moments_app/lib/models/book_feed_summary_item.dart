class BookFeedSummaryItem {
  final int bookId;
  final String bookTitle;
  final String? bookAuthor;
  final String? coverUrl;
  final String? isbn;
  final int publicSelectionCount;
  final int publicNoteCount;
  final DateTime latestCreatedAt;
  final String? previewText;
  final bool isWishlisted;

  BookFeedSummaryItem({
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.coverUrl,
    required this.isbn,
    required this.publicSelectionCount,
    required this.publicNoteCount,
    required this.latestCreatedAt,
    required this.previewText,
    required this.isWishlisted,
  });

  BookFeedSummaryItem copyWith({
    bool? isWishlisted,
  }) {
    return BookFeedSummaryItem(
      bookId: bookId,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      coverUrl: coverUrl,
      isbn: isbn,
      publicSelectionCount: publicSelectionCount,
      publicNoteCount: publicNoteCount,
      latestCreatedAt: latestCreatedAt,
      previewText: previewText,
      isWishlisted: isWishlisted ?? this.isWishlisted,
    );
  }
}