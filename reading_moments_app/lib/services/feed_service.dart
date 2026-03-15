import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/book_feed_summary_item.dart';
import '../models/feed_note_item.dart';
import '../models/public_book_selection_item.dart';

class FeedService {
  final SupabaseClient _client = supabase;

  Future<List<BookFeedSummaryItem>> loadBookFeedSummaries() async {
    final currentUser = _client.auth.currentUser;

    Set<int> wishlistedBookIds = {};

    if (currentUser != null) {
      final wishlistResponse = await _client
          .from('book_wishlist')
          .select('book_id')
          .eq('user_id', currentUser.id);

      wishlistedBookIds = (wishlistResponse as List)
          .map((e) => e['book_id'] as int)
          .toSet();
    }

    final selectionsResponse = await _client
        .from('book_selections')
        .select('''
          id,
          book_id,
          selection_reason,
          created_at,
          books:book_id (
            id,
            title,
            author,
            cover_url,
            isbn
          )
        ''')
        .eq('visibility', 'public')
        .order('created_at', ascending: false);

    final notesResponse = await _client
        .from('reading_notes')
        .select('''
          id,
          book_id,
          quote_text,
          note_text,
          created_at,
          books:book_id (
            id,
            title,
            author,
            cover_url,
            isbn
          )
        ''')
        .eq('visibility', 'public')
        .order('created_at', ascending: false);

    final selectionRows = (selectionsResponse as List).cast<Map<String, dynamic>>();
    final noteRows = (notesResponse as List).cast<Map<String, dynamic>>();

    final Map<int, Map<String, dynamic>> summaryMap = {};

    void ensureBook({
      required int bookId,
      required Map<String, dynamic>? bookMap,
    }) {
      summaryMap.putIfAbsent(bookId, () {
        return {
          'bookId': bookId,
          'bookTitle': (bookMap?['title'] ?? '-') as String,
          'bookAuthor': bookMap?['author'] as String?,
          'coverUrl': bookMap?['cover_url'] as String?,
          'isbn': bookMap?['isbn'] as String?,
          'publicSelectionCount': 0,
          'publicNoteCount': 0,
          'latestCreatedAt': DateTime.fromMillisecondsSinceEpoch(0),
          'previewText': null,
        };
      });
    }

    for (final row in selectionRows) {
      final bookId = row['book_id'] as int;
      final bookMap = row['books'] as Map<String, dynamic>?;
      final createdAt = DateTime.parse(row['created_at'] as String);
      final reason = row['selection_reason'] as String?;

      ensureBook(bookId: bookId, bookMap: bookMap);

      final target = summaryMap[bookId]!;
      target['publicSelectionCount'] = (target['publicSelectionCount'] as int) + 1;

      final latestCreatedAt = target['latestCreatedAt'] as DateTime;
      if (createdAt.isAfter(latestCreatedAt)) {
        target['latestCreatedAt'] = createdAt;
        target['previewText'] = reason;
      }
    }

    for (final row in noteRows) {
      final bookId = row['book_id'] as int;
      final bookMap = row['books'] as Map<String, dynamic>?;
      final createdAt = DateTime.parse(row['created_at'] as String);
      final quoteText = row['quote_text'] as String?;
      final noteText = row['note_text'] as String?;
      final preview = (noteText ?? '').trim().isNotEmpty ? noteText : quoteText;

      ensureBook(bookId: bookId, bookMap: bookMap);

      final target = summaryMap[bookId]!;
      target['publicNoteCount'] = (target['publicNoteCount'] as int) + 1;

      final latestCreatedAt = target['latestCreatedAt'] as DateTime;
      if (createdAt.isAfter(latestCreatedAt)) {
        target['latestCreatedAt'] = createdAt;
        target['previewText'] = preview;
      }
    }

    final result = summaryMap.values.map((e) {
      final bookId = e['bookId'] as int;
      return BookFeedSummaryItem(
        bookId: bookId,
        bookTitle: e['bookTitle'] as String,
        bookAuthor: e['bookAuthor'] as String?,
        coverUrl: e['coverUrl'] as String?,
        isbn: e['isbn'] as String?,
        publicSelectionCount: e['publicSelectionCount'] as int,
        publicNoteCount: e['publicNoteCount'] as int,
        latestCreatedAt: e['latestCreatedAt'] as DateTime,
        previewText: e['previewText'] as String?,
        isWishlisted: wishlistedBookIds.contains(bookId),
      );
    }).toList();

    result.sort((a, b) => b.latestCreatedAt.compareTo(a.latestCreatedAt));
    return result;
  }

  Future<List<PublicBookSelectionItem>> loadPublicSelectionsByBook(int bookId) async {
    final response = await _client
        .from('book_selections')
        .select('''
          id,
          user_id,
          book_id,
          book_description,
          selection_reason,
          visibility,
          meeting_id,
          created_at,
          users:user_id (
            nickname
          ),
          books:book_id (
            title,
            author,
            cover_url,
            isbn
          )
        ''')
        .eq('visibility', 'public')
        .eq('book_id', bookId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => PublicBookSelectionItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<FeedNoteItem>> loadPublicFeedByBook(int bookId) async {
    final currentUser = _client.auth.currentUser;

    Set<int> likedNoteIds = {};
    Map<int, int> likeCountMap = {};

    if (currentUser != null) {
      final likedResponse = await _client
          .from('note_likes')
          .select('note_id')
          .eq('user_id', currentUser.id);

      likedNoteIds = (likedResponse as List)
          .map((e) => e['note_id'] as int)
          .toSet();
    }

    final likeCountResponse = await _client.from('note_likes').select('note_id');

    for (final row in (likeCountResponse as List)) {
      final noteId = row['note_id'] as int;
      likeCountMap[noteId] = (likeCountMap[noteId] ?? 0) + 1;
    }

    final response = await _client
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
          users:user_id (
            nickname
          ),
          books:book_id (
            title,
            author
          )
        ''')
        .eq('visibility', 'public')
        .eq('book_id', bookId)
        .order('created_at', ascending: false);

    final rows = (response as List).cast<Map<String, dynamic>>();

    return rows
        .map(
          (e) => FeedNoteItem.fromMap(
            e,
            savedNoteIds: const <int>{},
            likedNoteIds: likedNoteIds,
            likeCountMap: likeCountMap,
          ),
        )
        .toList();
  }

  Future<void> likeNote(int noteId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    await _client.from('note_likes').insert({
      'user_id': currentUser.id,
      'note_id': noteId,
    });
  }

  Future<void> unlikeNote(int noteId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    await _client
        .from('note_likes')
        .delete()
        .eq('user_id', currentUser.id)
        .eq('note_id', noteId);
  }
}