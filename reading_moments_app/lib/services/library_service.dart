import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/wishlist_book_item.dart';

class LibraryService {
  final SupabaseClient _client = supabase;

  Future<void> addWishlistBook(int bookId) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    await _client.from('book_wishlist').insert({
      'user_id': user.id,
      'book_id': bookId,
    });
  }

  Future<void> removeWishlistBook(int bookId) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    await _client
        .from('book_wishlist')
        .delete()
        .eq('user_id', user.id)
        .eq('book_id', bookId);
  }

  Future<bool> isBookSaved(int bookId) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return false;
    }

    final res = await _client
        .from('book_wishlist')
        .select()
        .eq('user_id', user.id)
        .eq('book_id', bookId)
        .maybeSingle();

    return res != null;
  }

  Future<List<WishlistBookItem>> loadWishlistBooks() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

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

    return (response as List)
        .map((e) => WishlistBookItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}