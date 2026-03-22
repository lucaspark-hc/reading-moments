import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/log/app_logger.dart';
import '../core/supabase_client.dart';
import '../models/my_book_record_group_item.dart';
import '../models/my_record_item.dart';

class MyRecordsService {
  final SupabaseClient _client = supabase;

  Future<List<MyBookRecordGroupItem>> loadMyBookRecordGroups() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    AppLogger.apiStart(
      'loadMyBookRecordGroups',
      detail: 'userId=${currentUser.id}',
    );

    try {
      final response = await _client
          .from('reading_moments')
          .select('''
            id,
            user_id,
            book_id,
            visibility,
            created_at
          ''')
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false);

      final rows = (response as List).cast<Map<String, dynamic>>();

      if (rows.isEmpty) {
        AppLogger.apiSuccess(
          'loadMyBookRecordGroups',
          detail: 'bookCount=0',
        );
        return [];
      }

      final bookIds = rows.map((e) => e['book_id'] as int).toSet().toList();

      final booksResponse = await _client
          .from('books')
          .select('id, title, author, cover_url')
          .inFilter('id', bookIds);

      final bookRows = (booksResponse as List).cast<Map<String, dynamic>>();
      final Map<int, Map<String, dynamic>> bookMapById = {
        for (final row in bookRows) row['id'] as int: row,
      };

      final Map<int, List<Map<String, dynamic>>> grouped = {};

      for (final row in rows) {
        final bookId = row['book_id'] as int;
        grouped.putIfAbsent(bookId, () => []).add(row);
      }

      final result = grouped.entries.map((entry) {
        final items = [...entry.value]
          ..sort(
            (a, b) => DateTime.parse(b['created_at'] as String).compareTo(
              DateTime.parse(a['created_at'] as String),
            ),
          );

        final first = items.first;
        final bookId = entry.key;
        final bookMap = bookMapById[bookId];

        final totalCount = items.length;
        final publicCount = items
            .where((e) => (e['visibility'] ?? 'private') == 'public')
            .length;
        final privateCount = items
            .where((e) => (e['visibility'] ?? 'private') == 'private')
            .length;

        return MyBookRecordGroupItem(
          bookId: bookId,
          bookTitle: (bookMap?['title'] ?? '-') as String,
          bookAuthor: bookMap?['author'] as String?,
          coverUrl: bookMap?['cover_url'] as String?,
          totalCount: totalCount,
          publicCount: publicCount,
          privateCount: privateCount,
          latestCreatedAt: DateTime.parse(first['created_at'] as String),
        );
      }).toList();

      result.sort((a, b) => b.latestCreatedAt.compareTo(a.latestCreatedAt));

      AppLogger.apiSuccess(
        'loadMyBookRecordGroups',
        detail: 'bookCount=${result.length}',
      );

      return result;
    } catch (e, st) {
      AppLogger.apiError('loadMyBookRecordGroups', e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<MyRecordItem>> loadMyNotesByBook(
    int bookId, {
    String? visibility,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    AppLogger.apiStart(
      'loadMyNotesByBook',
      detail:
          'userId=${currentUser.id}, bookId=$bookId, visibility=${visibility ?? 'all'}',
    );

    try {
      var query = _client
          .from('reading_moments')
          .select('''
            id,
            user_id,
            book_id,
            type,
            quote_text,
            explain_text,
            note_text,
            visibility,
            page,
            created_at,
            updated_at
          ''')
          .eq('user_id', currentUser.id)
          .eq('book_id', bookId);

      if (visibility != null && visibility != 'all') {
        query = query.eq('visibility', visibility);
      }

      final response = await query.order('created_at', ascending: false);

      final rows = (response as List).cast<Map<String, dynamic>>();

      final booksResponse = await _client
          .from('books')
          .select('id, title, author, cover_url')
          .eq('id', bookId)
          .maybeSingle();

      final bookMap = booksResponse as Map<String, dynamic>?;

      final list = rows
          .map(
            (e) => MyRecordItem.fromMap({
              ...e,
              'books': bookMap,
            }),
          )
          .toList();

      AppLogger.apiSuccess(
        'loadMyNotesByBook',
        detail: 'count=${list.length}',
      );

      return list;
    } catch (e, st) {
      AppLogger.apiError('loadMyNotesByBook', e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<MyRecordItem>> loadTodayMomentsByBook(int bookId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final now = DateTime.now();
    final todayStartLocal = DateTime(now.year, now.month, now.day);
    final tomorrowStartLocal = todayStartLocal.add(const Duration(days: 1));

    final todayStartUtc = todayStartLocal.toUtc().toIso8601String();
    final tomorrowStartUtc = tomorrowStartLocal.toUtc().toIso8601String();

    AppLogger.apiStart(
      'loadTodayMomentsByBook',
      detail:
          'userId=${currentUser.id}, bookId=$bookId, start=$todayStartUtc, end=$tomorrowStartUtc',
    );

    try {
      final response = await _client
          .from('reading_moments')
          .select('''
            id,
            user_id,
            book_id,
            type,
            quote_text,
            explain_text,
            note_text,
            visibility,
            page,
            created_at,
            updated_at
          ''')
          .eq('user_id', currentUser.id)
          .eq('book_id', bookId)
          .gte('created_at', todayStartUtc)
          .lt('created_at', tomorrowStartUtc)
          .order('created_at', ascending: false);

      final rows = (response as List).cast<Map<String, dynamic>>();

      final booksResponse = await _client
          .from('books')
          .select('id, title, author, cover_url')
          .eq('id', bookId)
          .maybeSingle();

      final bookMap = booksResponse as Map<String, dynamic>?;

      final list = rows
          .map(
            (e) => MyRecordItem.fromMap({
              ...e,
              'books': bookMap,
            }),
          )
          .toList();

      AppLogger.apiSuccess(
        'loadTodayMomentsByBook',
        detail: 'count=${list.length}',
      );

      return list;
    } catch (e, st) {
      AppLogger.apiError('loadTodayMomentsByBook', e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> updateNote({
    required int noteId,
    required String? quoteText,
    required String? explainText,
    required String? noteText,
    required String visibility,
    required int? page,
  }) async {
    AppLogger.apiStart(
      'updateNote',
      detail: 'noteId=$noteId',
    );

    try {
      await _client.from('reading_moments').update({
        'type': 'quote',
        'quote_text': (quoteText ?? '').trim().isEmpty ? null : quoteText!.trim(),
        'explain_text':
            (explainText ?? '').trim().isEmpty ? null : explainText!.trim(),
        'note_text': (noteText ?? '').trim().isEmpty ? null : noteText!.trim(),
        'visibility': visibility,
        'page': page,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', noteId);

      AppLogger.apiSuccess(
        'updateNote',
        detail: 'noteId=$noteId',
      );
    } catch (e, st) {
      AppLogger.apiError('updateNote', e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteNote(int noteId) async {
    AppLogger.apiStart(
      'deleteNote',
      detail: 'noteId=$noteId',
    );

    try {
      await _client.from('reading_moments').delete().eq('id', noteId);

      AppLogger.apiSuccess(
        'deleteNote',
        detail: 'noteId=$noteId',
      );
    } catch (e, st) {
      AppLogger.apiError('deleteNote', e, stackTrace: st);
      rethrow;
    }
  }
}