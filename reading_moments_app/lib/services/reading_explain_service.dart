import 'package:reading_moments_app/core/log/app_logger.dart';
import 'package:reading_moments_app/core/supabase_client.dart';

class ReadingExplainResult {
  final String summary;
  final String explanation;

  const ReadingExplainResult({
    required this.summary,
    required this.explanation,
  });
}

class ReadingExplainService {
  Future<ReadingExplainResult> explainSentence(String userSelectedText) async {
    final text = userSelectedText.trim();
    if (text.isEmpty) {
      throw Exception('문장이 비어 있습니다.');
    }

    const prompt = '''
당신은 독서를 돕는 설명 도우미입니다.

사용자가 읽다가 이해하기 어려운 문장을 보냈습니다.
이 문장을 쉽고 짧게 풀어주세요.

문장에는 OCR로 인해 일부 오타가 있을 수 있습니다.
문맥을 기준으로 자연스럽게 해석해주세요.

조건:
- 최대 3~4문장으로 설명
- 첫 문장은 반드시 "쉽게 말하면,"으로 시작
- 어려운 단어는 쉬운 말로 바꿔 설명
- 핵심 의미만 전달
- 단정적인 해석은 피하고 "~로 이해할 수 있습니다" 형태 사용
- 작가 의도 추측 금지
- 배경 설명 금지
- 장황한 설명 금지

출력 형식:
{
  "summary": "한 줄 요약",
  "explanation": "간단한 의미 설명"
}
''';

    AppLogger.apiStart(
      'readingExplain',
      detail: 'textLength=${text.length}',
    );

    try {
      final response = await supabase.functions.invoke(
        'easy-read-explain',
        body: {
          'prompt': prompt,
          'text': text,
        },
      );

      final data = response.data;

      String summary = '';
      String explanation = '';

      if (data is Map) {
        summary = (data['summary'] ?? '').toString().trim();
        explanation = (data['explanation'] ?? '').toString().trim();
      } else {
        final raw = data?.toString().trim() ?? '';
        summary = raw;
        explanation = raw;
      }

      if (summary.isEmpty && explanation.isEmpty) {
        throw Exception('AI 응답이 비어 있습니다.');
      }

      if (summary.isEmpty) {
        summary = explanation;
      }

      if (explanation.isEmpty) {
        explanation = summary;
      }

      if (!summary.startsWith('쉽게 말하면,')) {
        summary =
            '쉽게 말하면, ${summary.replaceFirst(RegExp(r'^쉽게 말하면[, ]*'), '')}';
      }

      AppLogger.apiSuccess(
        'readingExplain',
        detail: 'textLength=${text.length}',
      );

      return ReadingExplainResult(
        summary: summary,
        explanation: explanation,
      );
    } catch (e, st) {
      AppLogger.apiError('readingExplain', e, stackTrace: st);

      final errorText = e.toString();
      if (errorText.contains('404') || errorText.contains('NOT_FOUND')) {
        throw Exception(
          'easy-read-explain 함수가 아직 배포되지 않았습니다. Supabase Edge Function 배포가 필요합니다.',
        );
      }

      rethrow;
    }
  }
}