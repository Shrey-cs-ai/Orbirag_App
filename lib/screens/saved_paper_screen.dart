import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/app_scaffold.dart';

class SavedPapersScreen extends StatefulWidget {
  const SavedPapersScreen({super.key});

  @override
  State<SavedPapersScreen> createState() => _SavedPapersScreenState();
}

class _SavedPapersScreenState extends State<SavedPapersScreen> {
  int _selectedFilter = 0; // 0=All, 1=Recent, 2=To Read, 3=Analyzed
  final List<String> _filters = ["All", "Recent", "To Read", "Analyzed"];

  final List<Map<String, dynamic>> _papers = [
    {
      "category": "QUALITATIVE METHODS • 2024",
      "title": "The Impact of AI on Qualitative Research",
      "authors": "Smith, J., et al. Exploring the methodological shifts and ethical...",
      "status": "analyzed",
      "progress": null,
    },
    {
      "category": "EDUCATION • 2023",
      "title": "Foundations of Modern Pedagogy",
      "authors": "Johnson, M. A comprehensive review of evolving pedagogical...",
      "status": "reading",
      "progress": 0.65,
    },
    {
      "category": "COMPUTER SCIENCE • 2022",
      "title": "Neural Networks for Beginners",
      "authors": "Lee, K., Patel, R. An accessible introduction to the underlying...",
      "status": "unread",
      "progress": null,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Orbirag",
      actions: [
        IconButton(
          icon: const Icon(Icons.bolt_outlined),
          onPressed: () {},
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Paper", style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Saved Papers",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              "Your personal academic library.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Search
            TextField(
              decoration: InputDecoration(
                hintText: "Search saved papers...",
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_filters.length, (index) {
                  final isSelected = _selectedFilter == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_filters[index]),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedFilter = index),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),

            // Papers list
            ..._papers.map((paper) => _buildPaperCard(paper)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperCard(Map<String, dynamic> paper) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
              Expanded(
                child: Text(
                  paper["category"],
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textSecondary),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            paper["title"],
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            paper["authors"],
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          // Status row
          if (paper["status"] == "analyzed")
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lightPurple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 12, color: AppColors.purple),
                      SizedBox(width: 4),
                      Text("Analyzed by OrbiRAG", style: TextStyle(fontSize: 11, color: AppColors.purple)),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Text("Read →", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            )
          else if (paper["status"] == "reading")
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: paper["progress"],
                          backgroundColor: AppColors.cardBg,
                          color: AppColors.success,
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "${(paper["progress"] * 100).toInt()}% Read",
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.menu_book, size: 16),
                    label: const Text("Continue"),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text("Unread", style: TextStyle(fontSize: 12)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Text("Start Reading →", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}