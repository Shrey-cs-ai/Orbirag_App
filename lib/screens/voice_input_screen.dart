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
  String _filePath = '';

  // TODO: Move this to a secure location (env variables)
  final String _apiKey = 'YOUR_OPENAI_API_KEY_HERE';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
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
    final hasPermission = await _recorder.requestPermission();
    if (!hasPermission) {
      setState(() {
        _statusMessage = 'Microphone permission denied';
      });
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
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      final granted = await _recorder.requestPermission();
      if (!granted) {
        setState(() {
          _statusMessage = 'Microphone permission required';
        });
        return;
      }
    }

    final path = await _recorder.startRecording();
    if (path != null) {
      setState(() {
        _isRecording = true;
        _hasTranscript = false;
        _filePath = path;
        _statusMessage = 'Recording...';
        _transcriptController.clear();
      });
    } else {
      setState(() {
        _statusMessage = 'Failed to start recording';
      });
    }
  }

  Future<void> _stopRecording() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Processing audio...';
    });

    final path = await _recorder.stopRecording();
    if (path != null) {
      _filePath = path;
      await _transcribeAudio(path);
    } else {
      setState(() {
        _isRecording = false;
        _isProcessing = false;
        _statusMessage = 'Failed to stop recording';
      });
    }
  }

  Future<void> _transcribeAudio(String audioPath) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        throw Exception('Audio file not found');
      }

      final service = WhisperTranscriptionService(apiKey: _apiKey);
      final transcript = await service.transcribeFile(file);

      setState(() {
        _isRecording = false;
        _isProcessing = false;
        _hasTranscript = transcript.isNotEmpty;
        _transcriptController.text = transcript;
        _statusMessage = transcript.isNotEmpty
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

  Future<void> _clearTranscript() async {
    await _recorder.cancelRecording();
    setState(() {
      _transcriptController.clear();
      _hasTranscript = false;
      _statusMessage = 'Cleared';
    });
  }

  void _useTranscript() {
    Navigator.of(context).pop(_transcriptController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppConstants.appName,
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: () {
            _showHelpDialog();
          },
        ),
      ],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              // Status and Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
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
                              color: _isRecording ? AppColors.error : AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_isProcessing)
                          LoadingAnimationWidget.threeRotatingDots(
                            color: AppColors.primary,
                            size: 30,
                          ),
                      ],
                    ),
                    if (_isRecording) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.fiber_manual_record, color: AppColors.error, size: 12),
                            SizedBox(width: 6),
                            Text(
                              'Recording in progress...',
                              style: TextStyle(fontSize: 12, color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Transcript Area
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
                        'Transcript',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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
                            hintText: 'Your transcribed text will appear here...',
                            hintStyle: TextStyle(color: AppColors.hintText),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (_hasTranscript) ...[
                        const Divider(),
                        Row(
                          children: [
                            const Text(
                              'Speech detected',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: _transcriptController.text),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Copied to clipboard')),
                                );
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: _clearTranscript,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Recording Button
              GestureDetector(
                onTap: _isProcessing ? null : _toggleRecording,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isRecording ? _pulseAnimation.value : 1.0,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: _isRecording
                              ? AppColors.error
                              : AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            if (_isRecording)
                              BoxShadow(
                                color: AppColors.error.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _hasTranscript ? _clearTranscript : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: _hasTranscript ? AppColors.border : AppColors.border.withOpacity(0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _hasTranscript ? _useTranscript : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: AppColors.border,
                      ),
                      child: const Text('Use This'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              const Text(
                'Tap the mic to start recording. Speak clearly for best results.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to use Voice Input'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Tap the microphone button to start recording.'),
            const SizedBox(height: 8),
            const Text('2. Speak clearly into your device.'),
            const SizedBox(height: 8),
            const Text('3. Tap the stop button when finished.'),
            const SizedBox(height: 8),
            const Text('4. Review the transcribed text.'),
            const SizedBox(height: 8),
            const Text('5. Tap "Use This" to insert into your document.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '💡 Tip: Find a quiet place for better accuracy.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}