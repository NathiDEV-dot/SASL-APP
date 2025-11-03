// ignore_for_file: duplicate_import

import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';

class LessonCreationService {
  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();

  // Camera state management
  bool _isCameraInUse = false;
  DateTime? _lastCameraAccessTime;

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
      throw Exception('Failed to pick video');
    }
  }

  // Record video using camera
  Future<File?> recordVideo() async {
    if (_isCameraInUse) {
      throw Exception('Camera is currently in use');
    }

    _isCameraInUse = true;

    try {
      final XFile? recordedFile = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (recordedFile != null) {
        return File(recordedFile.path);
      }
      return null;
    } catch (e) {
      throw Exception(
          'Camera unavailable. Close other camera apps and try again.');
    } finally {
      _isCameraInUse = false;
    }
  }

  Future<void> _cleanupCameraResources() async {
    _isCameraInUse = false;
    await Future.delayed(const Duration(milliseconds: 300));
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
  }

  // Get video duration
  Future<Duration> getVideoDuration(File videoFile) async {
    final controller = VideoPlayerController.file(videoFile);
    try {
      await controller.initialize();
      return controller.value.duration;
    } finally {
      await controller.dispose();
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
      final fileName =
          'video_${DateTime.now().millisecondsSinceEpoch}${path.extension(videoFile.path)}';
      final filePath = '$educatorId/$lessonId/$fileName';

      await _client.storage.from('videos').upload(filePath, videoFile);
      return _client.storage.from('videos').getPublicUrl(filePath);
    } catch (e) {
      throw Exception('Failed to upload video');
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
      return null;
    }
  }

  // Create lesson in database
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
      final response = await _client.from('lessons').insert({
        'title': title,
        'subject': subject,
        'grade': grade,
        'duration': durationSeconds,
        'educator_id': educatorId,
        'description': description,
        'is_published': isPublished,
        'scheduled_publish': scheduledPublish?.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select('id');

      if (response.isEmpty) throw Exception('No ID returned');
      return response.first['id'] as String;
    } catch (e) {
      throw Exception('Failed to create lesson');
    }
  }

  // ADD THIS MISSING METHOD - Update lesson with media URLs
  Future<void> updateLessonMedia({
    required String lessonId,
    required String videoUrl,
    String? thumbnailUrl,
  }) async {
    try {
      final updateData = {
        'video_url': videoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (thumbnailUrl != null) {
        updateData['thumbnail_url'] = thumbnailUrl;
      }

      await _client.from('lessons').update(updateData).eq('id', lessonId);
    } catch (e) {
      throw Exception('Failed to update lesson media');
    }
  }

  // Update lesson with video URLs (for backward compatibility)
  Future<void> updateLessonUrls({
    required String lessonId,
    required String videoUrl,
    required String thumbnailUrl,
  }) async {
    try {
      await _client.from('lessons').update({
        'video_url': videoUrl,
        'thumbnail_url': thumbnailUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', lessonId);
    } catch (e) {
      throw Exception('Failed to update lesson URLs');
    }
  }

  // Schedule lesson for later publication
  Future<void> scheduleLesson({
    required String lessonId,
    required DateTime publishDate,
  }) async {
    try {
      await _client.from('lessons').update({
        'scheduled_publish': publishDate.toIso8601String(),
        'is_published': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', lessonId);
    } catch (e) {
      throw Exception('Failed to schedule lesson');
    }
  }

  // ULTRA-FAST Lesson Creation Method
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

      // Step 2: Get duration (10%)
      final duration = await getVideoDuration(videoFile);
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
    } catch (e) {
      await _cleanupCameraResources();
      rethrow;
    }
  }

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
}
