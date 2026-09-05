import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get openAiApiKey {
    return dotenv.env['OPENAI_API_KEY'] ?? '';
  }
}