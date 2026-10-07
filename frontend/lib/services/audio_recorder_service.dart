import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

  Future<bool> requestPermission() async {
    try {
      if (kIsWeb) {
        return await _recorder.hasPermission();
      }
      final status = await Permission.microphone.request();
      if (status.isGranted) return true;
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('[AudioRecorder] permission request error: $e');
      return await _recorder.hasPermission();
    }
  }

  Future<bool> hasPermission() async {
    try {
      if (kIsWeb) {
        return await _recorder.hasPermission();
      }
      final isGranted = await Permission.microphone.isGranted;
      if (isGranted) return true;
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('[AudioRecorder] permission check error: $e');
      return await _recorder.hasPermission();
    }
  }

  Future<String?> startRecording() async {
    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        final granted = await requestPermission();
        if (!granted) {
          debugPrint('[AudioRecorder] microphone permission denied');
          return null;
        }
      }

      String path = '';
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        _currentPath =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        path = _currentPath!;
      } else {
        _currentPath = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        path = '';
      }

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      return _currentPath ?? 'recording';
    } catch (e) {
      debugPrint('[AudioRecorder] start error: $e');
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      return path ?? _currentPath;
    } catch (e) {
      debugPrint('[AudioRecorder] stop error: $e');
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      await _recorder.stop();
      if (!kIsWeb && _currentPath != null) {
        final file = File(_currentPath!);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
    _currentPath = null;
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}