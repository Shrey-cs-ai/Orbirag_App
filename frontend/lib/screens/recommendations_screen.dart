import 'package:flutter/material.dart';
import '../services/recommendation_service.dart';
import '../services/search_service.dart';
import '../utils/app_colors.dart';
import 'literature_retrieval_screen.dart';
import 'paper_orbit_screen.dart';

class RecommendationsScreen extends StatefulWidget {
  final List<SearchResult>? initialRecommendations;

  const RecommendationsScreen({
    super.key,
    this.initialRecommendations,
  });

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final RecommendationService _recommendationService =
      RecommendationService.instance;
  final SearchService _searchService = SearchService.instance;

  List<SearchResult> _recommendations = [];
  bool _isLoading = false;
  final Set<String> _savedTitles = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialRecommendations != null &&
        widget.initialRecommendations!.isNotEmpty) {
      _recommendations = List.from(widget.initialRecommendations!);
    } else {
      _loadRecommendations();
    }
  }

  Future<void> _loadRecommendations() async {
    setState(() => _isLoading = true);
    final results = await _recommendationService.getRecommendations(limit: 15);
    if (!mounted) return;
    setState(() {
      _recommendations = results;
      _isLoading = false;
    });
  }

  Future<void> _savePaper(SearchResult paper) async {
    final success = await _searchService.savePaper(paper);
    if (!mounted) return;
    if (success) {
      setState(() {
        _savedTitles.add(paper.title);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Saved to library'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to save paper'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Recommended for You",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _isLoading ? null : _loadRecommendations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _recommendations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadRecommendations,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _recommendations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final paper = _recommendations[index];
                      return _buildPaperCard(paper);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_awesome_outlined,
              size: 56,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              "No recommendations yet",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Start searching or saving papers to get personalized AI recommendations tailored to your research.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LiteratureRetrievalScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Search Papers",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperCard(SearchResult paper) {
    final isSaved = _savedTitles.contains(paper.title);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  paper.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
              if (paper.citations > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${paper.citations} citations",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "${paper.authors} • ${paper.year.isNotEmpty ? paper.year : 'Recent'}",
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (paper.venue.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              paper.venue,
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (paper.aiSummary.isNotEmpty || paper.abstract.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              paper.aiSummary.isNotEmpty ? paper.aiSummary : paper.abstract,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _savePaper(paper),
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  size: 16,
                  color: isSaved ? AppColors.primary : AppColors.textPrimary,
                ),
                label: Text(
                  isSaved ? "Saved" : "Save",
                  style: TextStyle(
                    fontSize: 12,
                    color: isSaved ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: BorderSide(
                    color: isSaved ? AppColors.primary : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PaperOrbitScreen(paperTitle: paper.title),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text(
                  "Orbit",
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LiteratureRetrievalScreen(
                        initialQuery: paper.title,
                      ),
                    ),
                  );
                },
                child: const Text(
                  "Search Related →",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
