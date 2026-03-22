import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/log/app_logger.dart';
import '../core/supabase_client.dart';
import '../models/wishlist_book_item.dart';

enum LibraryBookStatus {
  wishlist,
  selected,
  reading,
  done,
  none,
}

class LibraryService {
  final SupabaseClient _client = supabase;

  Future<void> addWishlistBook(int bookId) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    AppLogger.apiStart(
      'addWishlistBook',
      detail: 'userId=${user.id}, bookId=$bookId',
    );

    try {
      await _client.from('book_wishlist').insert({
        'user_id': user.id,
        'book_id': bookId,
      });

      AppLogger.apiSuccess(
        'addWishlistBook',
        detail: 'bookId=$bookId',
      );
    } catch (e, st) {
      AppLogger.apiError('addWishlistBook', e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> removeWishlistBook(int bookId) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    AppLogger.apiStart(
      'removeWishlistBook',
      detail: 'userId=${user.id}, bookId=$bookId',
    );

    try {
      await _client
          .from('book_wishlist')
          .delete()
          .eq('user_id', user.id)
          .eq('book_id', bookId);

      AppLogger.apiSuccess(
        'removeWishlistBook',
        detail: 'bookId=$bookId',
      );
    } catch (e, st) {
      AppLogger.apiError('removeWishlistBook', e, stackTrace: st);
      rethrow;
    }
  }

  Future<bool> isBookSaved(int bookId) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return false;
    }

    AppLogger.apiStart(
      'isBookSaved',
      detail: 'userId=${user.id}, bookId=$bookId',
    );

