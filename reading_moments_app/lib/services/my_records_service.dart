import 'package:supabase_flutter/supabase_flutter.dart';

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

    final response = await _client
        .from('reading_notes')
        .select('''
          id,
          user_id,
          book_id,
          visibility,
          created_at,
          books:book_id (
            id,
            title,
            author,
            cover_url
          )
        ''')
        .eq('user_id', currentUser.id)
        .order('created_at', ascending: false);

    final rows = (response as List).cast<Map<String, dynamic>>();

    final Map<int, List<Map<String, dynamic>>> grouped = {};

    for (final row in rows) {
      final bookId = row['book_id'] as int;
      grouped.putIfAbsent(bookId, () => []).add(row);
    }

    final result = grouped.entries.map((entry) {
      final items = [...entry.value]
        ..sort(
          (a, b) => DateTime.parse(b['created_at'] as String)
              .compareTo(DateTime.parse(a['created_at'] as String)),
        );

      final first = items.first;
      final bookMap = first['books'] as Map<String, dynamic>?;

      final totalCount = items.length;
      final publicCount = items
          .where((e) => (e['visibility'] ?? 'private') == 'public')
          .length;
      final privateCount = items
          .where((e) => (e['visibility'] ?? 'private') == 'private')
          .length;

      return MyBookRecordGroupItem(
        bookId: entry.key,
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
    return result;
  }

  Future<List<MyRecordItem>> loadMyNotesByBook(
    int bookId, {
    String? visibility,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    var query = _client
        .from('reading_notes')
        .select('''
          id,
          user_id,
          book_id,
          type,
          quote_text,
          note_text,
          visibility,
          page,
          created_at,
          books:book_id (
            id,
            title,
            author,
            cover_url
          )
        ''')
        .eq('user_id', currentUser.id)
        .eq('book_id', bookId);

    if (visibility != null && visibility != 'all') {
      query = query.eq('visibility', visibility);
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map((e) => MyRecordItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateNote({
    required int noteId,
    required String type,
    required String? quoteText,
    required String? noteText,
    required String visibility,
    required int? page,
  }) async {
    await _client.from('reading_notes').update({
      'type': type,
      'quote_text': (quoteText ?? '').trim().isEmpty ? null : quoteText!.trim(),
      'note_text': (noteText ?? '').trim().isEmpty ? null : noteText!.trim(),
      'visibility': visibility,
      'page': page,
    }).eq('id', noteId);
  }

  Future<void> deleteNote(int noteId) async {
    await _client.from('reading_notes').delete().eq('id', noteId);
  }
}