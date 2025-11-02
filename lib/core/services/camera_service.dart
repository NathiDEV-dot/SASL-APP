import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// Simple camera service that works without external dependencies
class CameraService {
  static bool _isRecording = false;
  static String? _videoPath;
  static bool _isInitialized = false;
  static Timer? _recordingTimer;
  static Duration _recordingDuration = Duration.zero;

  static bool get isRecording => _isRecording;
  static String? get videoPath => _videoPath;
  static bool get isInitialized => _isInitialized;
  static Duration get recordingDuration => _recordingDuration;

  // Initialize camera simulation
  static Future<bool> initializeCamera() async {
    try {
      // Simulate camera initialization delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      _isInitialized = true;
      _recordingDuration = Duration.zero;
      
      if (kDebugMode) {
        print('Camera service initialized successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Camera initialization error: $e');
      }
      return false;
    }
  }

  // Start recording simulation
  static Future<bool> startRecording() async {
    try {
      if (!_isInitialized || _isRecording) {
        return false;
      }

      final Directory appDir = await getApplicationDocumentsDirectory();
      final String videoDirectory = '${appDir.path}/Videos';
      await Directory(videoDirectory).create(recursive: true);
      
      final String currentTime = DateTime.now().millisecondsSinceEpoch.toString();
      _videoPath = '$videoDirectory/recording_$currentTime.mp4';

      _isRecording = true;
      _recordingDuration = Duration.zero;
      
      // Start recording timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordingDuration += const Duration(seconds: 1);
      });

      if (kDebugMode) {
        print('Recording started: $_videoPath');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Recording start error: $e');
      }
      return false;
    }
  }

  // Stop recording simulation
  static Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        return null;
      }

      _isRecording = false;
      _recordingTimer?.cancel();
      _recordingTimer = null;

      // Simulate file creation delay
      await Future.delayed(const Duration(milliseconds: 300));

      if (kDebugMode) {
        print('Recording stopped: $_videoPath');
        print('Recording duration: ${_formatDuration(_recordingDuration)}');
      }

      final String? recordedPath = _videoPath;
      
      // Reset state
      _videoPath = null;
      _recordingDuration = Duration.zero;

      return recordedPath;
    } catch (e) {
      if (kDebugMode) {
        print('Recording stop error: $e');
      }
      return null;
    }
  }

  // Toggle flash simulation (mock implementation)
  static Future<bool> toggleFlash() async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      if (kDebugMode) {
        print('Flash toggled');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Flash toggle error: $e');
      }
      return false;
    }
  }

  // Switch camera simulation (mock implementation)
  static Future<bool> switchCamera() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      if (kDebugMode) {
        print('Camera switched');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Camera switch error: $e');
      }
      return false;
    }
  }

  // Dispose camera resources
  static Future<void> dispose() async {
    try {
      if (_isRecording) {
        await stopRecording();
      }
      
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _isInitialized = false;
      _videoPath = null;
      _recordingDuration = Duration.zero;

      if (kDebugMode) {
        print('Camera service disposed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Camera dispose error: $e');
      }
    }
  }

  // Check if camera is available
  static Future<bool> checkCameraAvailability() async {
    try {
      // Simulate camera availability check
      await Future.delayed(const Duration(milliseconds: 100));
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Camera availability check error: $e');
      }
      return false;
    }
  }

  // Get recording status
  static Map<String, dynamic> getRecordingStatus() {
    return {
      'isRecording': _isRecording,
      'videoPath': _videoPath,
      'duration': _recordingDuration,
      'formattedDuration': _formatDuration(_recordingDuration),
      'isInitialized': _isInitialized,
    };
  }

  // Format duration for display
  static String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  // Get maximum recording duration
  static Duration get maxRecordingDuration => const Duration(minutes: 30);

  // Check if recording time is within limits
  static bool get isWithinRecordingLimit => _recordingDuration < maxRecordingDuration;

  // Get remaining recording time
  static Duration get remainingRecordingTime => maxRecordingDuration - _recordingDuration;

  // Create a mock video file for testing
  static Future<File?> createMockVideoFile({String? customPath}) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String videoDirectory = '${appDir.path}/Videos';
      await Directory(videoDirectory).create(recursive: true);
      
      final String fileName = 'mock_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final String filePath = customPath ?? '$videoDirectory/$fileName';
      
      final File mockFile = File(filePath);
      await mockFile.writeAsBytes(List.filled(1024, 0)); // Create a small mock file
      
      if (kDebugMode) {
        print('Mock video file created: $filePath');
      }
      
      return mockFile;
    } catch (e) {
      if (kDebugMode) {
        print('Mock video creation error: $e');
      }
      return null;
    }
  }

  // Clean up old recordings
  static Future<void> cleanupOldRecordings({int keepLast = 5}) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String videoDirectory = '${appDir.path}/Videos';
      final Directory dir = Directory(videoDirectory);
      
      if (!await dir.exists()) return;
      
      final List<FileSystemEntity> files = await dir.list().toList();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      
      for (int i = keepLast; i < files.length; i++) {
        await files[i].delete();
      }
      
      if (kDebugMode) {
        print('Cleaned up ${files.length - keepLast} old recordings');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Cleanup error: $e');
      }
    }
  }
}