    try {
      final res = await _client
          .from('book_wishlist')
          .select()
          .eq('user_id', user.id)
          .eq('book_id', bookId)
          .maybeSingle();

      final result = res != null;

      AppLogger.apiSuccess(
        'isBookSaved',
        detail: 'bookId=$bookId, saved=$result',
      );

      return result;
    } catch (e, st) {
      AppLogger.apiError('isBookSaved', e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<WishlistBookItem>> loadWishlistBooks() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    AppLogger.apiStart(
      'loadWishlistBooks',
      detail: 'userId=${user.id}',
    );

    try {
      final response = await _client
          .from('book_wishlist')
          .select('''
          id,
          book_id,
          created_at,
          books:book_id (
            id,
            title,
            author,
            cover_url,
            isbn
          )
        ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final result = (response as List)
          .map((e) => WishlistBookItem.fromMap(e as Map<String, dynamic>))
          .toList();

      AppLogger.apiSuccess(
        'loadWishlistBooks',
        detail: 'count=${result.length}',
      );

      return result;
    } catch (e, st) {
      AppLogger.apiError('loadWishlistBooks', e, stackTrace: st);
      rethrow;
    }
  }

  Future<Map<int, LibraryBookStatus>> loadSelectionStatuses() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    AppLogger.apiStart(
      'loadSelectionStatuses',
      detail: 'userId=${user.id}',
    );

    try {
      final response = await _client
          .from('book_selections')
          .select('book_id, status')
          .eq('user_id', user.id);

      final rows = (response as List).cast<Map<String, dynamic>>();
      final Map<int, LibraryBookStatus> result = {};

      for (final row in rows) {
        final bookId = row['book_id'] as int?;
        if (bookId == null) continue;

        result[bookId] = _parseStatus(row['status']);
      }

      AppLogger.apiSuccess(
        'loadSelectionStatuses',
        detail: 'count=${result.length}',
      );
      return result;
    } catch (e, st) {
      AppLogger.apiError('loadSelectionStatuses', e, stackTrace: st);
      rethrow;
    }
  }

  Future<LibraryBookStatus> getBookStatus(int bookId) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    AppLogger.apiStart(
      'getBookStatus',
      detail: 'userId=${user.id}, bookId=$bookId',
    );

    try {
      final selectionRow = await _client
          .from('book_selections')
          .select('id, status')
          .eq('user_id', user.id)
          .eq('book_id', bookId)
          .maybeSingle();

      if (selectionRow != null) {
        final status = _parseStatus(selectionRow['status']);
        AppLogger.apiSuccess(
          'getBookStatus',
          detail: 'bookId=$bookId, status=${status.name}',
        );
        return status;
      }

      final recordRows = await _client
          .from('reading_moments')
          .select('id')
          .eq('user_id', user.id)
          .eq('book_id', bookId)
          .limit(1);

      if ((recordRows as List).isNotEmpty) {
        AppLogger.apiSuccess(
          'getBookStatus',
          detail: 'bookId=$bookId, status=reading(legacy)',
        );
        return LibraryBookStatus.reading;
      }

      final wishlistRow = await _client
          .from('book_wishlist')
          .select('id')
          .eq('user_id', user.id)
          .eq('book_id', bookId)
          .maybeSingle();

      if (wishlistRow != null) {
        AppLogger.apiSuccess(
          'getBookStatus',
          detail: 'bookId=$bookId, status=wishlist',
        );
        return LibraryBookStatus.wishlist;
      }

      AppLogger.apiSuccess(
        'getBookStatus',
        detail: 'bookId=$bookId, status=none',
      );
      return LibraryBookStatus.none;
    } catch (e, st) {
      AppLogger.apiError('getBookStatus', e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> ensureWishlistState(int bookId) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    AppLogger.apiStart(
      'ensureWishlistState',
      detail: 'userId=${user.id}, bookId=$bookId',
    );

    try {
      final status = await getBookStatus(bookId);

      if (status == LibraryBookStatus.none) {
        await addWishlistBook(bookId);
      }

      AppLogger.apiSuccess(
        'ensureWishlistState',
        detail:
            'bookId=$bookId, finalStatus=${status == LibraryBookStatus.none ? 'wishlist' : status.name}',
      );
    } catch (e, st) {
      AppLogger.apiError('ensureWishlistState', e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> moveWishlistToReading(int bookId) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    AppLogger.apiStart(
      'moveWishlistToReading',
      detail: 'userId=${user.id}, bookId=$bookId',
    );

    try {
      await removeWishlistBook(bookId);

      AppLogger.apiSuccess(
        'moveWishlistToReading',
        detail: 'bookId=$bookId',
      );
    } catch (e, st) {
      AppLogger.apiError('moveWishlistToReading', e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> markBookAsDone(int bookId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    AppLogger.apiStart(
      'markBookAsDone',
      detail: 'userId=${user.id}, bookId=$bookId',
    );

    try {
      await _client
          .from('book_selections')
          .update({
            'status': 'done',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', user.id)
          .eq('book_id', bookId);

      AppLogger.apiSuccess(
        'markBookAsDone',
        detail: 'bookId=$bookId',
      );
    } catch (e, st) {
      AppLogger.apiError('markBookAsDone', e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> markBookAsReading(int bookId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    AppLogger.apiStart(
      'markBookAsReading',
      detail: 'userId=${user.id}, bookId=$bookId',
    );

    try {
      await _client
          .from('book_selections')
          .update({
            'status': 'reading',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', user.id)
          .eq('book_id', bookId);

      await _client
          .from('book_wishlist')
          .delete()
          .eq('user_id', user.id)
          .eq('book_id', bookId);

      AppLogger.apiSuccess(
        'markBookAsReading',
        detail: 'bookId=$bookId',
      );
    } catch (e, st) {
      AppLogger.apiError('markBookAsReading', e, stackTrace: st);
      rethrow;
    }
  }

  LibraryBookStatus _parseStatus(dynamic raw) {
    final value = (raw ?? '').toString().trim();

    switch (value) {
      case 'done':
        return LibraryBookStatus.done;
      case 'reading':
        return LibraryBookStatus.reading;
      case 'selected':
        return LibraryBookStatus.selected;
      default:
        return LibraryBookStatus.selected;
    }
  }
}