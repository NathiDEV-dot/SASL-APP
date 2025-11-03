import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeworkService with WidgetsBindingObserver {
  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();

  // Camera state management
  bool _isCameraInUse = false;
  bool _isAppInBackground = false;
  Completer<File?>? _recordingCompleter;

  HomeworkService() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _isAppInBackground = true;
        _cancelRecordingIfInProgress();
        break;
      case AppLifecycleState.resumed:
        _isAppInBackground = false;
        break;
      case AppLifecycleState.detached:
        _cleanupAllResources();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _cancelRecordingIfInProgress() {
    if (_isCameraInUse &&
        _recordingCompleter != null &&
        !_recordingCompleter!.isCompleted) {
      _recordingCompleter!.completeError(
          Exception('Recording interrupted - app went to background'));
      _recordingCompleter = null;
    }
    _isCameraInUse = false;
  }

  void _cleanupAllResources() {
    _isCameraInUse = false;
    _recordingCompleter = null;
  }

  // Check and request camera permissions
  Future<bool> _checkCameraPermissions() async {
    try {
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        cameraStatus = await Permission.camera.request();
      }

      var microphoneStatus = await Permission.microphone.status;
      if (!microphoneStatus.isGranted) {
        microphoneStatus = await Permission.microphone.request();
      }

      var storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        storageStatus = await Permission.storage.request();
      }

      return cameraStatus.isGranted &&
          microphoneStatus.isGranted &&
          storageStatus.isGranted;
    } catch (e) {
      debugPrint('Permission check error: $e');
      return false;
    }
  }

  // Pick video from gallery
  Future<File?> pickVideo() async {
    try {
      await _cleanupCameraResources();

      final XFile? pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );

      return pickedFile != null ? File(pickedFile.path) : null;
    } catch (e) {
      await _cleanupCameraResources();
      throw Exception('Failed to pick video: ${e.toString()}');
    }
  }

  // Record video using camera
  Future<File?> recordVideo() async {
    if (_isCameraInUse) {
      throw Exception('Camera is currently in use. Please wait...');
    }

    if (_isAppInBackground) {
      throw Exception('Cannot start recording while app is in background');
    }

    final hasPermissions = await _checkCameraPermissions();
    if (!hasPermissions) {
      throw Exception(
          'Camera, microphone, and storage permissions are required to record videos. Please enable them in app settings.');
    }

    _isCameraInUse = true;
    _recordingCompleter = Completer<File?>();

    try {
      await _preCameraSetup();

      final XFile? recordedFile = await _imagePicker
          .pickVideo(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxDuration: const Duration(minutes: 10),
      )
          .timeout(const Duration(seconds: 60), onTimeout: () {
        throw Exception(
            'Camera recording timed out. Please try recording a shorter video.');
      });

      if (recordedFile != null) {
        final file = File(recordedFile.path);
        if (await file.exists()) {
          _recordingCompleter!.complete(file);
          return file;
        } else {
          throw Exception('Recorded video file was not saved properly.');
        }
      } else {
        _recordingCompleter!.complete(null);
        return null;
      }
    } catch (e) {
      debugPrint('Camera recording error: $e');
      _recordingCompleter!.completeError(e);

      if (e.toString().contains('Permission') ||
          e.toString().contains('permission')) {
        throw Exception(
            'Camera permission denied. Please enable camera permissions in app settings.');
      } else if (e.toString().contains('timeout')) {
        throw Exception(
            'Recording took too long. Please try shorter recordings (1-2 minutes).');
      } else if (e.toString().contains('camera') ||
          e.toString().contains('Camera')) {
        throw Exception(
            'Camera is busy. Please close other camera apps and try again.');
      } else {
        throw Exception('Camera error: ${e.toString()}');
      }
    } finally {
      await _postCameraCleanup();
    }
  }

  Future<void> _preCameraSetup() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await Future(() {});
  }

  Future<void> _postCameraCleanup() async {
    _isCameraInUse = false;
    _recordingCompleter = null;
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _cleanupCameraResources() async {
    _isCameraInUse = false;
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // Check camera availability
  Future<bool> checkCameraAvailability() async {
    try {
      return true;
    } catch (e) {
      debugPrint('Camera availability check failed: $e');
      return false;
    }
  }

  // Validate video file
  void validateVideoFile(File videoFile) {
    final fileSize = videoFile.lengthSync();
    const maxSize = 200 * 1024 * 1024; // 200MB for homework submissions
    if (fileSize > maxSize) {
      throw Exception('Video file too large. Maximum size is 200MB');
    }

    final extension = path.extension(videoFile.path).toLowerCase();
    final allowedExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];
    if (!allowedExtensions.contains(extension)) {
      throw Exception('Unsupported video format');
    }
  }

  // Get video duration safely
  Future<Duration> getVideoDuration(File videoFile) async {
    try {
      try {
        final fileSize = await videoFile.length();
        if (fileSize > 0) {
          final estimatedSeconds = (fileSize / (500 * 1024)).ceil();
          return Duration(seconds: estimatedSeconds.clamp(5, 600));
        }
      } catch (e) {
        debugPrint('File size estimation failed: $e');
      }
      return const Duration(seconds: 60);
    } catch (e) {
      debugPrint('All duration methods failed, using default: $e');
      return const Duration(seconds: 60);
    }
  }

  // Transcode video to compatible format
  Future<File> transcodeVideoToCompatibleFormat(File originalVideo) async {
    try {
      print('Starting video transcoding for homework submission...');
      await VideoCompress.setLogLevel(0);

      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        originalVideo.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (mediaInfo == null || mediaInfo.file == null) {
        throw Exception('Video transcoding failed');
      }

      print('Homework video transcoding completed: ${mediaInfo.file!.path}');
      return File(mediaInfo.file!.path);
    } catch (e) {
      print('Homework video transcoding error: $e');
      return originalVideo;
    }
  }

  // Upload homework video
  Future<String> uploadHomeworkVideo({
    required String homeworkId,
    required String studentId,
    required File videoFile,
    required Function(double) onProgress,
  }) async {
    try {
      // Transcode video first (30% of progress)
      onProgress(0.1);
      final compatibleVideo = await transcodeVideoToCompatibleFormat(videoFile);
      onProgress(0.3);

      // Upload transcoded video (70% of progress)
      final fileName =
          'submission_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = 'homework_submissions/$homeworkId/$studentId/$fileName';

      await _client.storage.from('videos').uploadBinary(
            filePath,
            await compatibleVideo.readAsBytes(),
            fileOptions: const FileOptions(upsert: true),
          );

      onProgress(1.0);

      // Clean up temporary file
      try {
        if (compatibleVideo.path != videoFile.path) {
          await compatibleVideo.delete();
        }
      } catch (e) {
        print('Could not delete temporary video file: $e');
      }

      return _client.storage.from('videos').getPublicUrl(filePath);
    } catch (e) {
      print('Homework video upload failed: $e');
      throw Exception('Failed to upload homework video: ${e.toString()}');
    }
  }

  // Get homework details
  Future<Map<String, dynamic>?> getHomeworkDetails(String homeworkId) async {
    try {
      final response = await _client
          .from('homeworks')
          .select('*')
          .eq('id', homeworkId)
          .single();

      return response as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting homework details: $e');
      return null;
    }
  }

  // Check if homework is already submitted
  Future<bool> isHomeworkSubmitted(String homeworkId, String studentId) async {
    try {
      final response = await _client
          .from('homework_submissions')
          .select('id')
          .eq('homework_id', homeworkId)
          .eq('student_id', studentId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // Get existing submission
  Future<Map<String, dynamic>?> getExistingSubmission(
      String homeworkId, String studentId) async {
    try {
      final response = await _client
          .from('homework_submissions')
          .select('*')
          .eq('homework_id', homeworkId)
          .eq('student_id', studentId)
          .maybeSingle();

      return response as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  // Submit homework
  Future<String> submitHomework({
    required String homeworkId,
    required String studentId,
    required String studentCode,
    required String studentName,
    required String studentGrade,
    required String videoUrl,
    required int durationSeconds,
    String? comments,
  }) async {
    try {
      final response = await _client.from('homework_submissions').insert({
        'homework_id': homeworkId,
        'student_id': studentId,
        'student_code': studentCode,
        'student_name': studentName,
        'student_grade': studentGrade,
        'video_url': videoUrl,
        'duration_seconds': durationSeconds,
        'comments': comments,
        'submitted_at': DateTime.now().toIso8601String(),
        'status': 'submitted',
        'grade': null,
        'feedback': null,
      }).select('id');

      if (response.isEmpty) throw Exception('No ID returned');

      final submissionId = response.first['id'] as String;
      print('Homework submitted with ID: $submissionId');

      return submissionId;
    } catch (e) {
      print('Failed to submit homework: $e');
      throw Exception('Failed to submit homework: ${e.toString()}');
    }
  }

  // Update existing submission
  Future<void> updateSubmission({
    required String submissionId,
    required String videoUrl,
    required int durationSeconds,
    String? comments,
  }) async {
    try {
      await _client.from('homework_submissions').update({
        'video_url': videoUrl,
        'duration_seconds': durationSeconds,
        'comments': comments,
        'submitted_at': DateTime.now().toIso8601String(),
        'status': 'resubmitted',
        'grade': null,
        'feedback': null,
      }).eq('id', submissionId);

      print('Homework submission updated: $submissionId');
    } catch (e) {
      print('Failed to update submission: $e');
      throw Exception('Failed to update submission: ${e.toString()}');
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupAllResources();
  }
}
