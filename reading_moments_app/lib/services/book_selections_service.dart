import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/book_selection_item.dart';

class BookSelectionsService {
  final SupabaseClient _client = supabase;

  Future<BookSelectionItem> createSelection({
    required String userId,
    required int bookId,
    String? bookDescription,
    required String selectionReason,
    required String visibility,
  }) async {
    final inserted = await _client
        .from('book_selections')
        .insert({
          'user_id': userId,
          'book_id': bookId,
          'book_description': bookDescription,
          'selection_reason': selectionReason,
          'visibility': visibility,
        })
        .select('id')
        .single();

    final id = inserted['id'] as int;
    return loadSelectionById(id);
  }

  Future<BookSelectionItem> loadSelectionById(int id) async {
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
        .eq('id', id)
        .single();

    return BookSelectionItem.fromMap(response);
  }

  Future<List<BookSelectionItem>> loadMySelections() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

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
        .eq('user_id', currentUser.id)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => BookSelectionItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}