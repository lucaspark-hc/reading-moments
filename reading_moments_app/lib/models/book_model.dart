class BookModel {
  final int id;
  final String isbn;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? category;
  final String? description;
  final String? publisher;
  final String? publishedDate;

  BookModel({
    required this.id,
    required this.isbn,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.category,
    this.description,
    this.publisher,
    this.publishedDate,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id'] as int,
      isbn: (json['isbn'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      author: json['author'] as String?,
      coverUrl: json['cover_url'] as String?,
      category: json['category'] as String?,
      description: json['description'] as String?,
      publisher: json['publisher'] as String?,
      publishedDate: json['published_date'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isbn': isbn,
      'title': title,
      'author': author,
      'cover_url': coverUrl,
      'category': category,
      'description': description,
      'publisher': publisher,
      'published_date': publishedDate,
    };
  }

  BookModel copyWith({
    int? id,
    String? isbn,
    String? title,
    String? author,
    String? coverUrl,
    String? category,
    String? description,
    String? publisher,
    String? publishedDate,
  }) {
    return BookModel(
      id: id ?? this.id,
      isbn: isbn ?? this.isbn,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      category: category ?? this.category,
      description: description ?? this.description,
      publisher: publisher ?? this.publisher,
      publishedDate: publishedDate ?? this.publishedDate,
    );
  }
}
