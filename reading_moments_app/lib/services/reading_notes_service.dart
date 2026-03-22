import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../core/log/app_logger.dart';
import '../models/reading_note.dart';

class ReadingNotesService {
  final SupabaseClient _client = supabase;

  /// 내 기록 조회
  Future<List<ReadingNote>> getMyNotesByBook({
    required String userId,
    required int bookId,
  }) async {
    AppLogger.apiStart(
      'getMyNotesByBook',
      detail: 'userId=$userId, bookId=$bookId',
    );

    try {
      final response = await _client
          .from('reading_notes')
          .select()
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((e) => ReadingNote.fromMap(e as Map<String, dynamic>))
          .toList();

      AppLogger.apiSuccess(
        'getMyNotesByBook',
        detail: 'count=${list.length}',
      );

      return list;
    } catch (e, st) {
      AppLogger.apiError('getMyNotesByBook', e, stackTrace: st);
      rethrow;
    }
  }

  /// 기록 생성
  Future<void> createNote({
    required String userId,
    required int bookId,
    String? quoteText,
    String? noteText,
    required String visibility,
    int? page,
  }) async {
    AppLogger.apiStart(
      'createNote',
      detail: 'userId=$userId, bookId=$bookId',
    );

    try {
      await _client.from('reading_notes').insert({
        'user_id': userId,
        'book_id': bookId,

        /// DB 호환을 위해 type은 고정
        'type': 'quote',

        'quote_text': quoteText,
        'note_text': noteText,
        'visibility': visibility,
        'page': page,
      });

      AppLogger.apiSuccess('createNote');
    } catch (e, st) {
      AppLogger.apiError('createNote', e, stackTrace: st);
      rethrow;
    }
  }

  /// 기록 수정
  Future<void> updateNote({
    required int id,
    String? quoteText,
    String? noteText,
    required String visibility,
    int? page,
  }) async {
    AppLogger.apiStart(
      'updateNote',
      detail: 'noteId=$id',
    );

    try {
      await _client.from('reading_notes').update({
        /// DB 호환
        'type': 'quote',

        'quote_text': quoteText,
        'note_text': noteText,
        'visibility': visibility,
        'page': page,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      AppLogger.apiSuccess('updateNote');
    } catch (e, st) {
      AppLogger.apiError('updateNote', e, stackTrace: st);
      rethrow;
    }
  }

  /// 기록 삭제
  Future<void> deleteNote(int id) async {
    AppLogger.apiStart(
      'deleteNote',
      detail: 'noteId=$id',
    );

    try {
      await _client.from('reading_notes').delete().eq('id', id);
      AppLogger.apiSuccess('deleteNote');
    } catch (e, st) {
      AppLogger.apiError('deleteNote', e, stackTrace: st);
      rethrow;
    }
  }
}