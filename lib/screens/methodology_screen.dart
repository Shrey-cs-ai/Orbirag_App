import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../services/methodology_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/methodology_form.dart';
import 'home_screen.dart';
import 'ori_chatbot_screen.dart';
import 'literature_retrieval_screen.dart';
import 'profile_screen.dart';

class MethodologyScreen extends StatefulWidget {
  final String? paperTitle;

  const MethodologyScreen({super.key, this.paperTitle});

  @override
  State<MethodologyScreen> createState() => _MethodologyScreenState();
}

class _MethodologyScreenState extends State<MethodologyScreen> {
  final int _currentIndex = 2;
  final MethodologyService _service = MethodologyService.instance;
  final TextEditingController _textController = TextEditingController();

  MethodologyData? _extractedData;
  bool _isExtracting = false;
  bool _hasExtracted = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // ==================== ACTIONS ====================

  Future<void> _extract() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showMessage('Please paste the methods section first');
      return;
    }

    setState(() {
      _isExtracting = true;
      _hasExtracted = false;
    });

    final result = await _service.extractMethodology(text);

    if (!mounted) return;
    setState(() {
      _extractedData = result ?? MethodologyData(rawHighlightedText: text);
      _isExtracting = false;
      _hasExtracted = true;
    });

    if (result == null) {
      _showMessage('Could not auto-extract. Please fill in manually.');
    }
  }

  void _saveMethodology(MethodologyData data) async {
    final success = await _service.saveMethodology(data);
    if (!mounted) return;
    _showMessage(success ? '✅ Methodology saved' : '❌ Save failed');
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _onBottomNavTap(int index) {
    if (index == 2) return;

    switch (index) {
      case 0:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OriChatScreen()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
        break;
    }
  }

  // ==================== BUILD ====================

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
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          AppConstants.appName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_outlined, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.pushNamed(context, AppConstants.routePaperOrbit);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            const Text(
              'Methodology Extraction',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.paperTitle ?? 'Paste the methods section to extract structured fields',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // PASTE SECTION
            _buildPasteSection(),
            const SizedBox(height: 16),

            // EXTRACT BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isExtracting ? null : _extract,
                icon: _isExtracting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  _isExtracting ? 'Extracting...' : 'Extract with AI',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // RESULT FORM
            if (_hasExtracted && _extractedData != null) ...[
              const SizedBox(height: 24),
              MethodologyForm(
                initialData: _extractedData!,
                onSave: _saveMethodology,
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }

  Widget _buildPasteSection() {
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
          const Row(
            children: [
              Icon(Icons.description_outlined,
                  size: 16, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'Methods Section Text',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _textController,
            maxLines: 6,
            style: const TextStyle(fontSize: 14, height: 1.5),
            decoration: const InputDecoration(
              hintText:
                  'Paste the highlighted methods text from the paper here...',
              hintStyle: TextStyle(color: AppColors.hintText, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.auto_awesome,
                  size: 12, color: AppColors.purple),
              SizedBox(width: 4),
              Text(
                'AI will extract structured fields from this text',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}