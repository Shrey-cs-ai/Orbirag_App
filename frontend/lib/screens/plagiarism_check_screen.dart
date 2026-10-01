import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';
import '../services/plagiarism_service.dart';

class PlagiarismScreen extends StatefulWidget {
  const PlagiarismScreen({super.key});

  @override
  State<PlagiarismScreen> createState() => _PlagiarismScreenState();
}

class _PlagiarismScreenState extends State<PlagiarismScreen> {
  final TextEditingController _textController = TextEditingController();
  final PlagiarismService _service = PlagiarismService.instance;

  bool _isChecking = false;
  PlagiarismResult? _result;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _runCheck() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text first')),
      );
      return;
    }

    if (text.split(' ').length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least 20 words')),
      );
      return;
    }

    setState(() {
      _isChecking = true;
      _result = null;
    });

    final result = await _service.check(text: text);

    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _result = result;
    });

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check failed — is the backend running?'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Color _scoreColor(double score) {
    if (score < 20) return Colors.green;
    if (score < 50) return Colors.orange;
    return Colors.red;
  }

  void _loadSample() {
    _textController.text =
        "Artificial intelligence has transformed modern medicine by enabling "
        "faster and more accurate diagnoses. Machine learning models have been "
        "shown to outperform traditional statistical methods in several domains. "
        "The integration of AI into clinical workflows remains a critical "
        "challenge. Recent studies indicate that deep learning techniques "
        "can reduce diagnostic time by up to forty percent.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Plagiarism Check',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Load sample',
            onPressed: _loadSample,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste your text',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'We will check for copied phrases, generic writing, and matches against your saved library.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Text input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _textController,
                maxLines: 10,
                minLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Paste your paragraph, essay, or abstract here...',
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Check button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isChecking ? null : _runCheck,
                icon: _isChecking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.search, size: 18),
                label: Text(_isChecking ? 'Checking...' : 'Run Plagiarism Check'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // Results
            if (_result != null) ...[
              const SizedBox(height: 28),
              _buildScoreCard(_result!),
              const SizedBox(height: 20),
              _buildStats(_result!),
              const SizedBox(height: 20),
              if (_result!.matches.isNotEmpty) _buildMatches(_result!),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(PlagiarismResult r) {
    final color = _scoreColor(r.score);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            '${r.score.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            r.score < 20
                ? 'Looks original'
                : r.score < 50
                    ? 'Some phrases need attention'
                    : 'High similarity detected',
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            r.summary,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(PlagiarismResult r) {
    return Row(
      children: [
        _statCard('Words', '${r.totalWords}', Icons.text_fields),
        const SizedBox(width: 12),
        _statCard('Unique', '${r.uniqueWords}', Icons.fingerprint),
        const SizedBox(width: 12),
        _statCard('Flagged', '${r.flaggedCount}', Icons.flag_outlined),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatches(PlagiarismResult r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Flagged Sections',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...r.matches.map((m) => _matchCard(m)),
      ],
    );
  }

  Widget _matchCard(PlagiarismMatch m) {
    final color = _scoreColor(m.similarity * 100);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${(m.similarity * 100).toStringAsFixed(0)}% match',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: m.matchedText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            m.source,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '"${m.matchedText}"',
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
          if (m.reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              m.reason,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}