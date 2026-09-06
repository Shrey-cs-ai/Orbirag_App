import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/app_scaffold.dart';

class PlagiarismCheckScreen extends StatelessWidget {
  const PlagiarismCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Orbirag",
      actions: [
        IconButton(icon: const Icon(Icons.bolt_outlined), onPressed: () {}),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Check Similarity",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              "Verify your document against billions of sources.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Similarity Score Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Similarity Score", style: TextStyle(fontWeight: FontWeight.w600)),
                      const Text("18%", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text("Low Similarity", style: TextStyle(color: Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.verified, size: 16, color: AppColors.primaryLight),
                      const SizedBox(width: 4),
                      const Text("AI Scanned", style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Info box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.primaryLight),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "A similarity match does not necessarily mean plagiarism. Review highlighted sections carefully to ensure proper citation.",
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Matched Text Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Matched Text", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text("12 Matches Found", style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sample matched paragraph
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
                  children: [
                    TextSpan(text: "The integration of artificial intelligence in educational technologies has shown "),
                    TextSpan(
                      text: "promising results. However, the reliance on automated systems for critical evaluation requires careful consideration of algorithmic bias. This is particularly",
                      style: TextStyle(backgroundColor: Color(0xFFE0E7FF)),
                    ),
                    TextSpan(text: " true in systems designed to assess student writing and originality.\n\nFurthermore, qualitative research suggests that "),
                    TextSpan(
                      text: "students often feel",
                      style: TextStyle(backgroundColor: Color(0xFFFEE2E2)),
                    ),
                    TextSpan(text: " disconnected from feedback generated by machines."),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Match Card
            _buildMatchCard(
              matchNumber: 3,
              percentage: "92%",
              words: "34 matching words",
              source: "Pedagogical Balancing in AI Systems",
              excerpt: "...the primary challenge lies in balancing scale with personalized pedagogical...",
            ),

            const SizedBox(height: 20),

            // Report Summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Report Summary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBox("Original Content", "82%"),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatBox("Total Words", "7,842"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download),
                      label: const Text("Download PDF Report"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () {},
                      child: const Text("Run Check Again", style: TextStyle(color: AppColors.primary)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Center(
              child: Text(
                "Orbirag promotes academic integrity. Users are responsible for ensuring their work meets institutional guidelines.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchCard({
    required int matchNumber,
    required String percentage,
    required String words,
    required String source,
    required String excerpt,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primary,
                child: Text("$matchNumber", style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Text("Match #$matchNumber", style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(percentage, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(words, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          const Text("SOURCE IDENTIFIED", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(source, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(excerpt, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          Row(
            children: [
              _actionChip("Cite", Icons.format_quote),
              const SizedBox(width: 8),
              _actionChip("Paraphrase", Icons.auto_fix_high),
              const SizedBox(width: 8),
              _actionChip("Humanize", Icons.person_outline),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _tag("Academic"),
              const SizedBox(width: 6),
              _tag("Simple"),
              const SizedBox(width: 6),
              _tag("Concise"),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightPurple,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: AppColors.purple),
                    SizedBox(width: 6),
                    Text("AI SUGGESTION", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.purple)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "The main difficulty is finding an equilibrium between widespread implementation and tailored educational support.",
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text("Replace"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Keep Original"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.visibility_off, size: 16),
              label: const Text("Exclude Match"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _actionChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}