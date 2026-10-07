import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/app_brand_title.dart';
import '../services/citation_service.dart';

class CitationGeneratorScreen extends StatefulWidget {
  const CitationGeneratorScreen({super.key});

  @override
  State<CitationGeneratorScreen> createState() =>
      _CitationGeneratorScreenState();
}

class _CitationGeneratorScreenState extends State<CitationGeneratorScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 2;
  late TabController _tabController;

  final CitationService _service = CitationService();

  // ---- Style ----
  String _style = 'APA 7';
  static const List<String> _styles = [
    'APA 7',
    'MLA 9',
    'Chicago',
    'IEEE',
    'Harvard',
  ];

  // ---- Manual fields ----
  final _titleCtrl = TextEditingController();
  final _authorsCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _journalCtrl = TextEditingController();
  final _publisherCtrl = TextEditingController();
  final _doiCtrl = TextEditingController();

  // ---- URL field ----
  final _urlCtrl = TextEditingController();

  // ---- PDF ----
  List<int>? _pickedPdfBytes;
  String? _pickedPdfName;

  // ---- Result ----
  String? _inText;
  String? _referenceList;
  String? _lastSource; // "manual" | "url" | "pdf"

  bool _isGenerating = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _authorsCtrl.dispose();
    _yearCtrl.dispose();
    _journalCtrl.dispose();
    _publisherCtrl.dispose();
    _doiCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // GENERATE
  // ============================================================
  Future<void> _generate() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isGenerating = true;
      _inText = null;
      _referenceList = null;
    });

    try {
      Map<String, dynamic>? res;
      String source;

      final tabIndex = _tabController.index;

      if (tabIndex == 0) {
        // PDF
        if (_pickedPdfBytes == null) {
          _showSnack('Please select a PDF first');
          setState(() => _isGenerating = false);
          return;
        }
        source = 'pdf';
        res = await _service.generateFromPdf(
          bytes: _pickedPdfBytes!,
          filename: _pickedPdfName ?? 'paper.pdf',
          style: _style,
        );
      } else if (tabIndex == 1) {
        // URL
        final url = _urlCtrl.text.trim();
        if (url.isEmpty) {
          _showSnack('Please paste a URL');
          setState(() => _isGenerating = false);
          return;
        }
        source = 'url';
        res = await _service.generateFromUrl(url, _style);
      } else {
        // Manual
        if (_titleCtrl.text.trim().isEmpty &&
            _authorsCtrl.text.trim().isEmpty) {
          _showSnack('Enter at least a title or an author');
          setState(() => _isGenerating = false);
          return;
        }
        source = 'manual';
        res = await _service.generateManual(
          title: _titleCtrl.text.trim(),
          authors: _authorsCtrl.text.trim(),
          year: _yearCtrl.text.trim(),
          journal: _journalCtrl.text.trim(),
          publisher: _publisherCtrl.text.trim(),
          doi: _doiCtrl.text.trim(),
          style: _style,
        );
      }

            if (!mounted) return;

      if (res == null) {
        _showSnack('Generation failed. Check the backend.');
        setState(() => _isGenerating = false);
        return;
      }

      // Extract BEFORE setState so Dart sees non-nullable values inside the closure
      final inText = (res['in_text'] ?? '').toString();
      final refList = (res['reference_list'] ?? '').toString();
      final src = source;

      setState(() {
        _inText = inText;
        _referenceList = refList;
        _lastSource = src;
        _isGenerating = false;
      });

    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      _showSnack('Error: $e');
    }
  }

  // ============================================================
  // SAVE
  // ============================================================
  Future<void> _save() async {
    if (_referenceList == null || _inText == null) {
      _showSnack('Nothing to save — generate a citation first');
      return;
    }
    setState(() => _isSaving = true);

    // Build the citation object from current form/state
    final meta = {
      'title': _titleCtrl.text.trim(),
      'authors': _authorsCtrl.text.trim(),
      'year': _yearCtrl.text.trim(),
      'journal': _journalCtrl.text.trim(),
    };

    final citation = _service.citationFromGenerateResponse(
      {
        'metadata': meta,
        'style': _style,
        'in_text': _inText,
        'reference_list': _referenceList,
      },
      sourceType: _lastSource ?? 'manual',
    );

    final ok = await _service.saveCitation(citation);
    if (!mounted) return;

    setState(() => _isSaving = false);
    _showSnack(ok ? 'Saved to your library' : 'Save failed');
  }

  void _copyReference() {
    if (_referenceList == null) return;
    Clipboard.setData(ClipboardData(text: _referenceList!));
    _showSnack('Copied to clipboard');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ============================================================
  // PDF PICKER
  // ============================================================
  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      List<int>? bytes = file.bytes;
      if (bytes == null && !kIsWeb && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) {
        _showSnack('Could not read PDF bytes');
        return;
      }
      setState(() {
        _pickedPdfBytes = bytes;
        _pickedPdfName = file.name;
      });
    } catch (e) {
      _showSnack('Pick failed: $e');
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const AppBrandTitle(),
      ),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Citation Generator',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Generate formatted citations in 5 styles',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Style chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _styles.map((s) {
                      final selected = s == _style;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s),
                          selected: selected,
                          onSelected: (_) => setState(() => _style = s),
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: selected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          backgroundColor: AppColors.white,
                          side: BorderSide(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textPrimary,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Upload Paper'),
                  Tab(text: 'Paste URL'),
                  Tab(text: 'Enter Manually'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tab content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IndexedStack(
                    index: _tabController.index,
                    sizing: StackFit.loose,
                    children: [
                      _buildPdfTab(),
                      _buildUrlTab(),
                      _buildManualTab(),
                    ],
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generate,
                      icon: _isGenerating
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        _isGenerating
                            ? 'Generating…'
                            : 'Generate Citation',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  if (_referenceList != null) ...[
                    const SizedBox(height: 20),
                    _buildResultCard(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          final route =
              AppConstants.bottomNavItems[index]['route'] as String;
          Navigator.of(context).pushReplacementNamed(route);
        },
      ),
    );
  }

  // ============================================================
  // TABS
  // ============================================================
  Widget _buildPdfTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickPdf,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.border,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.upload_file,
                    size: 40,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _pickedPdfName ?? 'Tap to choose a PDF',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'We extract metadata from the first 5 pages',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlTab() {
    return _buildFieldCard(
      children: [
        _textField(
          controller: _urlCtrl,
          label: 'Article URL',
          hint: 'https://example.com/article',
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  Widget _buildManualTab() {
    return _buildFieldCard(
      children: [
        _textField(controller: _titleCtrl, label: 'Title'),
        const SizedBox(height: 10),
        _textField(
          controller: _authorsCtrl,
          label: 'Authors',
          hint: 'Smith, J., Doe, A.',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _textField(
                controller: _yearCtrl,
                label: 'Year',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _textField(
                controller: _journalCtrl,
                label: 'Journal',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _textField(controller: _publisherCtrl, label: 'Publisher'),
        const SizedBox(height: 10),
        _textField(controller: _doiCtrl, label: 'DOI'),
      ],
    );
  }

  // ============================================================
  // RESULT CARD
  // ============================================================
  Widget _buildResultCard() {
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
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Generated Citation',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _style,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'In-text',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _inText ?? '',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Reference list',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _referenceList ?? '',
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyReference,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.bookmark_add, size: 18),
                  label: Text(_isSaving ? 'Saving…' : 'Save to Library'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Small helpers
  // ============================================================
  Widget _buildFieldCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 13),
        hintStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.hintText,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }
}