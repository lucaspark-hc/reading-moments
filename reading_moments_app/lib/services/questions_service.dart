import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:reading_moments_app/core/env.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/answer_item.dart';
import 'package:reading_moments_app/models/question_item.dart';

class QuestionsService {
  Future<List<QuestionItem>> loadQuestions(int meetingId) async {
    final url = Uri.parse('$apiBaseUrl/meetings/$meetingId/questions');
    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception('질문 조회 실패: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['questions'] as List)
        .map((e) => QuestionItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> generateQuestions({
    required int meetingId,
    required String bookTitle,
    required String author,
    required String hostUserId,
  }) async {
    final url = Uri.parse('$apiBaseUrl/generate-questions');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'meetingId': meetingId,
        'bookTitle': bookTitle,
        'author': author,
        'hostUserId': hostUserId,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('질문 생성 실패: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> addQuestion({
    required int meetingId,
    required String userId,
    required String question,
  }) async {
    await supabase.from('questions').insert({
      'meeting_id': meetingId,
      'created_by': userId,
      'question': question,
    });
  }

  Future<void> editQuestion({
    required int questionId,
    required String question,
  }) async {
    await supabase.from('questions').update({
      'question': question,
    }).eq('id', questionId);
  }

  Future<List<AnswerItem>> loadAnswers(int questionId) async {
    final rows = await supabase
        .from('answers')
        .select('''
          id,
          question_id,
          meeting_id,
          user_id,
          answer,
          created_at,
          users (
            nickname
          )
        ''')
        .eq('question_id', questionId)
        .order('created_at', ascending: true);

    return (rows as List)
        .map((e) => AnswerItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveAnswer({
    required AnswerItem? myAnswer,
    required int questionId,
    required int meetingId,
    required String userId,
    required String answer,
  }) async {
    if (myAnswer == null) {
      await supabase.from('answers').insert({
        'question_id': questionId,
        'meeting_id': meetingId,
        'user_id': userId,
        'answer': answer,
      });
      return;
    }

    await supabase.from('answers').update({
      'answer': answer,
    }).eq('id', myAnswer.id);
  }

  Future<List<AnswerItem>> loadMyAnswersForMeeting({
    required int meetingId,
    required String userId,
  }) async {
    final rows = await supabase
        .from('answers')
        .select('''
          id,
          question_id,
          meeting_id,
          user_id,
          answer,
          created_at,
          users (
            nickname
          ),
          questions (
            question
          )
        ''')
        .eq('meeting_id', meetingId)
        .eq('user_id', userId)
        .order('created_at', ascending: true);

    return (rows as List)
        .map((e) => AnswerItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}