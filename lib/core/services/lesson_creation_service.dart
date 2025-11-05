import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart' as camera_package;
import 'package:video_player/video_player.dart';

class LessonCreationService with WidgetsBindingObserver {
  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  // Camera instance management - EXACTLY LIKE VideoUploadService
  camera_package.CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  bool _isAppInBackground = false;
  bool _isFrontCamera = false;
  List<camera_package.CameraDescription> _cameras = [];
  double _currentZoomLevel = 1.0;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  LessonCreationService() {
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
    if (_isRecording) {
      _stopRecordingInternal();
    }
  }

  void _cleanupAllResources() {
    _disposeCamera();
    _stopRecordingTimer();
  }

  // ========== CAMERA MANAGEMENT - EXACTLY LIKE VideoUploadService ==========

  Future<camera_package.CameraController?> initializeCamera() async {
    try {
      await _disposeCamera();

      // EXACTLY LIKE VideoUploadService - direct permission requests
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        throw Exception('Camera permission denied');
      }

      final statusMicrophone = await Permission.microphone.request();
      if (!statusMicrophone.isGranted) {
        throw Exception('Microphone permission denied');
      }

      _cameras = await camera_package.availableCameras();
      if (_cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      // Start with back camera - EXACTLY LIKE VideoUploadService
      final initialCamera = _cameras.firstWhere(
        (camera) =>
            camera.lensDirection == camera_package.CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = camera_package.CameraController(
        initialCamera,
        camera_package.ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: camera_package.ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      _isCameraInitialized = true;
      _isFrontCamera = initialCamera.lensDirection ==
          camera_package.CameraLensDirection.front;
      _currentZoomLevel = 1.0;

      return _cameraController;
    } catch (e) {
      await _disposeCamera();
      throw Exception('Failed to initialize camera: $e');
    }
  }

  Future<void> switchCamera() async {
    if (!_isCameraInitialized || _cameras.length < 2) return;

    await _disposeCamera();

    _isFrontCamera = !_isFrontCamera;
    final newCamera = _isFrontCamera
        ? _cameras.firstWhere(
            (camera) =>
                camera.lensDirection ==
                camera_package.CameraLensDirection.front,
            orElse: () => _cameras.first,
          )
        : _cameras.firstWhere(
            (camera) =>
                camera.lensDirection == camera_package.CameraLensDirection.back,
            orElse: () => _cameras.first,
          );

    _cameraController = camera_package.CameraController(
      newCamera,
      camera_package.ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: camera_package.ImageFormatGroup.yuv420,
    );

    await _cameraController!.initialize();
    _isCameraInitialized = true;
    _currentZoomLevel = 1.0;
  }

  Future<void> setZoomLevel(double zoomLevel) async {
    if (!_isCameraInitialized) return;

    // Use reasonable zoom range since camera package doesn't provide min/max
    final minZoom = 1.0;
    final maxZoom = 5.0;

    // Clamp zoom level between min and max
    _currentZoomLevel = zoomLevel.clamp(minZoom, maxZoom);

    try {
      await _cameraController!.setZoomLevel(_currentZoomLevel);
    } catch (e) {
      debugPrint('Zoom not supported: $e');
    }
  }

  Future<void> startRecording() async {
    try {
      if (!_isCameraInitialized || !_cameraController!.value.isInitialized) {
        throw Exception('Camera not initialized');
      }

      if (_cameraController!.value.isRecordingVideo) {
        throw Exception('Already recording');
      }

      if (_isAppInBackground) {
        throw Exception('Cannot start recording while app is in background');
      }

      await _cameraController!.startVideoRecording();
      _isRecording = true;
      _startRecordingTimer();
    } catch (e) {
      throw Exception('Failed to start recording: $e');
    }
  }

  Future<File?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final camera_package.XFile videoFile =
          await _cameraController!.stopVideoRecording();
      final file = File(videoFile.path);

      _isRecording = false;
      _stopRecordingTimer();

      await Future.delayed(Duration(milliseconds: 1000));

      final isValid = await _isValidVideoFile(file);
      if (isValid) {
        return file;
      } else {
        throw Exception('Recorded video file is not valid');
      }
    } catch (e) {
      _isRecording = false;
      _stopRecordingTimer();
      throw Exception('Failed to stop recording: ${e.toString()}');
    }
  }

