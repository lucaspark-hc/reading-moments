import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:reading_moments_app/core/env.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/book_search_result.dart';

class BooksService {
  Future<List<BookSearchResult>> searchBooks(String query) async {
    final encodedQuery = Uri.encodeQueryComponent(query.trim());
    final url = Uri.parse('$apiBaseUrl/books/search?q=$encodedQuery');

    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception('책 검색 실패: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final books = data['books'];

    if (books is! List) {
      throw Exception('책 검색 응답 형식 오류');
    }

    return books
        .map((e) => BookSearchResult.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<String> generateDescription({
    required String title,
    required String author,
    required String publisher,
    required String publishedDate,
  }) async {
    final url = Uri.parse('$apiBaseUrl/books/generate-description');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'author': author,
        'publisher': publisher,
        'publishedDate': publishedDate,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('책 소개 생성 실패: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['description'] ?? '').toString();
  }

  Future<String> generateReason({
    required String title,
    required String author,
    required String description,
  }) async {
    final url = Uri.parse('$apiBaseUrl/books/generate-reason');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'author': author,
        'description': description,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('선정 이유 생성 실패: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['reason'] ?? '').toString();
  }

  Future<int> findOrCreateBook({
    required String isbn,
    required String title,
    required String author,
    required String description,
    String? coverUrl,
  }) async {
    if (isbn.isEmpty || title.isEmpty) {
      throw Exception('책 정보가 올바르지 않습니다.');
    }

    final existing = await supabase
        .from('books')
        .select('id')
        .eq('isbn', isbn)
        .maybeSingle();

    if (existing != null) {
      final existingId = existing['id'] as int;

      await supabase.from('books').update({
        'title': title,
        'author': author.isEmpty ? null : author,
        'cover_url': coverUrl,
        'description': description.isEmpty ? null : description,
      }).eq('id', existingId);

      return existingId;
    }

    final inserted = await supabase
        .from('books')
        .insert({
          'isbn': isbn,
          'title': title,
          'author': author.isEmpty ? null : author,
          'cover_url': coverUrl,
          'description': description.isEmpty ? null : description,
        })
        .select('id')
        .single();

    return inserted['id'] as int;
  }
}