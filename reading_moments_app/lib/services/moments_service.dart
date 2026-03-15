import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/moment_model.dart';

class MomentsService {
  Future<void> createMoment({
    required String userId,
    required int bookId,
    required String quoteText,
    String? noteText,
    int? page,
    required String visibility,
    int? meetingId,
    required String type,
    String inputMethod = 'manual',
  }) async {
    await supabase.from('reading_moments').insert({
      'user_id': userId,
      'book_id': bookId,
      'quote_text': quoteText,
      'note_text': noteText,
      'page': page,
      'visibility': visibility,
      'meeting_id': meetingId,
      'type': type,
      'input_method': inputMethod,
    });
  }

  Future<List<MomentModel>> loadMomentsByBook(int bookId) async {
    final rows = await supabase
        .from('reading_moments')
        .select()
        .eq('book_id', bookId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((e) => MomentModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> deleteMoment(int momentId) async {
    await supabase.from('reading_moments').delete().eq('id', momentId);
  }
}
