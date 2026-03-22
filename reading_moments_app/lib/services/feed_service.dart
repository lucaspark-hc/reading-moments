import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/log/app_logger.dart';
import '../core/supabase_client.dart';
import '../models/book_model.dart';
import '../models/book_selection_item.dart';
import '../models/feed_moment_item.dart';

class FeedService {
  final SupabaseClient _client = supabase;

  Future<Set<int>> _loadLikedMomentIds() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return <int>{};

    final likedResponse = await _client
        .from('moment_likes')
        .select('moment_id')
        .eq('user_id', currentUser.id);

    return (likedResponse as List)
        .map((e) => (e['moment_id'] as num).toInt())
        .toSet();
  }

  Future<Set<int>> _loadWishlistedBookIds() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return <int>{};

    final response = await _client
        .from('book_wishlist')
        .select('book_id')
        .eq('user_id', currentUser.id);

    return (response as List)
        .map((e) => (e['book_id'] as num).toInt())
        .toSet();
  }

  Future<Map<String, String>> _loadNicknames(List<Map<String, dynamic>> rows) async {
    final userIds = rows
        .map((e) => e['user_id'])
        .whereType<String>()
        .toSet()
        .toList();

    if (userIds.isEmpty) return {};

    final userResponse = await _client
        .from('users')
        .select('id, nickname')
        .inFilter('id', userIds);

    final userRows = (userResponse as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return {
      for (final row in userRows)
        row['id'] as String: ((row['nickname'] ?? '알 수 없음') as String),
    };
  }

  Future<Map<int, Map<String, dynamic>>> _loadBooksByIds(
    List<Map<String, dynamic>> rows,
  ) async {
    final bookIds = rows
        .map((e) => e['book_id'])
        .whereType<num>()
        .map((e) => e.toInt())
        .toSet()
        .toList();

    if (bookIds.isEmpty) return {};

    final bookResponse = await _client
        .from('books')
        .select('id, isbn, title, author, cover_url, category, description')
        .inFilter('id', bookIds);

    final bookRows = (bookResponse as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return {
      for (final row in bookRows) (row['id'] as num).toInt(): row,
    };
  }

  List<FeedMomentItem> _mapFeedMoments(
    List<Map<String, dynamic>> rows, {
    required Set<int> likedMomentIds,
    required Set<int> wishlistedBookIds,
    required Map<String, String> nicknameByUserId,
    required Map<int, Map<String, dynamic>> bookById,
  }) {
    final mappedRows = rows.map((row) {
      final userId = row['user_id'] as String;
      final bookId = (row['book_id'] as num).toInt();
      final book = bookById[bookId];

      return <String, dynamic>{
        ...row,
        'users': <String, dynamic>{
          'nickname': nicknameByUserId[userId] ?? '알 수 없음',
        },
        'books': <String, dynamic>{
          'title': (book?['title'] ?? '-') as String,
          'author': book?['author'] as String?,
          'cover_url': book?['cover_url'] as String?,
        },
      };
    }).toList();

    return mappedRows
        .map(
          (e) => FeedMomentItem.fromMap(
            e,
            likedMomentIds: likedMomentIds,
            wishlistedBookIds: wishlistedBookIds,
          ),
        )
        .toList();
  }

  Future<List<FeedMomentItem>> loadPublicMoments() async {
    final currentUser = _client.auth.currentUser;

    AppLogger.apiStart(
      'loadPublicMoments',
      detail: 'userId=${currentUser?.id ?? 'guest'}',
    );

    try {
      final likedMomentIds = await _loadLikedMomentIds();
      final wishlistedBookIds = await _loadWishlistedBookIds();

      final response = await _client
          .from('reading_moments')
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
            like_count
          ''')
          .eq('visibility', 'public')
          .order('created_at', ascending: false);

      final rows =
          (response as List).map((e) => Map<String, dynamic>.from(e)).toList();

      if (rows.isEmpty) {
        AppLogger.apiSuccess('loadPublicMoments', detail: 'count=0');
        return [];
      }

      final nicknameByUserId = await _loadNicknames(rows);
      final bookById = await _loadBooksByIds(rows);

      final result = _mapFeedMoments(
        rows,
        likedMomentIds: likedMomentIds,
        wishlistedBookIds: wishlistedBookIds,
        nicknameByUserId: nicknameByUserId,
        bookById: bookById,
      );

      AppLogger.apiSuccess(
        'loadPublicMoments',
        detail: 'count=${result.length}',
      );

      return result;
    } catch (e, st) {
      AppLogger.apiError('loadPublicMoments', e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<FeedMomentItem>> loadPublicMomentsByBook(int bookId) async {
    final currentUser = _client.auth.currentUser;

    AppLogger.apiStart(
      'loadPublicMomentsByBook',
      detail: 'bookId=$bookId, userId=${currentUser?.id ?? 'guest'}',
    );

    try {
      final likedMomentIds = await _loadLikedMomentIds();
      final wishlistedBookIds = await _loadWishlistedBookIds();

      final response = await _client
          .from('reading_moments')
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
            like_count
          ''')
          .eq('visibility', 'public')
          .eq('book_id', bookId)
          .order('created_at', ascending: false);

      final rows =
          (response as List).map((e) => Map<String, dynamic>.from(e)).toList();

      if (rows.isEmpty) {
        AppLogger.apiSuccess('loadPublicMomentsByBook', detail: 'count=0');
        return [];
      }

      final nicknameByUserId = await _loadNicknames(rows);
      final bookById = await _loadBooksByIds(rows);

      final result = _mapFeedMoments(
        rows,
        likedMomentIds: likedMomentIds,
        wishlistedBookIds: wishlistedBookIds,
        nicknameByUserId: nicknameByUserId,
        bookById: bookById,
      );

      AppLogger.apiSuccess(
        'loadPublicMomentsByBook',
        detail: 'count=${result.length}',
      );

      return result;
    } catch (e, st) {
      AppLogger.apiError('loadPublicMomentsByBook', e, stackTrace: st);
      rethrow;
    }
  }

  Future<BookModel> loadBookById(int bookId) async {
    AppLogger.apiStart('loadBookById', detail: 'bookId=$bookId');

    try {
      final response = await _client
          .from('books')
          .select('id, isbn, title, author, cover_url, category, description')
          .eq('id', bookId)
          .single();

      final result = BookModel.fromJson(Map<String, dynamic>.from(response));

      AppLogger.apiSuccess(
        'loadBookById',
        detail: 'bookId=${result.id}, title=${result.title}',
      );

      return result;
    } catch (e, st) {
      AppLogger.apiError('loadBookById', e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<BookSelectionItem>> loadPublicSelectionsByBook(int bookId) async {
    AppLogger.apiStart(
      'loadPublicSelectionsByBook',
      detail: 'bookId=$bookId',
    );

    try {
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

      final result = (response as List)
          .map((e) => BookSelectionItem.fromMap(e as Map<String, dynamic>))
          .toList();

      AppLogger.apiSuccess(
        'loadPublicSelectionsByBook',
        detail: 'count=${result.length}',
      );

      return result;
    } catch (e, st) {
      AppLogger.apiError('loadPublicSelectionsByBook', e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> addBookToWishlist(int bookId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    AppLogger.apiStart(
      'addBookToWishlist',
      detail: 'bookId=$bookId, userId=${currentUser.id}',
    );

    try {
      await _client.from('book_wishlist').insert({
        'user_id': currentUser.id,
        'book_id': bookId,
      });

      AppLogger.apiSuccess('addBookToWishlist', detail: 'bookId=$bookId');
    } catch (e, st) {
      AppLogger.apiError('addBookToWishlist', e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> removeBookFromWishlist(int bookId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    AppLogger.apiStart(
      'removeBookFromWishlist',
      detail: 'bookId=$bookId, userId=${currentUser.id}',
    );

    try {
      await _client
          .from('book_wishlist')
          .delete()
          .eq('user_id', currentUser.id)
          .eq('book_id', bookId);

      AppLogger.apiSuccess('removeBookFromWishlist', detail: 'bookId=$bookId');
    } catch (e, st) {
      AppLogger.apiError('removeBookFromWishlist', e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> likeMoment(int momentId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    AppLogger.apiStart(
      'likeMoment',
      detail: 'momentId=$momentId, userId=${currentUser.id}',
    );

    try {
      await _client.from('moment_likes').insert({
        'user_id': currentUser.id,
        'moment_id': momentId,
      });

      AppLogger.apiSuccess('likeMoment', detail: 'momentId=$momentId');
    } catch (e, st) {
      AppLogger.apiError('likeMoment', e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> unlikeMoment(int momentId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    AppLogger.apiStart(
      'unlikeMoment',
      detail: 'momentId=$momentId, userId=${currentUser.id}',
    );

    try {
      await _client
          .from('moment_likes')
          .delete()
          .eq('user_id', currentUser.id)
          .eq('moment_id', momentId);

      AppLogger.apiSuccess('unlikeMoment', detail: 'momentId=$momentId');
    } catch (e, st) {
      AppLogger.apiError('unlikeMoment', e, stackTrace: st);
      rethrow;
    }
  }
}