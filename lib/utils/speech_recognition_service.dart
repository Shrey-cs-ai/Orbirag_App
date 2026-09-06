import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechRecognitionService {
  SpeechRecognitionService._internal();
  static final SpeechRecognitionService instance = SpeechRecognitionService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool get isListening => _speech.isListening;

  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onStatus: (status) => onStatus?.call(status),
      onError: (error) => onError?.call(error.errorMsg),
    );
    return _isInitialized;
  }

  Future<void> startListening({
    required void Function(String transcript, bool isFinal) onResult,
    String localeId = 'en_US',
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }
    await _speech.listen(
      onResult: (result) => onResult(result.recognizedWords, result.finalResult),
      localeId: localeId,
      listenFor: listenFor,
      pauseFor: pauseFor,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  Future<void> stopListening() => _speech.stop();
  Future<void> cancel() => _speech.cancel();
}