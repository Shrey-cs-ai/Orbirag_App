import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get deepgramApiKey => dotenv.env['DEEPGRAM_API_KEY'] ?? '';
}