import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderService {
  static final AudioRecorderService _instance = AudioRecorderService._internal();
  factory AudioRecorderService() => _instance;
  AudioRecorderService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  String? _filePath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check if permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Start recording
  Future<String?> startRecording() async {
    if (await _recorder.hasPermission()) {
      try {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 44100,
            bitRate: 128000,
          ),
          path: path,
        );
        
        _filePath = path;
        _isRecording = true;
        return path;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    if (_isRecording && _filePath != null) {
      try {
        final path = await _recorder.stop();
        _isRecording = false;
        final file = File(path ?? _filePath!);
        if (await file.exists()) {
          return file.path;
        }
        return null;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Cancel recording
  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.stop();
      _isRecording = false;
      if (_filePath != null) {
        final file = File(_filePath!);
        if (await file.exists()) {
          await file.delete();
        }
        _filePath = null;
      }
    }
  }

  /// Get recording duration in seconds
  Future<Duration> getRecordingDuration() async {
    if (_filePath != null) {
      final file = File(_filePath!);
      if (await file.exists()) {
        // Note: This is a placeholder - for accurate duration,
        // you'd need to use a package like flutter_ffmpeg
        return const Duration(seconds: 0);
      }
    }
    return const Duration(seconds: 0);
  }

  /// Dispose recorder
  void dispose() {
    _recorder.dispose();
  }
}