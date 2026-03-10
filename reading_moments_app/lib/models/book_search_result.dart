class BookSearchResult {
  final String googleBookId;
  final String title;
  final String author;
  final String isbn;
  final String coverUrl;
  final String description;
  final String publisher;
  final String publishedDate;

  BookSearchResult({
    required this.googleBookId,
    required this.title,
    required this.author,
    required this.isbn,
    required this.coverUrl,
    required this.description,
    required this.publisher,
    required this.publishedDate,
  });

  factory BookSearchResult.fromJson(Map<String, dynamic> json) {
    return BookSearchResult(
      googleBookId: (json['googleBookId'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      author: (json['author'] ?? '') as String,
      isbn: (json['isbn'] ?? '') as String,
      coverUrl: (json['coverUrl'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      publisher: (json['publisher'] ?? '') as String,
      publishedDate: (json['publishedDate'] ?? '') as String,
    );
  }
}