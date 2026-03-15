import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../models/reading_note.dart';

class ReadingNotesService {
  final SupabaseClient _client = supabase;

  Future<List<ReadingNote>> getMyNotesByBook({
    required String userId,
    required int bookId,
  }) async {
    final response = await _client
        .from('reading_notes')
        .select()
        .eq('user_id', userId)
        .eq('book_id', bookId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => ReadingNote.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createNote({
    required String userId,
    required int bookId,
    required String type,
    String? quoteText,
    String? noteText,
    required String visibility,
    int? page,
  }) async {
    await _client.from('reading_notes').insert({
      'user_id': userId,
      'book_id': bookId,
      'type': type,
      'quote_text': quoteText,
      'note_text': noteText,
      'visibility': visibility,
      'page': page,
    });
  }

  Future<void> updateNote({
    required int id,
    required String type,
    String? quoteText,
    String? noteText,
    required String visibility,
    int? page,
  }) async {
    await _client.from('reading_notes').update({
      'type': type,
      'quote_text': quoteText,
      'note_text': noteText,
      'visibility': visibility,
      'page': page,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteNote(int id) async {
    await _client.from('reading_notes').delete().eq('id', id);
  }
}