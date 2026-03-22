import 'package:reading_moments_app/core/log/app_logger.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/moment_model.dart';

class MomentsService {
  Future<void> createMoment({
    required String userId,
    required int bookId,
    required String quoteText,
    String? explainText,
    String? noteText,
    int? page,
    required String visibility,
    int? meetingId,
    required String type,
    String inputMethod = 'manual',
  }) async {
    final trimmedQuote = quoteText.trim();
    final trimmedExplain = explainText?.trim();
    final trimmedNote = noteText?.trim();

    AppLogger.apiStart(
      'createMoment',
      detail:
          'userId=$userId, bookId=$bookId, visibility=$visibility, inputMethod=$inputMethod, hasExplain=${trimmedExplain != null && trimmedExplain.isNotEmpty}',
    );
    print(
      '💾 createMoment START | userId=$userId | bookId=$bookId | visibility=$visibility | inputMethod=$inputMethod | hasExplain=${trimmedExplain != null && trimmedExplain.isNotEmpty}',
    );

    try {
      await supabase.from('reading_moments').insert({
        'user_id': userId,
        'book_id': bookId,
        'quote_text': trimmedQuote,
        'explain_text': (trimmedExplain == null || trimmedExplain.isEmpty)
            ? null
            : trimmedExplain,
        'note_text':
            (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
        'page': page,
        'visibility': visibility,
        'meeting_id': meetingId,
        'type': type,
        'input_method': inputMethod,
      });

      AppLogger.apiSuccess(
        'createMoment',
        detail: 'bookId=$bookId',
      );
      print('✅ createMoment SUCCESS | bookId=$bookId');
    } catch (e, st) {
      AppLogger.apiError('createMoment', e, stackTrace: st);
      print('❌ createMoment FAIL | $e');
      rethrow;
    }
  }

  Future<List<MomentModel>> loadMomentsByBook(int bookId) async {
    AppLogger.apiStart(
      'loadMomentsByBook',
      detail: 'bookId=$bookId',
    );
    print('📚 loadMomentsByBook START | bookId=$bookId');

    try {
      final rows = await supabase
          .from('reading_moments')
          .select()
          .eq('book_id', bookId)
          .order('created_at', ascending: false);

      final result = (rows as List)
          .map((e) => MomentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      AppLogger.apiSuccess(
        'loadMomentsByBook',
        detail: 'count=${result.length}',
      );
      print('✅ loadMomentsByBook SUCCESS | count=${result.length}');

      return result;
    } catch (e, st) {
      AppLogger.apiError('loadMomentsByBook', e, stackTrace: st);
      print('❌ loadMomentsByBook FAIL | $e');
      rethrow;
    }
  }

  Future<void> deleteMoment(int momentId) async {
    AppLogger.apiStart(
      'deleteMoment',
      detail: 'momentId=$momentId',
    );
    print('🗑️ deleteMoment START | momentId=$momentId');

    try {
      await supabase.from('reading_moments').delete().eq('id', momentId);

      AppLogger.apiSuccess(
        'deleteMoment',
        detail: 'momentId=$momentId',
      );
      print('✅ deleteMoment SUCCESS | momentId=$momentId');
    } catch (e, st) {
      AppLogger.apiError('deleteMoment', e, stackTrace: st);
      print('❌ deleteMoment FAIL | $e');
      rethrow;
    }
  }
}