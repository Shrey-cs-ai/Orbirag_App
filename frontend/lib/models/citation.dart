class Citation {
  final String id;
  final String title;
  final String authors;
  final String year;
  final String journal;
  final String sourceType;
  final String style;
  final String inTextCitation;
  final String referenceList;
  final DateTime savedAt;

  Citation({
    required this.id,
    required this.title,
    required this.authors,
    required this.year,
    required this.journal,
    required this.sourceType,
    required this.style,
    required this.inTextCitation,
    required this.referenceList,
    required this.savedAt,
  });

  factory Citation.fromJson(Map<String, dynamic> json) {
    return Citation(
      id: (json['id'] ?? '').toString(),
      title: json['title'] ?? '',
      authors: json['authors'] ?? '',
      year: json['year']?.toString() ?? '',
      journal: json['journal'] ?? '',
      sourceType: json['source_type'] ?? '',
      style: json['style'] ?? '',
      inTextCitation: json['in_text'] ?? '',
      referenceList: json['reference_list'] ?? '',
      savedAt: json['saved_at'] != null
            ? DateTime.parse(json['saved_at'])
            : DateTime.now(),
      );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'authors': authors,
        'year': year,
        'journal': journal,
        'source_type': sourceType,
        'style': style,
        'in_text': inTextCitation,
        'reference_list': referenceList,
        'saved_at': savedAt.toIso8601String(),
      };
}