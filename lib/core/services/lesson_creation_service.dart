// ignore_for_file: implementation_imports, prefer_const_constructors, avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/src/platform_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' as path;

class LessonCreationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> getEducatorGrade(String educatorId) async {
    try {
      final response = await _supabase
          .from('educators')
          .select('grade')
          .eq('user_id', educatorId)
          .single();
      
      return response['grade']?.toString() ?? 'Not Specified';
    } catch (e) {
      print('Error fetching educator grade: $e');
      return 'Not Specified';
    }
  }

  Future<List<String>> getEducatorSubjects(String educatorId) async {
    try {
      final response = await _supabase
          .from('educator_subjects')
          .select('subject')
          .eq('educator_id', educatorId);
      
      if (response.isNotEmpty) {
        return response.map((item) => item['subject'].toString()).toList();
      }
      
      return ['Mathematics', 'Science', 'English', 'History', 'Physics', 'Chemistry', 'Biology'];
    } catch (e) {
      print('Error fetching educator subjects: $e');
      return ['Mathematics', 'Science', 'English', 'History'];
    }
  }

  Future<Duration> getVideoDuration(File videoFile) async {
    try {
      // Check if file exists
      if (!await videoFile.exists()) {
        throw Exception('Video file does not exist');
      }

      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();
      
      return duration;
    } catch (e) {
      print('Error getting video duration: $e');
      try {
        final fileSize = await videoFile.length();
        const averageBitrate = 2000000;
        final estimatedSeconds = (fileSize * 8 / averageBitrate).toInt();
        return Duration(seconds: estimatedSeconds.clamp(1, 3600));
      } catch (e2) {
        return Duration(seconds: 300); // Default 5 minutes
      }
    }
  }

  Future<Duration> getVideoDurationFromBytes(Uint8List videoBytes) async {
    try {
      if (videoBytes.isEmpty) {
        throw Exception('Video bytes are empty');
      }

      // Create temporary file to get duration
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/temp_video.mp4');
      await tempFile.writeAsBytes(videoBytes);
      
      final duration = await getVideoDuration(tempFile);
      
      // Clean up
      await tempFile.delete();
      await tempDir.delete();
      
      return duration;
    } catch (e) {
      print('Error getting video duration from bytes: $e');
      final estimatedSeconds = (videoBytes.length * 8 / 2000000).toInt();
      return Duration(seconds: estimatedSeconds.clamp(1, 3600));
    }
  }

  Future<bool> validateLessonData({
    required String title,
    required String subject,
    required String grade,
    required int durationSeconds,
  }) async {
    if (title.isEmpty) throw Exception('Title is required');
    if (subject.isEmpty) throw Exception('Subject is required');
    if (grade.isEmpty) throw Exception('Grade is required');
    if (durationSeconds <= 0) throw Exception('Video duration must be positive');
    
    return true;
  }

  Future<String> createLesson({
    required String title,
    required String subject,
    required String grade,
    required int durationSeconds,
    required String educatorId,
    required String description,
    required bool isPublished,
    required DateTime? scheduledPublish,
  }) async {
    try {
      // Validate data first
      await validateLessonData(
        title: title,
        subject: subject,
        grade: grade,
        durationSeconds: durationSeconds,
      );

      final response = await _supabase
          .from('lessons')
          .insert({
            'title': title,
            'subject': subject,
            'grade': grade,
            'duration_seconds': durationSeconds,
            'educator_id': educatorId,
            'description': description,
            'is_published': isPublished,
            'scheduled_publish': scheduledPublish?.toIso8601String(),
            'status': 'draft',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select();
      
      if (response.isEmpty) {
        throw Exception('Failed to create lesson: No response from server');
      }
      
      return response.first['id'].toString();
    } catch (e) {
      throw Exception('Failed to create lesson: $e');
    }
  }

  Future<String> uploadVideo({
    required String lessonId,
    required String educatorId,
    required File videoFile,
    required Function(double) onProgress,
  }) async {
    try {
      // Check if file exists
      if (!await videoFile.exists()) {
        throw Exception('Video file does not exist');
      }

      final String fileName = 'lesson_${lessonId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      
      final fileBytes = await videoFile.readAsBytes();
      final fileSize = fileBytes.length;
      
      if (fileSize == 0) {
        throw Exception('Video file is empty');
      }

      int uploadedBytes = 0;
      
      // Upload in chunks to show progress
      const chunkSize = 1024 * 1024; // 1MB chunks
      for (int i = 0; i < fileBytes.length; i += chunkSize) {
        final end = (i + chunkSize < fileBytes.length) ? i + chunkSize : fileBytes.length;
        final chunk = fileBytes.sublist(i, end);
        
        if (i == 0) {
          // First chunk - create file
          await _supabase.storage
              .from('lesson-videos')
              .uploadBinary(fileName, chunk, fileOptions: FileOptions(upsert: true));
        } else {
          // Subsequent chunks - append
          await _supabase.storage
              .from('lesson-videos')
              .updateBinary(fileName, chunk);
        }
        
        uploadedBytes = end;
        final progress = uploadedBytes / fileSize;
        onProgress(progress);
        
        // Small delay to show progress
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final String publicUrl = _supabase.storage
          .from('lesson-videos')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload video: $e');
    }
  }

  Future<String> uploadVideoWebFromList({
    required String lessonId,
    required String educatorId,
    required Uint8List fileBytes,
    required String fileName,
    required Function(double) onProgress,
  }) async {
    try {
      if (fileBytes.isEmpty) {
        throw Exception('Video bytes are empty');
      }

      final String uploadFileName = 'lesson_${lessonId}_${DateTime.now().millisecondsSinceEpoch}${_getFileExtension(fileName)}';
      
      final fileSize = fileBytes.length;
      int uploadedBytes = 0;
      
      // Upload in chunks
      const chunkSize = 1024 * 1024;
      for (int i = 0; i < fileBytes.length; i += chunkSize) {
        final end = (i + chunkSize < fileBytes.length) ? i + chunkSize : fileBytes.length;
        final chunk = fileBytes.sublist(i, end);
        
        if (i == 0) {
          await _supabase.storage
              .from('lesson-videos')
              .uploadBinary(uploadFileName, chunk, fileOptions: FileOptions(upsert: true));
        } else {
          await _supabase.storage
              .from('lesson-videos')
              .updateBinary(uploadFileName, chunk);
        }
        
        uploadedBytes = end;
        final progress = uploadedBytes / fileSize;
        onProgress(progress);
        
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final String publicUrl = _supabase.storage
          .from('lesson-videos')
          .getPublicUrl(uploadFileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload video: $e');
    }
  }

  Future<void> updateLessonUrls({
    required String lessonId,
    required String videoUrl,
    required String thumbnailUrl,
  }) async {
    try {
      await _supabase
          .from('lessons')
          .update({
            'video_url': videoUrl,
            'thumbnail_url': thumbnailUrl,
            'status': 'completed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', lessonId);
    } catch (e) {
      throw Exception('Failed to update lesson URLs: $e');
    }
  }

  Future<String> generateThumbnail({
    required String lessonId,
    required String educatorId,
    required File videoFile,
  }) async {
    try {
      if (!await videoFile.exists()) {
        throw Exception('Video file does not exist for thumbnail generation');
      }

      final uint8List = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640,
        quality: 75,
      );

      if (uint8List == null) {
        throw Exception('Could not generate thumbnail');
      }

      final String thumbnailName = 'thumbnail_${lessonId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await _supabase.storage
          .from('lesson-thumbnails')
          .uploadBinary(thumbnailName, uint8List);

      final String thumbnailUrl = _supabase.storage
          .from('lesson-thumbnails')
          .getPublicUrl(thumbnailName);

      return thumbnailUrl;
    } catch (e) {
      print('Thumbnail generation failed: $e');
      return 'https://via.placeholder.com/640x360/4361EE/FFFFFF?text=Lesson+Thumbnail';
    }
  }

  Future<String> generateThumbnailFromBytes({
    required String lessonId,
    required String educatorId,
    required Uint8List videoBytes,
  }) async {
    try {
      if (videoBytes.isEmpty) {
        throw Exception('Video bytes are empty for thumbnail generation');
      }

      // Create temporary file
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/temp_video.mp4');
      await tempFile.writeAsBytes(videoBytes);
      
      final thumbnailUrl = await generateThumbnail(
        lessonId: lessonId,
        educatorId: educatorId,
        videoFile: tempFile,
      );
      
      // Clean up
      await tempFile.delete();
      await tempDir.delete();
      
      return thumbnailUrl;
    } catch (e) {
      print('Thumbnail generation from bytes failed: $e');
      return 'https://via.placeholder.com/640x360/4361EE/FFFFFF?text=Lesson+Thumbnail';
    }
  }

  String _getFileExtension(String fileName) {
    final ext = fileName.toLowerCase();
    if (ext.endsWith('.mp4')) return '.mp4';
    if (ext.endsWith('.mov')) return '.mov';
    if (ext.endsWith('.avi')) return '.avi';
    if (ext.endsWith('.mkv')) return '.mkv';
    if (ext.endsWith('.webm')) return '.webm';
    return '.mp4';
  }

  void validateVideoFile(PlatformFile file) {
    if (file.size == 0) {
      throw Exception('Video file is empty');
    }
    
    final validExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];
    final extension = path.extension(file.name).toLowerCase();
    
    if (!validExtensions.contains(extension)) {
      throw Exception('Invalid video format. Supported: MP4, MOV, AVI, MKV, WEBM');
    }
  }
}