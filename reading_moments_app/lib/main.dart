import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnon = dotenv.env['SUPABASE_ANON_KEY'];

  debugPrint('SUPABASE_URL=$supabaseUrl');
  debugPrint(
    'SUPABASE_ANON_KEY loaded=${supabaseAnon != null && supabaseAnon.isNotEmpty}',
  );

  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      supabaseAnon == null ||
      supabaseAnon.isEmpty) {
    throw Exception('❌ .env에 SUPABASE_URL / SUPABASE_ANON_KEY가 없습니다.');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnon,
  );

  runApp(const ReadingMomentsApp());
}