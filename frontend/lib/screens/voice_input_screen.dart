import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/app_brand_title.dart';
import '../services/audio_recorder_service.dart';
import '../services/voice_transcription_service.dart';

class VoiceInputScreen extends StatefulWidget {
  const VoiceInputScreen({super.key});

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen> {
  final AudioRecorderService _recorder = AudioRecorderService();
  final VoiceTranscriptionService _transcriber = VoiceTranscriptionService.instance;

  int _selectedIndex = 2;
  bool _isRecording = false;
  bool _isTranscribing = false;
  String _transcript = '';
  int _seconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ============================================================
  // Record / Stop
  // ============================================================
  Future<void> _toggleRecording() async {
    if (_isTranscribing) return;
    if (_isRecording) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    final granted = await _recorder.requestPermission();
    if (!granted) {
      _showMsg('Microphone permission denied. Check browser settings.');
      return;
    }

    final path = await _recorder.startRecording();
    if (path == null) {
      _showMsg('Microphone permission denied or recording failed. Check browser settings.');
      return;
    }

    setState(() {
      _isRecording = true;
      _transcript = '';
      _seconds = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    setState(() => _isRecording = false);

    final path = await _recorder.stopRecording();
    if (path == null) {
      _showMsg('Recording failed');
      return;
    }

    setState(() => _isTranscribing = true);

    final text = await _transcriber.transcribe(path);

    if (!mounted) return;
    setState(() {
      _isTranscribing = false;
      _transcript = text ?? 'Could not transcribe. Please try again.';
    });
  }

  void _copyTranscript() {
    if (_transcript.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _transcript));
    _showMsg('Copied to clipboard');
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ============================================================
  // Build
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            const Text(
              'Voice to Text',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Speak clearly into your microphone',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 40),

            // Status
            Text(
              _isRecording
                  ? 'Recording… ${_seconds}s'
                  : _isTranscribing
                      ? 'Transcribing…'
                      : 'Tap the mic to start',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 30),

            // Mic button
            GestureDetector(
              onTap: _toggleRecording,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? AppColors.error : AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording
                              ? AppColors.error
                              : AppColors.primary)
                          .withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),

            const SizedBox(height: 30),

            if (_isTranscribing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),

            // Transcript card
            if (_transcript.isNotEmpty)
              Container(
                width: double.infinity,
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
                        const Icon(Icons.text_fields,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        const Text(
                          'Transcript',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Copy',
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: _copyTranscript,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _transcript,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
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
}