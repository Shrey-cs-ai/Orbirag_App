import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/app_colors.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/citation_service.dart';
import 'notebook_llm_screen.dart';
import 'home_screen.dart';
import 'ori_chatbot_screen.dart';
import 'literature_retrieval_screen.dart';
import 'profile_screen.dart';

class CitationGenerationScreen extends StatefulWidget {
  const CitationGenerationScreen({super.key});

  @override
  State<CitationGenerationScreen> createState() =>
      _CitationGenerationScreenState();
}

class _CitationGenerationScreenState extends State<CitationGenerationScreen> {
  int _selectedTab = 2; // 0 = Upload, 1 = Paste URL, 2 = Enter Manually
  final int _currentIndex = 2; // Research tab
  String _selectedStyle = "APA 7";
  bool _showResult = false;

  final _titleController = TextEditingController(
    text: "The impact of artificial intelligence on academic research methodologies",
  );
  final _authorController = TextEditingController(text: "Smith, J., & Doe, A.");
  final _yearController = TextEditingController(text: "2024");
  final _journalController =
      TextEditingController(text: "Journal of Future Learning");
  final _urlController = TextEditingController();

  final List<String> _styles = ["APA 7", "MLA 9", "Chicago", "IEEE", "Harvard"];
  final List<String> _sourceTypes = [
    "Journal Article",
    "Book",
    "Website",
    "Conference Paper",
    "Thesis",
  ];
  String _selectedSourceType = "Journal Article";

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _yearController.dispose();
    _journalController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _onBottomNavTap(int index) {
    if (index == _currentIndex) return;

    Widget screen;
    switch (index) {
      case 0:
        screen = const HomeScreen();
        break;
      case 1:
        screen = const OriChatScreen();
        break;
      case 2:
        screen = const LiteratureRetrievalScreen();
        break;
      case 3:
        screen = const ProfileScreen();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _generateCitation() {
    if (_titleController.text.trim().isEmpty ||
        _authorController.text.trim().isEmpty ||
        _yearController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill Title, Author(s) and Year")),
      );
      return;
    }
    setState(() => _showResult = true);
  }

  String get _inTextCitation {
    final authors = _authorController.text;
    final year = _yearController.text;
    return "($authors, $year)";
  }

  String get _referenceList {
    return "${_authorController.text} (${_yearController.text}). "
        "${_titleController.text}. "
        "${_journalController.text}.";
  }

  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Copied to clipboard")),
    );
  }


  Future<void> _saveCitation() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot save an empty citation")),
      );
      return;
    }

    final citation = Citation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      authors: _authorController.text.trim(),
      year: _yearController.text.trim(),
      journal: _journalController.text.trim(),
      sourceType: _selectedSourceType,
      style: _selectedStyle,
      inTextCitation: _inTextCitation,
      referenceList: _referenceList,
      savedAt: DateTime.now(),
    );

    await CitationService.instance.saveCitation(citation);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Citation saved to your Library!"),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _pickPDF() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) return;

      final fileName = result.files.first.name;
      
      // Auto-fill Title from filename
      final cleanTitle = fileName
          .replaceAll('.pdf', '')
          .replaceAll('_', ' ')
          .replaceAll('-', ' ');

      if (!mounted) return;

      setState(() {
        _titleController.text = cleanTitle;
        _authorController.text = "Author, A."; // Default
        _yearController.text = DateTime.now().year.toString();
        _journalController.text = "Extracted from PDF";
        _selectedTab = 2; // Switch to Manual Form so user can edit
        _showResult = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("PDF selected! Title auto-filled. Please verify details."),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking PDF: $e")),
      );
    }
  }

  Future<void> _processURL() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please paste a URL")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Extracting metadata...")),
    );

    try {
      // Check if it's a DOI link
      if (url.contains('doi.org')) {
        final doi = url.split('doi.org/').last;
        
        // Fetch from Crossref API (Free, no backend needed)
        final response = await http.get(
          Uri.parse('https://api.crossref.org/works/$doi'),
          headers: {'User-Agent': 'Orbirag/1.0 (mailto:your@email.com)'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body)['message'];
          
          final title = data['title']?[0] ?? '';
          final authorsList = (data['author'] as List?)
              ?.map((a) => '${a['family']}, ${a['given']}')
              .join(', ') ?? '';
          final year = data['published-print']?['date-parts']?[0]?[0]?.toString() ?? 
                       data['published-online']?['date-parts']?[0]?[0]?.toString() ?? '';
          final journal = data['container-title']?[0] ?? '';

          if (!mounted) return;

          setState(() {
            _titleController.text = title;
            _authorController.text = authorsList;
            _yearController.text = year;
            _journalController.text = journal;
            _selectedTab = 2; // Switch to Manual Form
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Metadata extracted successfully!"),
              backgroundColor: AppColors.success,
            ),
          );
          return;
        }
      }

      // Fallback if not a DOI or extraction fails
      if (!mounted) return;
      setState(() => _selectedTab = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Could not extract metadata. Please enter manually."),
          backgroundColor: AppColors.warning,
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          "Orbirag",
          style: TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotebookLLMScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Generate Citation",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              "Instantly format references from papers, links, or manual entry.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildTab("Upload Paper", 0),
                  _buildTab("Paste URL", 1),
                  _buildTab("Enter Manually", 2),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Content based on tab
            if (_selectedTab == 0) _buildUploadSection(),
            if (_selectedTab == 1) _buildPasteUrlSection(),
            if (_selectedTab == 2) _buildManualForm(),

            const SizedBox(height: 20),

            // Generate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generateCitation,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text("Generate Citation"),
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

            // Generated Citation
            if (_showResult) ...[
              const SizedBox(height: 28),
              const Text(
                "Generated Citation",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // Style selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _styles.map((style) {
                    final isSelected = _selectedStyle == style;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(style),
                        selected: isSelected,
                        onSelected: (_) =>
                            setState(() => _selectedStyle = style),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color:
                              isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // In-Text Citation
              _buildCitationBox(
                title: "In-Text Citation",
                content: _inTextCitation,
              ),
              const SizedBox(height: 12),

              // Reference List
              _buildCitationBox(
                title: "Reference List",
                content: _referenceList,
                showAiBadge: true,
              ),
              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveCitation,
                  icon: const Icon(Icons.bookmark_border),
                  label: const Text("Save to Library"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }

  // ===================== TAB CONTENTS =====================

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedTab = index;
          _showResult = false;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4)
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return GestureDetector(
      onTap: _pickPDF,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          children: [
            Icon(Icons.upload_file, size: 40, color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              "Upload Paper (PDF)",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              "We will auto-fill title, authors, year & journal",
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasteUrlSection() {
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
          const Text("Paper URL",
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: "https://doi.org/...",
              filled: true,
              fillColor: AppColors.cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _processURL,
              child: const Text("Extract Metadata"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualForm() {
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
          const Text("Source Type",
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedSourceType,
            items: _sourceTypes
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedSourceType = val);
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text("Title", style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            maxLines: 2,
            decoration: _inputDecoration(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Author(s)",
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _authorController,
                      decoration: _inputDecoration(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Year",
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text("Journal / Publisher",
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: _journalController,
            decoration: _inputDecoration(),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.cardBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildCitationBox({
    required String title,
    required String content,
    bool showAiBadge = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              if (showAiBadge)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.lightPurple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 12, color: AppColors.purple),
                      SizedBox(width: 4),
                      Text("AI Detected",
                          style:
                              TextStyle(fontSize: 11, color: AppColors.purple)),
                    ],
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => _copyText(content),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}