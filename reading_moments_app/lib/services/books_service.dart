import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:postgrest/postgrest.dart';
import 'package:reading_moments_app/core/env.dart';
import 'package:reading_moments_app/core/log/app_logger.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/book_search_result.dart';

class BooksService {
  Future<List<BookSearchResult>> searchBooks(String query) async {
    final encodedQuery = Uri.encodeQueryComponent(query.trim());
    final url = Uri.parse('$apiBaseUrl/books/search?q=$encodedQuery');

    AppLogger.apiStart(
      'searchBooks',
      detail: 'query=${query.trim()}',
    );
    print('📚 searchBooks START | query=${query.trim()}');

    try {
      final res = await http.get(url);

      if (res.statusCode != 200) {
        throw Exception('책 검색 실패: ${res.statusCode} ${res.body}');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final books = data['books'];

      if (books is! List) {
        throw Exception('책 검색 응답 형식 오류');
      }

      final result = books
          .map((e) => BookSearchResult.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      AppLogger.apiSuccess(
        'searchBooks',
        detail: 'count=${result.length}',
      );
      print('✅ searchBooks SUCCESS | count=${result.length}');

      return result;
    } catch (e, st) {
      AppLogger.apiError('searchBooks', e, stackTrace: st);
      print('❌ searchBooks FAIL | $e');
      rethrow;
    }
  }

  Future<String> generateDescription({
    required String title,
    required String author,
    required String publisher,
    required String publishedDate,
  }) async {
    final url = Uri.parse('$apiBaseUrl/books/generate-description');

    AppLogger.apiStart(
      'generateDescription',
      detail: 'title=$title, author=$author',
    );
    print('📝 generateDescription START | title=$title | author=$author');

    try {
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
      final description = (data['description'] ?? '').toString();

      AppLogger.apiSuccess(
        'generateDescription',
        detail: 'length=${description.length}',
      );
      print('✅ generateDescription SUCCESS | length=${description.length}');

      return description;
    } catch (e, st) {
      AppLogger.apiError('generateDescription', e, stackTrace: st);
      print('❌ generateDescription FAIL | $e');
      rethrow;
    }
  }

  Future<String> generateReason({
    required String title,
    required String author,
    required String description,
  }) async {
    final url = Uri.parse('$apiBaseUrl/books/generate-reason');

    AppLogger.apiStart(
      'generateReason',
      detail: 'title=$title, author=$author',
    );
    print('💡 generateReason START | title=$title | author=$author');

    try {
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
      final reason = (data['reason'] ?? '').toString();

      AppLogger.apiSuccess(
        'generateReason',
        detail: 'length=${reason.length}',
      );
      print('✅ generateReason SUCCESS | length=${reason.length}');

      return reason;
    } catch (e, st) {
      AppLogger.apiError('generateReason', e, stackTrace: st);
      print('❌ generateReason FAIL | $e');
      rethrow;
    }
  }

  Future<int> findOrCreateBook({
    required String isbn,
    required String title,
    required String author,
    required String description,
    String? coverUrl,
  }) async {
    final safeIsbn = isbn.trim();
    final safeTitle = title.trim();
    final safeAuthor = author.trim();
    final safeDescription = description.trim();
    final safeCoverUrl = (coverUrl ?? '').trim().isEmpty ? null : coverUrl!.trim();

    if (safeIsbn.isEmpty || safeTitle.isEmpty) {
      throw Exception('책 정보가 올바르지 않습니다.');
    }

    AppLogger.apiStart(
      'findOrCreateBook',
      detail: 'isbn=$safeIsbn, title=$safeTitle',
    );
    print('📘 findOrCreateBook START | isbn=$safeIsbn | title=$safeTitle');

    try {
      final existing = await supabase
          .from('books')
          .select('id')
          .eq('isbn', safeIsbn)
          .maybeSingle();

      if (existing != null) {
        final existingId = existing['id'] as int;

        print('ℹ️ findOrCreateBook EXISTING | id=$existingId | isbn=$safeIsbn');

        await supabase.from('books').update({
          'title': safeTitle,
          'author': safeAuthor.isEmpty ? null : safeAuthor,
          'cover_url': safeCoverUrl,
          'description': safeDescription.isEmpty ? null : safeDescription,
        }).eq('id', existingId);

        AppLogger.apiSuccess(
          'findOrCreateBook',
          detail: 'mode=update_existing, id=$existingId',
        );
        print('✅ findOrCreateBook SUCCESS | mode=update_existing | id=$existingId');

        return existingId;
      }

      print('➕ findOrCreateBook INSERT TRY | isbn=$safeIsbn | title=$safeTitle');

      final inserted = await supabase
          .from('books')
          .insert({
            'isbn': safeIsbn,
            'title': safeTitle,
            'author': safeAuthor.isEmpty ? null : safeAuthor,
            'cover_url': safeCoverUrl,
            'description': safeDescription.isEmpty ? null : safeDescription,
          })
          .select('id')
          .single();

      final insertedId = inserted['id'] as int;

      AppLogger.apiSuccess(
        'findOrCreateBook',
        detail: 'mode=insert, id=$insertedId',
      );
      print('✅ findOrCreateBook SUCCESS | mode=insert | id=$insertedId');

      return insertedId;
    } on PostgrestException catch (e, st) {
      AppLogger.apiError('findOrCreateBook', e, stackTrace: st);
      print('❌ findOrCreateBook POSTGREST FAIL | ${e.message}');

      final isDuplicateIsbn = e.code == '23505' && e.message.contains('books_isbn_key');
      final isDuplicatePrimaryKey = e.code == '23505' && e.message.contains('books_pkey');

      if (isDuplicateIsbn || isDuplicatePrimaryKey) {
        print('🔁 findOrCreateBook RETRY LOOKUP | isbn=$safeIsbn');

        final retried = await supabase
            .from('books')
            .select('id')
            .eq('isbn', safeIsbn)
            .maybeSingle();

        if (retried != null) {
          final retriedId = retried['id'] as int;

          await supabase.from('books').update({
            'title': safeTitle,
            'author': safeAuthor.isEmpty ? null : safeAuthor,
            'cover_url': safeCoverUrl,
            'description': safeDescription.isEmpty ? null : safeDescription,
          }).eq('id', retriedId);

          AppLogger.apiSuccess(
            'findOrCreateBook',
            detail: 'mode=retry_lookup, id=$retriedId',
          );
          print('✅ findOrCreateBook SUCCESS | mode=retry_lookup | id=$retriedId');

          return retriedId;
        }
      }

      rethrow;
    } catch (e, st) {
      AppLogger.apiError('findOrCreateBook', e, stackTrace: st);
      print('❌ findOrCreateBook FAIL | $e');
      rethrow;
    }
  }
}