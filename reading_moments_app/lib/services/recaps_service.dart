import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:reading_moments_app/core/env.dart';
import 'package:reading_moments_app/models/recap_item.dart';

class RecapsService {
  Future<List<RecapItem>> loadRecaps(int meetingId) async {
    final url = Uri.parse('$apiBaseUrl/meetings/$meetingId/recaps');
    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception('요약 조회 실패: ${res.statusCode}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['recaps'] as List)
        .map((e) => RecapItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<RecapItem> generateRecap({
    required int meetingId,
    required String hostUserId,
  }) async {
    final url = Uri.parse('$apiBaseUrl/meetings/$meetingId/generate-recap');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'hostUserId': hostUserId}),
    );

    if (res.statusCode != 200) {
      throw Exception('요약 생성 실패: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return RecapItem.fromJson(Map<String, dynamic>.from(data['recap']));
  }
}