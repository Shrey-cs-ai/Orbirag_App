// Data models for Research Gap Analysis
// Handles serialization and deserialization for Matrix, Patterns, Gaps, Directions, and Reports.

class PaperEvidence {
  final String id;
  final String paperId;
  final String title;
  final String authors;
  final String year;
  final String venue;
  final String doi;
  final String url;
  final String objective;
  final String researchQuestion;
  final String population;
  final String dataset;
  final String methodology;
  final String evaluation;
  final String keyFindings;
  final String limitations;
  final String futureWork;

  PaperEvidence({
    required this.id,
    required this.paperId,
    required this.title,
    this.authors = '',
    this.year = '',
    this.venue = '',
    this.doi = '',
    this.url = '',
    this.objective = '',
    this.researchQuestion = '',
    this.population = '',
    this.dataset = '',
    this.methodology = '',
    this.evaluation = '',
    this.keyFindings = '',
    this.limitations = '',
    this.futureWork = '',
  });

  factory PaperEvidence.fromJson(Map<String, dynamic> json) {
    return PaperEvidence(
      id: (json['id'] ?? json['paper_id'] ?? '').toString(),
      paperId: (json['paper_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled') as String,
      authors: (json['authors'] ?? '') as String,
      year: (json['year'] ?? '').toString(),
      venue: (json['venue'] ?? '') as String,
      doi: (json['doi'] ?? '') as String,
      url: (json['url'] ?? '') as String,
      objective: (json['objective'] ?? '') as String,
      researchQuestion: (json['research_question'] ?? '') as String,
      population: (json['population'] ?? '') as String,
      dataset: (json['dataset'] ?? '') as String,
      methodology: (json['methodology'] ?? '') as String,
      evaluation: (json['evaluation'] ?? '') as String,
      keyFindings: (json['key_findings'] ?? '') as String,
      limitations: (json['limitations'] ?? '') as String,
      futureWork: (json['future_work'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'paper_id': paperId,
    'title': title,
    'authors': authors,
    'year': year,
    'venue': venue,
    'doi': doi,
    'url': url,
    'objective': objective,
    'research_question': researchQuestion,
    'population': population,
    'dataset': dataset,
    'methodology': methodology,
    'evaluation': evaluation,
    'key_findings': keyFindings,
    'limitations': limitations,
    'future_work': futureWork,
  };
}

class MatrixRow {
  final String id;
  final String paperId;
  final String title;
  final String authors;
  final String year;
  final String venue;
  final String doi;
  final String url;
  final String objective;
  final String researchQuestion;
  final String population;
  final String dataset;
  final String methodology;
  final String evaluation;
  final String keyFindings;
  final String limitations;
  final String futureWork;

  MatrixRow({
    required this.id,
    required this.paperId,
    required this.title,
    this.authors = '',
    this.year = '',
    this.venue = '',
    this.doi = '',
    this.url = '',
    this.objective = '',
    this.researchQuestion = '',
    this.population = '',
    this.dataset = '',
    this.methodology = '',
    this.evaluation = '',
    this.keyFindings = '',
    this.limitations = '',
    this.futureWork = '',
  });

  factory MatrixRow.fromJson(Map<String, dynamic> json) {
    return MatrixRow(
      id: (json['id'] ?? json['paper_id'] ?? '').toString(),
      paperId: (json['paper_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled') as String,
      authors: (json['authors'] ?? '') as String,
      year: (json['year'] ?? '').toString(),
      venue: (json['venue'] ?? '') as String,
      doi: (json['doi'] ?? '') as String,
      url: (json['url'] ?? '') as String,
      objective: (json['objective'] ?? '') as String,
      researchQuestion: (json['research_question'] ?? '') as String,
      population: (json['population'] ?? '') as String,
      dataset: (json['dataset'] ?? '') as String,
      methodology: (json['methodology'] ?? '') as String,
      evaluation: (json['evaluation'] ?? '') as String,
      keyFindings: (json['key_findings'] ?? '') as String,
      limitations: (json['limitations'] ?? '') as String,
      futureWork: (json['future_work'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'paper_id': paperId,
    'title': title,
    'authors': authors,
    'year': year,
    'venue': venue,
    'doi': doi,
    'url': url,
    'objective': objective,
    'research_question': researchQuestion,
    'population': population,
    'dataset': dataset,
    'methodology': methodology,
    'evaluation': evaluation,
    'key_findings': keyFindings,
    'limitations': limitations,
    'future_work': futureWork,
  };
}

class GapPattern {
  final List<String> concentrations;
  final List<String> absences;
  final List<String> contradictions;
  final List<String> methodologicalWeaknesses;
  final String summary;

  GapPattern({
    this.concentrations = const [],
    this.absences = const [],
    this.contradictions = const [],
    this.methodologicalWeaknesses = const [],
    this.summary = '',
  });

  factory GapPattern.fromJson(Map<String, dynamic> json) {
    return GapPattern(
      concentrations: (json['concentrations'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      absences: (json['absences'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      contradictions: (json['contradictions'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      methodologicalWeaknesses:
          (json['methodological_weaknesses'] as List? ?? [])
              .map((e) => e.toString())
              .toList(),
      summary: (json['summary'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'concentrations': concentrations,
    'absences': absences,
    'contradictions': contradictions,
    'methodological_weaknesses': methodologicalWeaknesses,
    'summary': summary,
  };
}

class GapCandidate {
  final String id;
  final String type;
  String claim;
  final String evidenceSummary;
  final List<String> supportingPapers;
  final List<String> contradictoryPapers;
  final String confidence;
  final String whyNotHigh;
  String userStatus; // 'accepted', 'rejected', 'uncertain', 'pending'

  GapCandidate({
    required this.id,
    required this.type,
    required this.claim,
    this.evidenceSummary = '',
    this.supportingPapers = const [],
    this.contradictoryPapers = const [],
    this.confidence = 'Moderate',
    this.whyNotHigh = 'N/A',
    this.userStatus = 'pending',
  });

  factory GapCandidate.fromJson(Map<String, dynamic> json) {
    return GapCandidate(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'methodological') as String,
      claim: (json['claim'] ?? '') as String,
      evidenceSummary: (json['evidence_summary'] ?? '') as String,
      supportingPapers: (json['supporting_papers'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      contradictoryPapers: (json['contradictory_papers'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      confidence: (json['confidence'] ?? 'Moderate') as String,
      whyNotHigh: (json['why_not_high'] ?? 'N/A') as String,
      userStatus: (json['user_status'] ?? 'pending') as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'claim': claim,
    'evidence_summary': evidenceSummary,
    'supporting_papers': supportingPapers,
    'contradictory_papers': contradictoryPapers,
    'confidence': confidence,
    'why_not_high': whyNotHigh,
    'user_status': userStatus,
  };
}

class ResearchDirection {
  final String id;
  final String researchQuestion;
  final String objective;
  final String hypothesis;
  final String rationale;

  ResearchDirection({
    required this.id,
    required this.researchQuestion,
    required this.objective,
    required this.hypothesis,
    required this.rationale,
  });

  factory ResearchDirection.fromJson(Map<String, dynamic> json) {
    return ResearchDirection(
      id: (json['id'] ?? '').toString(),
      researchQuestion: (json['research_question'] ?? '') as String,
      objective: (json['objective'] ?? '') as String,
      hypothesis: (json['hypothesis'] ?? '') as String,
      rationale: (json['rationale'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'research_question': researchQuestion,
    'objective': objective,
    'hypothesis': hypothesis,
    'rationale': rationale,
  };
}

class GapAnalysisResult {
  final String reportId;
  final List<MatrixRow> matrix;
  final GapPattern patterns;
  final List<GapCandidate> gaps;

  GapAnalysisResult({
    required this.reportId,
    required this.matrix,
    required this.patterns,
    required this.gaps,
  });

  factory GapAnalysisResult.fromJson(Map<String, dynamic> json) {
    return GapAnalysisResult(
      reportId: (json['report_id'] ?? '').toString(),
      matrix: (json['matrix'] as List? ?? [])
          .map((m) => MatrixRow.fromJson(m as Map<String, dynamic>))
          .toList(),
      patterns: GapPattern.fromJson(
        (json['patterns'] as Map<String, dynamic>?) ?? {},
      ),
      gaps: (json['gaps'] as List? ?? [])
          .map((g) => GapCandidate.fromJson(g as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GapReport {
  final String? id;
  final String? userId;
  final String topic;
  final String? researchQuestion;
  final List<String>? keywords;
  final Map<String, dynamic>? scopeFilters;
  final List<String> paperIds;
  final List<MatrixRow> matrix;
  final GapPattern? patterns;
  final List<GapCandidate> gaps;
  final GapCandidate? selectedGap;
  final List<ResearchDirection>? researchDirections;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GapReport({
    this.id,
    this.userId,
    required this.topic,
    this.researchQuestion,
    this.keywords,
    this.scopeFilters,
    this.paperIds = const [],
    this.matrix = const [],
    this.patterns,
    this.gaps = const [],
    this.selectedGap,
    this.researchDirections,
    this.status = 'draft',
    this.createdAt,
    this.updatedAt,
  });

  factory GapReport.fromJson(Map<String, dynamic> json) {
    return GapReport(
      id: json['id']?.toString(),
      userId: json['user_id']?.toString(),
      topic: (json['topic'] ?? 'Untitled Topic') as String,
      researchQuestion: json['research_question'] as String?,
      keywords: (json['keywords'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      scopeFilters: json['scope_filters'] as Map<String, dynamic>?,
      paperIds: (json['paper_ids'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      matrix: (json['matrix'] as List? ?? [])
          .map((m) => MatrixRow.fromJson(m as Map<String, dynamic>))
          .toList(),
      patterns: json['patterns'] != null
          ? GapPattern.fromJson(json['patterns'] as Map<String, dynamic>)
          : null,
      gaps: (json['gaps'] as List? ?? [])
          .map((g) => GapCandidate.fromJson(g as Map<String, dynamic>))
          .toList(),
      selectedGap: json['selected_gap'] != null
          ? GapCandidate.fromJson(json['selected_gap'] as Map<String, dynamic>)
          : null,
      researchDirections: (json['research_directions'] as List? ?? [])
          .map((d) => ResearchDirection.fromJson(d as Map<String, dynamic>))
          .toList(),
      status: (json['status'] ?? 'draft') as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (userId != null) 'user_id': userId,
    'topic': topic,
    if (researchQuestion != null) 'research_question': researchQuestion,
    'keywords': keywords ?? [],
    'scope_filters': scopeFilters ?? {},
    'paper_ids': paperIds,
    'matrix': matrix.map((m) => m.toJson()).toList(),
    'patterns': patterns?.toJson() ?? {},
    'gaps': gaps.map((g) => g.toJson()).toList(),
    if (selectedGap != null) 'selected_gap': selectedGap!.toJson(),
    'research_directions':
        researchDirections?.map((d) => d.toJson()).toList() ?? [],
    'status': status,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };
}
