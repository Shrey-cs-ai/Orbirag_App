import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../utils/whisper_transcription_service.dart';
import '../services/audio_recorder_service.dart';
import '../widgets/app_scaffold.dart';

class VoiceInputScreen extends StatefulWidget {
  const VoiceInputScreen({super.key});

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorderService _recorder = AudioRecorderService();
  final TextEditingController _transcriptController = TextEditingController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isRecording = false;
  bool _isProcessing = false;
  bool _hasTranscript = false;
  String _statusMessage = 'Tap the mic to start recording';

  // ⚠️ Put your real OpenAI key here (or use env later)
  final String _apiKey = 'YOUR_OPENAI_API_KEY_HERE';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _requestPermissions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transcriptController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    final granted = await _recorder.requestPermission();
    if (!granted) {
      setState(() => _statusMessage = 'Microphone permission denied');
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final path = await _recorder.startRecording();
    if (path != null) {
      setState(() {
        _isRecording = true;
        _hasTranscript = false;
        _statusMessage = 'Recording...';
        _transcriptController.clear();
      });
    } else {
      setState(() => _statusMessage = 'Failed to start recording');
    }
  }

  Future<void> _stopRecording() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Transcribing with Whisper...';
    });

    final path = await _recorder.stopRecording();
    if (path != null) {
      await _transcribe(path);
    } else {
      setState(() {
        _isRecording = false;
        _isProcessing = false;
        _statusMessage = 'Failed to stop recording';
      });
    }
  }

  Future<void> _transcribe(String path) async {
    try {
      final file = File(path);
      final service = WhisperTranscriptionService(apiKey: _apiKey);
      final text = await service.transcribeFile(file);

      setState(() {
        _isRecording = false;
        _isProcessing = false;
        _hasTranscript = text.trim().isNotEmpty;
        _transcriptController.text = text.trim();
        _statusMessage = text.trim().isNotEmpty
            ? 'Transcription complete'
            : 'No speech detected';
      });
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isProcessing = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  void _clear() {
    _recorder.cancelRecording();
    setState(() {
      _transcriptController.clear();
      _hasTranscript = false;
      _statusMessage = 'Cleared';
    });
  }

  void _useThis() {
    Navigator.pop(context, _transcriptController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Voice Input",
      showBackButton: true,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    _isRecording ? Icons.mic : Icons.mic_none,
                    color: _isRecording ? AppColors.error : AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: _isRecording ? AppColors.error : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_isProcessing)
                    LoadingAnimationWidget.threeRotatingDots(
                      color: AppColors.primary,
                      size: 28,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Transcript Box
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Transcript",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        controller: _transcriptController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Your transcribed text will appear here...",
                          hintStyle: TextStyle(color: AppColors.hintText),
                        ),
                      ),
                    ),
                    if (_hasTranscript)
                      Row(
                        children: [
                          const Text(
                            "Speech detected",
                            style: TextStyle(fontSize: 12, color: AppColors.success),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: _transcriptController.text),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Copied")),
                              );
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Mic Button
            GestureDetector(
              onTap: _isProcessing ? null : _toggleRecording,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, __) {
                  return Transform.scale(
                    scale: _isRecording ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: _isRecording ? AppColors.error : AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: _isRecording
                            ? [
                                BoxShadow(
                                  color: AppColors.error.withOpacity(0.35),
                                  blurRadius: 18,
                                  spreadRadius: 4,
                                )
                              ]
                            : null,
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Clear & Use This
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _hasTranscript ? _clear : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Clear"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _hasTranscript ? _useThis : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Use This"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}