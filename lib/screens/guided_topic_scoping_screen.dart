import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../services/scoping_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_screen.dart';
import 'ori_chatbot_screen.dart';
import 'literature_retrieval_screen.dart';
import 'profile_screen.dart';

class GuidedTopicScopingScreen extends StatefulWidget {
  const GuidedTopicScopingScreen({super.key});

  @override
  State<GuidedTopicScopingScreen> createState() =>
      _GuidedTopicScopingScreenState();
}

class _GuidedTopicScopingScreenState extends State<GuidedTopicScopingScreen> {
  final int _currentIndex = 0;
  final ScopingService _service = ScopingService.instance;
  final TextEditingController _topicController = TextEditingController();

  // Wizard state
  int _currentStep = 0; // 0 = topic, 1-4 = PICO, 5 = synthesis
  ScopingData _data = ScopingData();
  bool _isLoading = false;

  // Field controllers
  final Map<String, TextEditingController> _fieldControllers = {
    'population': TextEditingController(),
    'intervention': TextEditingController(),
    'comparison': TextEditingController(),
    'outcome': TextEditingController(),
  };

  final List<Map<String, String>> _picoFields = [
    {
      'key': 'population',
      'label': 'Population',
      'hint': 'Who are you studying?',
      'example': 'Adolescents aged 13–18',
    },
    {
      'key': 'intervention',
      'label': 'Intervention / Focus',
      'hint': 'What is being studied?',
      'example': 'Algorithmic short-form video feeds',
    },
    {
      'key': 'comparison',
      'label': 'Comparison (optional)',
      'hint': 'What is it compared to?',
      'example': 'Active messaging platforms',
    },
    {
      'key': 'outcome',
      'label': 'Outcome',
      'hint': 'What is the effect?',
      'example': 'Anxiety symptom severity',
    },
  ];

  @override
  void dispose() {
    _topicController.dispose();
    for (var c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ==================== ACTIONS ====================

  Future<void> _parseTopic() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      _showMessage('Please enter a topic');
      return;
    }

    setState(() => _isLoading = true);

    final result = await _service.parseTopic(topic);

    if (!mounted) return;
    setState(() {
      _data = result ?? ScopingData(topic: topic);
      _fieldControllers['population']!.text = _data.population;
      _fieldControllers['intervention']!.text = _data.intervention;
      _fieldControllers['comparison']!.text = _data.comparison;
      _fieldControllers['outcome']!.text = _data.outcome;
      _isLoading = false;
      _currentStep = 1;
    });
  }

  void _nextStep() {
    // Save current field
    final key = _picoFields[_currentStep - 1]['key']!;
    _data.population = _fieldControllers['population']!.text;
    _data.intervention = _fieldControllers['intervention']!.text;
    _data.comparison = _fieldControllers['comparison']!.text;
    _data.outcome = _fieldControllers['outcome']!.text;

    if (_currentStep < 4) {
      setState(() => _currentStep++);
    } else {
      _synthesize();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _synthesize() async {
    setState(() => _isLoading = true);

    final question = await _service.synthesizeQuestion(_data);

    if (!mounted) return;
    setState(() {
      _data.researchQuestion = question ?? '';
      _isLoading = false;
      _currentStep = 5;
    });
  }

  void _startSearch() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LiteratureRetrievalScreen(
          initialQuery: _data.researchQuestion.isNotEmpty
              ? _data.researchQuestion
              : _data.topic,
        ),
      ),
    );
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _onBottomNavTap(int index) {
    if (index == 0) return;

    switch (index) {
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OriChatScreen()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => const LiteratureRetrievalScreen()),
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentStep > 0 && _currentStep < 5)
                    _buildProgressBar(),
                  const SizedBox(height: 16),
                  _buildCurrentStep(),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }

  // ==================== STEP BUILDER ====================

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildTopicStep();
      case 1:
      case 2:
      case 3:
      case 4:
        return _buildPicoStep(_currentStep - 1);
      case 5:
        return _buildSynthesisStep();
      default:
        return const SizedBox();
    }
  }

  // ==================== STEP 1: TOPIC ====================

  Widget _buildTopicStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Text(
          "What's on your mind?",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter a rough topic or research idea. AI will refine it into a structured question.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // Topic input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'RESEARCH PREMISE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _topicController,
                maxLines: 5,
                autofocus: true,
                style: const TextStyle(fontSize: 15, height: 1.5),
                decoration: const InputDecoration(
                  hintText: 'e.g., impact of algorithmic feeds on teen anxiety',
                  hintStyle:
                      TextStyle(color: AppColors.hintText, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Info card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.lightPurple.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome, size: 18, color: AppColors.purple),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Don't worry about academic phrasing. AI will extract population, intervention, and outcome for you.",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Continue button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _parseTopic,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Continue to Scoping'),
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
      ],
    );
  }

  // ==================== STEP 2-5: PICO FIELDS ====================

  Widget _buildProgressBar() {
    return Row(
      children: List.generate(4, (index) {
        final isActive = index < _currentStep;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPicoStep(int index) {
    final field = _picoFields[index];
    final key = field['key']!;
    final controller = _fieldControllers[key]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step counter
        Text(
          'STEP ${index + 1} OF 4',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.purple,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),

        // Title
        Text(
          field['hint']!,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'AI has pre-filled this — edit or refine it.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // Input card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                field['label']!.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 3,
                style: const TextStyle(fontSize: 15, height: 1.4),
                decoration: InputDecoration(
                  hintText: field['example'],
                  hintStyle: const TextStyle(
                    color: AppColors.hintText,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Navigation buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _nextStep,
                icon: Icon(
                  index == 3 ? Icons.auto_awesome : Icons.arrow_forward,
                  size: 16,
                ),
                label: Text(index == 3 ? 'Synthesize' : 'Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== STEP 6: SYNTHESIS ====================

  Widget _buildSynthesisStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 12, color: AppColors.success),
                  SizedBox(width: 4),
                  Text(
                    'SCOPING COMPLETE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        const Text(
          'Your Scoped Research Question',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Review and refine before starting your search.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // Question card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.lightPurple,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 11, color: AppColors.purple),
                        SizedBox(width: 4),
                        Text(
                          'AI Synthesized',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.purple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _synthesize,
                    child: const Row(
                      children: [
                        Icon(Icons.refresh,
                            size: 14, color: AppColors.purple),
                        SizedBox(width: 4),
                        Text(
                          'Regenerate',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.purple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _data.researchQuestion.isNotEmpty
                    ? _data.researchQuestion
                    : 'Research question',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // PICO Summary
        const Text(
          'MAPPED EVIDENCE TAXONOMY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        _buildPicoSummaryRow('Population', _data.population, Icons.people),
        _buildPicoSummaryRow(
            'Intervention', _data.intervention, Icons.bolt),
        if (_data.comparison.isNotEmpty)
          _buildPicoSummaryRow(
              'Comparison', _data.comparison, Icons.compare_arrows),
        _buildPicoSummaryRow(
            'Outcome', _data.outcome, Icons.track_changes),

        const SizedBox(height: 24),

        // Start search button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startSearch,
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Start Search'),
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
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
            child: const Text(
              'Save to My Library & Exit',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPicoSummaryRow(String label, String value, IconData icon) {
    if (value.isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle,
              size: 14, color: AppColors.success),
        ],
      ),
    );
  }
}