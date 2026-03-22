import 'package:reading_moments_app/core/log/app_logger.dart';
import 'package:reading_moments_app/core/supabase_client.dart';

class MeaningUnitService {
  Future<List<String>> splitMeaningUnits(String paragraphText) async {
    final text = paragraphText.trim();
    if (text.isEmpty) {
      return <String>[];
    }

    AppLogger.apiStart(
      'splitMeaningUnits',
      detail: 'textLength=${text.length}',
    );
    print('🧩 splitMeaningUnits START | textLength=${text.length}');

    try {
      final response = await supabase.functions.invoke(
        'meaning-unit-split',
        body: {
          'text': text,
        },
      );

      final units = _parseUnits(response.data);

      if (units.isNotEmpty) {
        AppLogger.apiSuccess(
          'splitMeaningUnits',
          detail: 'count=${units.length}, source=ai',
        );
        print('✅ splitMeaningUnits SUCCESS | count=${units.length} | source=ai');
        return units;
      }

      final fallback = _fallbackSplit(text);

      AppLogger.apiSuccess(
        'splitMeaningUnits',
        detail: 'count=${fallback.length}, source=fallback_empty_ai',
      );
      print(
        '⚠️ splitMeaningUnits FALLBACK | count=${fallback.length} | source=fallback_empty_ai',
      );

      return fallback;
    } catch (e, st) {
      AppLogger.apiError('splitMeaningUnits', e, stackTrace: st);
      print('❌ splitMeaningUnits FAIL | $e');

      final fallback = _fallbackSplit(text);

      AppLogger.apiSuccess(
        'splitMeaningUnits',
        detail: 'count=${fallback.length}, source=fallback_error',
      );
      print(
        '⚠️ splitMeaningUnits FALLBACK | count=${fallback.length} | source=fallback_error',
      );

      return fallback;
    }
  }

  List<String> _parseUnits(dynamic data) {
    if (data is Map && data['units'] is List) {
      return (data['units'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (data is List) {
      return data
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final raw = data?.toString().trim() ?? '';
    if (raw.isEmpty) return <String>[];

    return raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.replaceFirst(RegExp(r'^\[\d+\]\s*'), ''))
        .map((e) => e.replaceFirst(RegExp(r'^\d+\.\s*'), ''))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> _fallbackSplit(String paragraph) {
    final text = paragraph
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.isEmpty) return <String>[];

    final sentences = text
        .split(RegExp(r'(?<=[\.\!\?])\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (sentences.isEmpty) {
      return <String>[text];
    }

    final units = <String>[];
    final buffer = StringBuffer();

    for (final sentence in sentences) {
      if (buffer.isEmpty) {
        buffer.write(sentence);
        continue;
      }

      final current = buffer.toString().trim();
      final combined = '$current $sentence'.trim();

      if (combined.length <= 120) {
        buffer
          ..clear()
          ..write(combined);
      } else {
        units.add(current);
        buffer
          ..clear()
          ..write(sentence);
      }
    }

    if (buffer.isNotEmpty) {
      units.add(buffer.toString().trim());
    }

    return units.where((e) => e.isNotEmpty).toList();
  }
}