class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  // Simulated AI responses for paper analysis
  final Map<String, String> _paperResponses = {
    'objective': 
        'Based on the paper, the main objective of this study is to evaluate the efficacy of machine learning models in early-stage diagnostic workflows.\n\nSpecifically, it aims to:\n• Compare deep learning algorithms against traditional diagnostic benchmarks\n• Identify bottlenecks in clinical implementation of AI tools\n• Propose a framework for integrating AI securely with existing electronic health records (EHR)',
    
    'methodology': 
        'The study employed a mixed-methods approach:\n\n📊 Quantitative Analysis:\n• Evaluated 5 different ML models\n• Used 10,000+ patient records\n• Compared accuracy, sensitivity, and specificity\n\n📝 Qualitative Analysis:\n• Interviewed 15 healthcare professionals\n• Assessed usability and adoption barriers\n• Evaluated integration challenges',
    
    'results': 
        'Key findings from the study:\n\n✅ Deep learning models showed 94.7% accuracy\n✅ Reduced diagnostic time by 40%\n✅ Identified 3 critical bottlenecks in implementation\n✅ Proposed framework was validated by 85% of participants\n\nLimitations:\n• Small sample size for qualitative study\n• Limited to radiology datasets',
    
    'conclusion': 
        'The study concludes that:\n\n🎯 AI integration in diagnostics is feasible and effective\n🏥 Hybrid human-AI workflows show promise\n🔐 Security and privacy concerns can be addressed with proper frameworks\n📈 Further research needed in multi-center studies\n\nRecommendations:\n• Start with pilot programs\n• Focus on explainable AI\n• Invest in clinician training',
  };

  Future<String> getResponse(String query, {String? paperContext}) async {
    // Simulate API call delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    final lowerQuery = query.toLowerCase();
    
    // Check for keywords
    for (final entry in _paperResponses.entries) {
      if (lowerQuery.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Default response
    return "I've analyzed the paper and here's what I found:\n\n📄 This paper discusses advancements in AI for medical diagnostics. It covers:\n• Machine learning applications in healthcare\n• Evaluation of different algorithms\n• Implementation challenges and solutions\n• Future directions for AI in medicine\n\nWhat specific aspect would you like to know more about?";
  }
}