  void _startRecordingTimer() {
    _recordingDuration = Duration.zero;
    _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _recordingDuration += Duration(seconds: 1);
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingDuration = Duration.zero;
  }

  void _stopRecordingInternal() {
    if (_isRecording) {
      _cameraController?.stopVideoRecording();
      _isRecording = false;
      _stopRecordingTimer();
    }
  }

  Future<void> _disposeCamera() async {
    _stopRecordingInternal();

    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
      _isCameraInitialized = false;
    }
  }

  Future<void> disposeCamera() async {
    await _disposeCamera();
  }

  // ========== VIDEO MANAGEMENT ==========

  Future<File?> pickVideoFromGallery() async {
    try {
      // EXACTLY LIKE VideoUploadService - with permission handling
      Permission permission;

      if (await Permission.photos.isRestricted) {
        permission = Permission.storage;
      } else {
        permission = Permission.photos;
      }

      final status = await permission.status;

      if (!status.isGranted) {
        final permissionResult = await permission.request();

        if (!permissionResult.isGranted) {
          if (permissionResult.isPermanentlyDenied) {
            throw Exception(
              'Gallery access is permanently denied. '
              'Please enable it in your device settings:\n'
              'Settings > Apps > Lesson App > Permissions > Photos/Storage',
            );
          }
          throw Exception('Gallery access permission denied');
        }
      }

      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 30),
      );

      if (video != null) {
        final file = File(video.path);
        debugPrint('Picked video from gallery: ${video.path}');

        if (await _isValidVideoFile(file)) {
          return file;
        } else {
          throw Exception('Selected file is not a valid video file');
        }
      }
      return null;
    } catch (e) {
      debugPrint('Gallery pick error: $e');
      throw Exception('Failed to pick video from gallery: $e');
    }
  }

  // For backward compatibility
  Future<File?> pickVideo() async {
    return await pickVideoFromGallery();
  }

  Future<bool> _isValidVideoFile(File file) async {
    try {
      if (!await file.exists()) return false;
      final fileSize = await file.length();
      if (fileSize == 0) return false;

      final path = file.path.toLowerCase();
      final validExtensions = [
        '.mp4',
        '.mov',
        '.avi',
        '.mkv',
        '.wmv',
        '.flv',
        '.webm',
        '.3gp',
      ];
      return validExtensions.any((ext) => path.endsWith(ext));
    } catch (e) {
      return false;
    }
  }

  void validateVideoFile(File videoFile) {
    final fileSize = videoFile.lengthSync();
    const maxSize = 500 * 1024 * 1024;
    if (fileSize > maxSize) {
      throw Exception('Video file too large. Maximum size is 500MB');
    }

    final extension = path.extension(videoFile.path).toLowerCase();
    final allowedExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];
    if (!allowedExtensions.contains(extension)) {
      throw Exception('Unsupported video format');
    }

    if (fileSize > 100 * 1024 * 1024) {
      throw Exception(
          'Video file is very large. Please compress it below 100MB for better compatibility');
    }
  }

  Future<int> _getVideoDuration(File videoFile) async {
    try {
      final videoPlayerController = VideoPlayerController.file(videoFile);
      await videoPlayerController.initialize();
      final duration = videoPlayerController.value.duration;
      await videoPlayerController.dispose();
      return duration.inSeconds;
    } catch (e) {
      debugPrint('Failed to get video duration: $e');
      return 0;
    }
  }

  Future<Duration> getVideoDuration(File videoFile) async {
    try {
      final fileSize = await videoFile.length();
      if (fileSize > 0) {
        final estimatedSeconds = (fileSize / (800 * 1024)).ceil();
        return Duration(seconds: estimatedSeconds.clamp(5, 3600));
      }
      return const Duration(seconds: 60);
    } catch (e) {
      debugPrint('Duration detection failed: $e');
      return const Duration(seconds: 60);
    }
  }

  Future<Uint8List?> generateVideoThumbnail(File videoFile) async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        quality: 50,
        timeMs: 1000,
      );
      return uint8list;
    } catch (e) {
      debugPrint('Thumbnail generation failed: $e');
      return null;
    }
  }

  Future<File> transcodeVideoToCompatibleFormat(File originalVideo) async {
    try {
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

      return File(mediaInfo.file!.path);
    } catch (e) {
      return originalVideo;
    }
  }

  // ========== UPLOAD & STORAGE ==========

  Future<String> uploadVideo({
    required String lessonId,
    required String educatorId,
    required File videoFile,
    required Function(double) onProgress,
  }) async {
    try {
      onProgress(0.1);
      final compatibleVideo = await transcodeVideoToCompatibleFormat(videoFile);
      onProgress(0.3);

      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '$educatorId/$lessonId/$fileName';

      await _client.storage.from('videos').uploadBinary(
            filePath,
            await compatibleVideo.readAsBytes(),
            fileOptions: const FileOptions(upsert: true),
          );

      onProgress(1.0);

      try {
        if (compatibleVideo.path != videoFile.path) {
          await compatibleVideo.delete();
        }
      } catch (e) {
        debugPrint('Could not delete temporary video file: $e');
      }

      return _client.storage.from('videos').getPublicUrl(filePath);
    } catch (e) {
      throw Exception('Failed to upload video: ${e.toString()}');
    }
  }

  Future<String?> generateThumbnail({
    required String lessonId,
    required String educatorId,
    required File videoFile,
  }) async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 320,
        quality: 50,
        timeMs: 1000,
      );

      if (uint8list == null) return null;

      final tempFile =
          File('${Directory.systemTemp.path}/${lessonId}_thumb.jpg');
      await tempFile.writeAsBytes(uint8list);

      final fileName = 'thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '$educatorId/$lessonId/$fileName';

      await _client.storage.from('thumbnails').upload(filePath, tempFile);
      await tempFile.delete();

      return _client.storage.from('thumbnails').getPublicUrl(filePath);
    } catch (e) {
      return null;
    }
  }

  // ========== DATABASE OPERATIONS ==========

  Future<String> createLesson({
    required String title,
    required String subject,
    required String grade,
    required int durationSeconds,
    required String educatorId,
    String? description,
    bool isPublished = false,
    DateTime? scheduledPublish,
  }) async {
    try {
      final bool actualIsPublished;
      final String? actualScheduledPublish;

      if (scheduledPublish != null) {
        actualIsPublished = false;
        actualScheduledPublish = scheduledPublish.toIso8601String();
      } else {
        actualIsPublished = isPublished;
        actualScheduledPublish = null;
      }

      final response = await _client.from('lessons').insert({
        'title': title,
        'subject': subject,
        'grade': grade,
        'duration': durationSeconds,
        'educator_id': educatorId,
        'description': description,
        'is_published': actualIsPublished,
        'scheduled_publish': actualScheduledPublish,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select('id');

      if (response.isEmpty) throw Exception('No ID returned');
      return response.first['id'] as String;
    } catch (e) {
      throw Exception('Failed to create lesson: ${e.toString()}');
    }
  }

  Future<void> updateLessonMedia({
    required String lessonId,
    required String videoUrl,
    String? thumbnailUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'video_url': videoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (thumbnailUrl != null) {
        updateData['thumbnail_url'] = thumbnailUrl;
      }

      await _client.from('lessons').update(updateData).eq('id', lessonId);
    } catch (e) {
      throw Exception('Failed to update lesson media: ${e.toString()}');
    }
  }

  Future<String> getEducatorGrade(String educatorId) async {
    try {
      final response = await _client
          .from('educators')
          .select('grade_level')
          .eq('user_id', educatorId)
          .single();
      return response['grade_level'] as String? ?? 'Grade 10';
    } catch (e) {
      return 'Grade 10';
    }
  }

  Future<List<String>> getEducatorSubjects(String educatorId) async {
    try {
      final response = await _client
          .from('educators')
          .select('subjects_taught')
          .eq('user_id', educatorId)
          .single();

      final subjects = response['subjects_taught'] as List<dynamic>?;
      return subjects?.cast<String>() ?? getAvailableSubjects();
    } catch (e) {
      return getAvailableSubjects();
    }
  }

  List<String> getAvailableSubjects() {
    return [
      'Mathematics',
      'English',
      'South African Sign Language',
      'Technology',
      'Economic Management Sciences',
      'Life Orientation'
    ];
  }

  // ========== ULTRA-FAST LESSON CREATION ==========

  Future<void> createLessonUltraFast({
    required String title,
    required String subject,
    required String grade,
    required File videoFile,
    required String educatorId,
    String? description,
    bool isPublished = false,
    DateTime? scheduledPublish,
    required Function(double) onProgress,
  }) async {
    try {
      validateVideoFile(videoFile);
      onProgress(0.05);

      Duration duration;
      try {
        duration = await getVideoDuration(videoFile);
      } catch (e) {
        duration = const Duration(seconds: 60);
      }
      onProgress(0.15);

      final lessonId = await createLesson(
        title: title,
        subject: subject,
        grade: grade,
        durationSeconds: duration.inSeconds,
        educatorId: educatorId,
        description: description,
        isPublished: isPublished,
        scheduledPublish: scheduledPublish,
      );
      onProgress(0.30);

      final results = await Future.wait([
        uploadVideo(
          lessonId: lessonId,
          educatorId: educatorId,
          videoFile: videoFile,
          onProgress: (progress) {
            onProgress(0.30 + (progress * 0.60));
          },
        ),
        generateThumbnail(
          lessonId: lessonId,
          educatorId: educatorId,
          videoFile: videoFile,
        ),
      ], eagerError: true);

      final videoUrl = results[0] as String;
      final thumbnailUrl = results[1] as String?;

      await updateLessonMedia(
        lessonId: lessonId,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
      );

      onProgress(1.0);
    } catch (e) {
      rethrow;
    }
  }

  // ========== GETTERS - EXACTLY LIKE VideoUploadService ==========

  double get currentZoomLevel => _currentZoomLevel;
  bool get isFrontCamera => _isFrontCamera;
  bool get isCameraInitialized => _isCameraInitialized;
  bool get isRecording => _isRecording;
  Duration get recordingDuration => _recordingDuration;
  camera_package.CameraController? get cameraController => _cameraController;

  // ========== UTILITIES ==========

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<int> getFileSize(File file) async => await file.length();

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  Future<Map<String, dynamic>> getFileInfo(File file) async {
    try {
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      final path = file.path;
      final extension = path.split('.').last.toLowerCase();

      return {
        'exists': exists,
        'size': size,
        'path': path,
        'extension': extension,
        'filename': path.split('/').last,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<void> debugStorageAccess() async {
    try {
      debugPrint('=== STORAGE DEBUG INFO ===');
      final listResult = await _client.storage.from('videos').list();
      debugPrint('Bucket list success: ${listResult.length} items');
      debugPrint('=== END DEBUG INFO ===');
    } catch (e) {
      debugPrint('=== STORAGE DEBUG ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('=== END DEBUG INFO ===');
      rethrow;
    }
  }

  Future<void> debugPermissions() async {
    debugPrint('=== PERMISSION DEBUG ===');
    debugPrint('Storage: ${await Permission.storage.status}');
    debugPrint('Photos: ${await Permission.photos.status}');
    debugPrint('Camera: ${await Permission.camera.status}');
    debugPrint('Microphone: ${await Permission.microphone.status}');
    debugPrint('=== END DEBUG ===');
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupAllResources();
  }
}
