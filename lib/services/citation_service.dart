class CitationService {
  CitationService._();
  static final CitationService instance = CitationService._();

  /// Generate In-Text + Reference from basic metadata
  Map<String, String> generate({
    required String authors,
    required String year,
    required String title,
    required String journal,
    String style = "APA 7",
  }) {
    final inText = _inText(authors, year, style);
    final reference = _reference(authors, year, title, journal, style);

    return {
      "inText": inText,
      "reference": reference,
      "style": style,
    };
  }

  String _inText(String authors, String year, String style) {
    // Simple APA-style for now (you can expand later)
    return "($authors, $year)";
  }

  String _reference(
    String authors,
    String year,
    String title,
    String journal,
    String style,
  ) {
    return "$authors ($year). $title. $journal.";
  }

  /// Quick citation from a matched source name (used by Plagiarism screen)
  String quickInTextFromSource(String sourceTitle, {String year = "2023"}) {
    // Extract a simple author-like name from source title if possible
    final short = sourceTitle.length > 30
        ? "${sourceTitle.substring(0, 30)}..."
        : sourceTitle;
    return "($short, $year)";
  }
}