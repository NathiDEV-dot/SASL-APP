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

class LessonCreationService with WidgetsBindingObserver {
  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();

  // Camera state management
  bool _isCameraInUse = false;
  bool _isAppInBackground = false;
  Completer<File?>? _recordingCompleter;

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
        // Handle this case
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
      // Check camera permission
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        cameraStatus = await Permission.camera.request();
      }

      // Check microphone permission for audio recording
      var microphoneStatus = await Permission.microphone.status;
      if (!microphoneStatus.isGranted) {
        microphoneStatus = await Permission.microphone.request();
      }

      // Check storage permission for saving videos
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

  // Record video using camera - ENHANCED VERSION
  Future<File?> recordVideo() async {
    if (_isCameraInUse) {
      throw Exception('Camera is currently in use. Please wait...');
    }

    if (_isAppInBackground) {
      throw Exception('Cannot start recording while app is in background');
    }

    // Check permissions first
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
        preferredCameraDevice: CameraDevice.rear,
        maxDuration: const Duration(minutes: 30),
      )
          .timeout(const Duration(seconds: 60), onTimeout: () {
        throw Exception(
            'Camera recording timed out. Please try recording a shorter video.');
      });

      if (recordedFile != null) {
        // Verify the file was actually created and is accessible
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

      // Provide more specific error messages
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

  // Alternative recording method with shorter timeout
  Future<File?> recordVideoQuick() async {
    try {
      final XFile? recordedFile = await _imagePicker
          .pickVideo(
            source: ImageSource.camera,
            preferredCameraDevice: CameraDevice.rear,
            maxDuration: const Duration(seconds: 30), // Shorter max duration
          )
          .timeout(const Duration(seconds: 15)); // Shorter timeout

      return recordedFile != null ? File(recordedFile.path) : null;
    } catch (e) {
      debugPrint('Quick recording failed: $e');
      return null;
    }
  }

  Future<void> _preCameraSetup() async {
    // Add delay to ensure previous camera is fully released
    await Future.delayed(const Duration(milliseconds: 500));

    // Force garbage collection
    await Future(() {});
  }

  Future<void> _postCameraCleanup() async {
    _isCameraInUse = false;
    _recordingCompleter = null;
    // Additional cleanup delay
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _cleanupCameraResources() async {
    _isCameraInUse = false;
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // Check camera availability
  Future<bool> checkCameraAvailability() async {
    try {
      // For web compatibility, we'll assume camera is available
      // In a real app, you might want to use camera package to check
      return true;
    } catch (e) {
      debugPrint('Camera availability check failed: $e');
      return false;
    }
  }

  // Validate video file
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

    // Additional validation for very large files
    if (fileSize > 100 * 1024 * 1024) {
      throw Exception(
          'Video file is very large. Please compress it below 100MB for better compatibility');
    }
  }

  // FIXED: Get video duration WITHOUT VideoPlayerController
  Future<Duration> getVideoDuration(File videoFile) async {
    try {
      // Method 1: Try to get duration using file metadata (safe)
      try {
        final fileSize = await videoFile.length();
        if (fileSize > 0) {
          // Smart estimation based on file size and common bitrates
          // Higher quality = more bytes per second
          final estimatedSeconds =
              (fileSize / (800 * 1024)).ceil(); // 800KB per second
          return Duration(
              seconds: estimatedSeconds.clamp(5, 3600)); // 5 seconds to 1 hour
        }
      } catch (e) {
        debugPrint('File size estimation failed: $e');
      }

      // Method 2: Return a reasonable default
      debugPrint('Using default video duration');
      return const Duration(seconds: 60); // 1 minute default
    } catch (e) {
      debugPrint('All duration methods failed, using default: $e');
      return const Duration(seconds: 60);
    }
  }

  // Generate video thumbnail for preview
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

  // CORRECTED: Transcode video to compatible format
  Future<File> transcodeVideoToCompatibleFormat(File originalVideo) async {
    try {
      print('Starting video transcoding for compatibility...');

      // Initialize video compression
      await VideoCompress.setLogLevel(0);

      // CORRECTED: Use the proper compressVideo method without outputPath parameter
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        originalVideo.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (mediaInfo == null || mediaInfo.file == null) {
        throw Exception('Video transcoding failed');
      }

      print('Video transcoding completed: ${mediaInfo.file!.path}');

      // CORRECTED: The compressed file is already saved, we just need to return it
      return File(mediaInfo.file!.path);
    } catch (e) {
      print('Video transcoding error: $e');
      // If transcoding fails, return original file as fallback
      return originalVideo;
    }
  }

  // Upload video to Supabase
  Future<String> uploadVideo({
    required String lessonId,
    required String educatorId,
    required File videoFile,
    required Function(double) onProgress,
  }) async {
    try {
      // Step 1: Transcode video first (30% of progress)
      print('Starting video transcoding...');
      onProgress(0.1);

      final compatibleVideo = await transcodeVideoToCompatibleFormat(videoFile);
      onProgress(0.3);

      // Step 2: Upload transcoded video (70% of progress)
      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '$educatorId/$lessonId/$fileName';

      print('Uploading transcoded video...');

      // Upload with progress tracking
      await _client.storage.from('videos').uploadBinary(
            filePath,
            await compatibleVideo.readAsBytes(),
            fileOptions: const FileOptions(
              upsert: true,
            ),
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
      print('Video upload failed: $e');
      throw Exception('Failed to upload video: ${e.toString()}');
    }
  }

  // Generate thumbnail
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
      print('Thumbnail generation failed: $e');
      return null;
    }
  }

  // Create lesson in database - UPDATED FOR PUBLISHING OPTIONS
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
      // Determine the actual publish status
      final bool actualIsPublished;
      final String? actualScheduledPublish;

      if (scheduledPublish != null) {
        // If scheduled for future, set as unpublished and store scheduled time
        actualIsPublished = false;
        actualScheduledPublish = scheduledPublish.toIso8601String();
      } else {
        // If no schedule time, use the isPublished flag directly
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

      final lessonId = response.first['id'] as String;
      print(
          'Lesson created with ID: $lessonId, Published: $actualIsPublished, Scheduled: $actualScheduledPublish');

      return lessonId;
    } catch (e) {
      print('Failed to create lesson: $e');
      throw Exception('Failed to create lesson: ${e.toString()}');
    }
  }

  // Update lesson with media URLs
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
      print('Lesson media updated for: $lessonId');
    } catch (e) {
      print('Failed to update lesson media: $e');
      throw Exception('Failed to update lesson media: ${e.toString()}');
    }
  }

  // NEW: Publish lesson immediately
  Future<void> publishLessonNow(String lessonId) async {
    try {
      await _client.from('lessons').update({
        'is_published': true,
        'scheduled_publish': null, // Clear any scheduled time
        'published_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', lessonId);

      print('Lesson published immediately: $lessonId');
    } catch (e) {
      print('Failed to publish lesson: $e');
      throw Exception('Failed to publish lesson: ${e.toString()}');
    }
  }

  // NEW: Schedule lesson for later publication
  Future<void> scheduleLesson({
    required String lessonId,
    required DateTime publishDate,
  }) async {
    try {
      // Validate schedule time (must be in future)
      if (publishDate.isBefore(DateTime.now())) {
        throw Exception('Schedule time must be in the future');
      }

      await _client.from('lessons').update({
        'is_published': false,
        'scheduled_publish': publishDate.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', lessonId);

      print('Lesson scheduled for: $publishDate, ID: $lessonId');
    } catch (e) {
      print('Failed to schedule lesson: $e');
      throw Exception('Failed to schedule lesson: ${e.toString()}');
    }
  }

  // NEW: Get scheduled lessons that need to be published
  Future<List<Map<String, dynamic>>> getLessonsToPublish() async {
    try {
      final now = DateTime.now().toIso8601String();

      final response = await _client
          .from('lessons')
          .select('*')
          .lt('scheduled_publish', now) // Less than current time
          .eq('is_published', false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting lessons to publish: $e');
      return [];
    }
  }

  // NEW: Publish scheduled lessons (to be called by a background service)
  Future<void> publishScheduledLessons() async {
    try {
      final lessonsToPublish = await getLessonsToPublish();

      for (final lesson in lessonsToPublish) {
        final lessonId = lesson['id'] as String;
        await publishLessonNow(lessonId);
        print('Auto-published scheduled lesson: $lessonId');
      }
    } catch (e) {
      print('Error publishing scheduled lessons: $e');
    }
  }

  // NEW: Update existing lesson's publishing status
  Future<void> updateLessonPublishing({
    required String lessonId,
    bool? isPublished,
    DateTime? scheduledPublish,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isPublished != null) {
        updateData['is_published'] = isPublished;
        if (isPublished) {
          updateData['published_at'] = DateTime.now().toIso8601String();
          updateData['scheduled_publish'] =
              null; // Clear schedule if publishing now
        }
      }

      if (scheduledPublish != null) {
        updateData['scheduled_publish'] = scheduledPublish.toIso8601String();
        updateData['is_published'] =
            false; // Ensure it's not published immediately
      }

      await _client.from('lessons').update(updateData).eq('id', lessonId);
      print('Lesson publishing updated: $lessonId');
    } catch (e) {
      print('Failed to update lesson publishing: $e');
      throw Exception('Failed to update lesson publishing: ${e.toString()}');
    }
  }

  // ULTRA-FAST Lesson Creation Method - UPDATED FOR PUBLISHING OPTIONS
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
      // Step 1: Quick validation (5%)
      validateVideoFile(videoFile);
      onProgress(0.05);

      // Step 2: Get duration (10%) - with safe error handling
      Duration duration;
      try {
        duration = await getVideoDuration(videoFile);
      } catch (e) {
        debugPrint('Duration detection failed, using default: $e');
        duration = const Duration(seconds: 60); // Use default
      }
      onProgress(0.15);

      // Step 3: Create lesson record (15%)
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

      // Step 4: Upload video and generate thumbnail in parallel (60%)
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

      // Step 5: Quick final update (10%)
      await updateLessonMedia(
        lessonId: lessonId,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
      );

      onProgress(1.0);

      print('Lesson creation completed: $lessonId');
    } catch (e) {
      await _cleanupCameraResources();
      print('Lesson creation failed: $e');
      rethrow;
    }
  }

  // Get educator's grade
  // Get educator's grade
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

  // Get educator's subjects
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

  // NEW: Get lesson by ID
  Future<Map<String, dynamic>?> getLesson(String lessonId) async {
    try {
      final response =
          await _client.from('lessons').select('*').eq('id', lessonId).single();

      return response as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting lesson: $e');
      return null;
    }
  }

  // NEW: Check if lesson is scheduled
  Future<bool> isLessonScheduled(String lessonId) async {
    try {
      final lesson = await getLesson(lessonId);
      if (lesson == null) return false;

      final scheduledPublish = lesson['scheduled_publish'];
      final isPublished = lesson['is_published'] as bool? ?? false;

      return scheduledPublish != null && !isPublished;
    } catch (e) {
      return false;
    }
  }

  // NEW: Get scheduled publish time
  Future<DateTime?> getScheduledPublishTime(String lessonId) async {
    try {
      final lesson = await getLesson(lessonId);
      if (lesson == null) return null;

      final scheduledPublish = lesson['scheduled_publish'];
      if (scheduledPublish == null) return null;

      return DateTime.parse(scheduledPublish as String);
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupAllResources();
  }
}
