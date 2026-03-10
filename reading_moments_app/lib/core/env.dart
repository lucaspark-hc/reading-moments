import 'package:flutter_dotenv/flutter_dotenv.dart';

String get apiBaseUrl =>
    dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:3000';