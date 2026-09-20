import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> hasPermission() async {
    return await Permission.microphone.isGranted;
  }

  Future<String?> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        _currentPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _currentPath!,
        );
        return _currentPath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      return path ?? _currentPath;
    } catch (e) {
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      await _recorder.stop();
      if (_currentPath != null) {
        final file = File(_currentPath!);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}