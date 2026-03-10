class BookModel {
  final int id;
  final String isbn;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? category;

  BookModel({
    required this.id,
    required this.isbn,
    required this.title,
    this.author,
    this.coverUrl,
    this.category,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id'] as int,
      isbn: (json['isbn'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      author: json['author'] as String?,
      coverUrl: json['cover_url'] as String?,
      category: json['category'] as String?,
    );
  }
}