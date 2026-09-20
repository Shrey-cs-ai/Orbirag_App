import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../services/methodology_service.dart';

class MethodologyForm extends StatefulWidget {
  final MethodologyData initialData;
  final Function(MethodologyData) onSave;

  const MethodologyForm({
    super.key,
    required this.initialData,
    required this.onSave,
  });

  @override
  State<MethodologyForm> createState() => _MethodologyFormState();
}

class _MethodologyFormState extends State<MethodologyForm> {
  late MethodologyData _data;
  late Map<String, TextEditingController> _controllers;

  final List<Map<String, String>> _studyTypes = [
    {'key': 'quantitative', 'label': 'Quantitative'},
    {'key': 'qualitative', 'label': 'Qualitative'},
    {'key': 'mixed-methods', 'label': 'Mixed Methods'},
    {'key': 'systematic-review', 'label': 'Systematic Review'},
    {'key': 'case-study', 'label': 'Case Study'},
    {'key': 'other', 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _controllers = {
      'design': TextEditingController(text: _data.design),
      'sampleSize': TextEditingController(text: _data.sampleSize),
      'samplingMethod': TextEditingController(text: _data.samplingMethod),
      'dataCollection': TextEditingController(text: _data.dataCollection),
      'analysisMethod': TextEditingController(text: _data.analysisMethod),
      'databasesSearched':
          TextEditingController(text: _data.databasesSearched),
      'inclusionCriteria':
          TextEditingController(text: _data.inclusionCriteria),
      'exclusionCriteria':
          TextEditingController(text: _data.exclusionCriteria),
      'studiesIncludedCount':
          TextEditingController(text: _data.studiesIncludedCount),
      'additionalNotes': TextEditingController(text: _data.additionalNotes),
    };
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Show only fields relevant to the selected study type
  List<String> get _relevantFields {
    switch (_data.studyType) {
      case 'quantitative':
      case 'mixed-methods':
        return [
          'design',
          'sampleSize',
          'samplingMethod',
          'dataCollection',
          'analysisMethod',
        ];
      case 'qualitative':
        return [
          'design',
          'sampleSize',
          'dataCollection',
          'analysisMethod',
        ];
      case 'systematic-review':
        return [
          'databasesSearched',
          'inclusionCriteria',
          'exclusionCriteria',
          'studiesIncludedCount',
        ];
      case 'case-study':
        return ['design', 'dataCollection', 'analysisMethod'];
      default:
        return ['design', 'dataCollection', 'analysisMethod'];
    }
  }

  String _fieldLabel(String key) {
    const labels = {
      'design': 'Study Design',
      'sampleSize': 'Sample Size',
      'samplingMethod': 'Sampling Method',
      'dataCollection': 'Data Collection',
      'analysisMethod': 'Analysis Method',
      'databasesSearched': 'Databases Searched',
      'inclusionCriteria': 'Inclusion Criteria',
      'exclusionCriteria': 'Exclusion Criteria',
      'studiesIncludedCount': 'Studies Included (count)',
    };
    return labels[key] ?? key;
  }

  String _fieldHint(String key) {
    const hints = {
      'design': 'e.g., RCT, cohort, cross-sectional',
      'sampleSize': 'e.g., n=240',
      'samplingMethod': 'e.g., random, convenience, purposive',
      'dataCollection': 'e.g., survey, interview, EEG',
      'analysisMethod': 'e.g., regression, thematic coding',
      'databasesSearched': 'e.g., PubMed, Scopus, IEEE Xplore',
      'inclusionCriteria': 'e.g., peer-reviewed, English, 2015-2024',
      'exclusionCriteria': 'e.g., non-human studies, editorials',
      'studiesIncludedCount': 'e.g., 42',
    };
    return hints[key] ?? '';
  }

  void _save() {
    _data.design = _controllers['design']!.text;
    _data.sampleSize = _controllers['sampleSize']!.text;
    _data.samplingMethod = _controllers['samplingMethod']!.text;
    _data.dataCollection = _controllers['dataCollection']!.text;
    _data.analysisMethod = _controllers['analysisMethod']!.text;
    _data.databasesSearched = _controllers['databasesSearched']!.text;
    _data.inclusionCriteria = _controllers['inclusionCriteria']!.text;
    _data.exclusionCriteria = _controllers['exclusionCriteria']!.text;
    _data.studiesIncludedCount = _controllers['studiesIncludedCount']!.text;
    _data.additionalNotes = _controllers['additionalNotes']!.text;

    widget.onSave(_data);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SECTION HEADER
        const Text(
          'EXTRACTED METHODOLOGY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),

        // STUDY TYPE
        _buildStudyTypeSection(),
        const SizedBox(height: 20),

        // CONDITIONAL FIELDS
        ..._relevantFields.map((key) => _buildField(key)),

        // ADDITIONAL NOTES (always shown)
        _buildField('additionalNotes'),

        const SizedBox(height: 12),

        // SAVE BUTTON
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Save Methodology'),
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

  Widget _buildStudyTypeSection() {
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
          const Text(
            'Study Type',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _studyTypes.map((type) {
              final isSelected = _data.studyType == type['key'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _data.studyType = type['key']!;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    type['label']!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String key) {
    final controller = _controllers[key]!;
    final isMultiline = key == 'additionalNotes' ||
        key == 'inclusionCriteria' ||
        key == 'exclusionCriteria';

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
              Text(
                _fieldLabel(key),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (controller.text.isNotEmpty)
                const Icon(
                  Icons.auto_awesome,
                  size: 12,
                  color: AppColors.purple,
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: isMultiline ? 4 : 1,
            style: const TextStyle(fontSize: 14, height: 1.4),
            decoration: InputDecoration(
              hintText: _fieldHint(key),
              hintStyle: const TextStyle(
                color: AppColors.hintText,
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}