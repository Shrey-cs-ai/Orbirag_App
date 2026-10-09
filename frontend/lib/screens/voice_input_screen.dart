import 'dart:async';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../utils/app_colors.dart';
import '../widgets/app_scaffold.dart';
import '../services/audio_recorder_service.dart';
import '../services/transcription_service.dart';

class VoiceInputScreen extends StatefulWidget {
  const VoiceInputScreen({super.key});

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorderService _recorder = AudioRecorderService();
  final TranscriptionService _transcriber = TranscriptionService.instance;

  bool _isRecording = false;
  bool _isTranscribing = false;
  String _transcript = '';
  double _confidence = 0;
  int _seconds = 0;
  Timer? _timer;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _recorder.dispose();
    super.dispose();
  }

  String get _statusText {
    if (_isRecording) return 'Recording… ${_seconds}s';
    if (_isTranscribing) return 'Transcribing...';
    if (_transcript.isNotEmpty) return 'Ready to use';
    return 'Tap the mic to start';
  }

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
      _showMsg(
          'Microphone permission denied or recording failed. Check browser settings.');
      return;
    }

    setState(() {
      _isRecording = true;
      _transcript = '';
      _confidence = 0;
      _seconds = 0;
    });
    _pulse.repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _pulse.stop();
    _pulse.reset();
    setState(() => _isRecording = false);

    final path = await _recorder.stopRecording();
    if (path == null) {
      _showMsg('Recording failed');
      return;
    }

    setState(() => _isTranscribing = true);

    try {
      final result = await _transcriber.transcribe(path);
      if (!mounted) return;
      final text = (result['transcript'] ?? '').toString();
      final confidence = (result['confidence'] is num)
          ? (result['confidence'] as num).toDouble()
          : 0.0;
      setState(() {
        _isTranscribing = false;
        _transcript = text;
        _confidence = confidence;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTranscribing = false);
      _showMsg('Transcription failed: $e');
    }
  }

  void _clear() {
    setState(() {
      _transcript = '';
      _confidence = 0;
      _seconds = 0;
    });
  }

  void _useThis() {
    final text = _transcript.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final canUse = _transcript.trim().isNotEmpty && !_isRecording && !_isTranscribing;

    return AppScaffold(
      title: 'Voice Input',
      showBackButton: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              _statusCard(),
              const SizedBox(height: 16),
              Expanded(child: _transcriptBox()),
              if (_transcript.isNotEmpty && !_isTranscribing && !_isRecording)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _transcript.trim().isEmpty
                          ? 'No speech detected'
                          : _confidence > 0
                              ? 'Speech detected'
                              : 'Speech detected',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _transcript.trim().isEmpty
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              _micButton(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: (_isRecording || _isTranscribing)
                          ? null
                          : _clear,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                      onPressed: canUse ? _useThis : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.35),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Use This'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.listeningCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            _isRecording
                ? Icons.graphic_eq
                : _isTranscribing
                    ? Icons.hourglass_top
                    : Icons.mic_none,
            color: AppColors.micPurple,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusText,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (_isTranscribing)
            LoadingAnimationWidget.staggeredDotsWave(
              color: AppColors.primary,
              size: 28,
            ),
        ],
      ),
    );
  }

  Widget _transcriptBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: _isTranscribing
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LoadingAnimationWidget.fourRotatingDots(
                    color: AppColors.primary,
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Transcribing...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: _transcript.isEmpty
                  ? const Text(
                      'Your transcript will appear here.',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : SelectableText(
                      _transcript,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
            ),
    );
  }

  Widget _micButton() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _isRecording ? _pulse.value : 0.0;
        return Container(
          width: 92 + (t * 10),
          height: 92 + (t * 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isRecording ? AppColors.error : AppColors.micPurple,
            boxShadow: [
              BoxShadow(
                color: (_isRecording ? AppColors.error : AppColors.micPurple)
                    .withValues(alpha: 0.28 + (t * 0.25)),
                blurRadius: 22 + (t * 18),
                spreadRadius: 4 + (t * 8),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _toggleRecording,
          child: Center(
            child: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}
