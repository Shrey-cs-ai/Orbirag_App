import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:record/record.dart';
import '../utils/app_colors.dart';
import '../services/ai_service.dart';
import '../widgets/app_scaffold.dart';

class VoiceInputScreen extends StatefulWidget {
  const VoiceInputScreen({super.key});

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  final TextEditingController _transcriptController = TextEditingController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isRecording = false;
  bool _isProcessing = false;
  bool _hasTranscript = false;
  String _statusMessage = 'Tap the mic to start recording';

  // ✅ Collects bytes from the stream (works on Web AND Mobile)
  final List<int> _audioBytes = [];
  StreamSubscription<Uint8List>? _audioStreamSubscription;

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
    _audioStreamSubscription?.cancel();
    _pulseController.dispose();
    _transcriptController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    final granted = await _recorder.hasPermission();
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
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _statusMessage = 'Microphone permission denied');
        return;
      }

      _audioBytes.clear();

      // ✅ Use the stream API — gives us bytes directly, works on Web + Mobile
      final stream = await _recorder.startStream(
        const RecordConfig(encoder: AudioEncoder.aacLc),
      );

      _audioStreamSubscription = stream.listen(
        (data) => _audioBytes.addAll(data),
        onError: (e) => debugPrint("Stream error: $e"),
      );

      setState(() {
        _isRecording = true;
        _hasTranscript = false;
        _statusMessage = 'Recording...';
        _transcriptController.clear();
      });
    } catch (e) {
      setState(() => _statusMessage = 'Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Transcribing...';
    });

    try {
      await _recorder.stop();
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      if (_audioBytes.isEmpty) {
        setState(() {
          _isRecording = false;
          _isProcessing = false;
          _statusMessage = 'No audio captured. Try speaking a bit longer.';
        });
        return;
      }

      // ✅ Send the collected bytes to the backend
      final transcript = await AiService.instance.transcribeAudio(
        audioBytes: _audioBytes,
        filename: 'voice_input.m4a',
      );

      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isProcessing = false;
        _hasTranscript = transcript.trim().isNotEmpty;
        _transcriptController.text = transcript.trim();
        _statusMessage = transcript.trim().isNotEmpty
            ? 'Transcription complete'
            : 'No speech detected';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isProcessing = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  void _clear() {
    _audioBytes.clear();
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
                        color: _isRecording
                            ? AppColors.error
                            : AppColors.textPrimary,
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
                            style: TextStyle(
                                fontSize: 12, color: AppColors.success),
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
                        color: _isRecording
                            ? AppColors.error
                            : AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: _isRecording
                            ? [
                                BoxShadow(
                                  color:
                                      AppColors.error.withValues(alpha: 0.35),
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