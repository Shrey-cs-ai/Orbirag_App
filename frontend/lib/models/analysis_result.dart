class TextStats {
  final int words;
  final int characters;
  final int sentences;

  TextStats({required this.words, required this.characters, required this.sentences});

  factory TextStats.fromJson(Map<String, dynamic> json) {
    return TextStats(
      words: json['words'] ?? 0,
      characters: json['characters'] ?? 0,
      sentences: json['sentences'] ?? 0,
    );
  }
}

class Suggestion {
  final String id;
  final String type;
  final String original;
  final String replacement;
  final String message;
  final int start;
  final int end;

  Suggestion({
    required this.id,
    required this.type,
    required this.original,
    required this.replacement,
    required this.message,
    required this.start,
    required this.end,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      id: json['id'] ?? '',
      type: json['type'] ?? 'suggestion',
      original: json['original'] ?? '',
      replacement: json['replacement'] ?? '',
      message: json['message'] ?? '',
      start: json['start'] ?? 0,
      end: json['end'] ?? 0,
    );
  }
}

class AnalysisResult {
  final TextStats stats;
  final List<Suggestion> suggestions;

  AnalysisResult({required this.stats, required this.suggestions});

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      stats: TextStats.fromJson(json['stats'] ?? {}),
      suggestions: (json['suggestions'] as List? ?? [])
          .map((s) => Suggestion.fromJson(s))
          .toList(),
    );
  }
}