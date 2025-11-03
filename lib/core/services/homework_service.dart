// lib/core/services/homework_service.dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class HomeworkService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get homework assignments for a student
  Future<List<Map<String, dynamic>>> getHomeworkAssignments(
      String studentCode) async {
    try {
      final response = await _supabase
          .from('homework_assignments')
          .select('''
            *,
            lessons (
              title,
              subject,
              video_url,
              thumbnail_url,
              educator_id,
              profiles!lessons_educator_id_fkey (first_name, last_name)
            )
          ''')
          .eq('student_code', studentCode)
          .order('due_date', ascending: true);

      return response;
    } catch (e) {
      throw Exception('Failed to load homework assignments: $e');
    }
  }

  // Submit homework with video
  Future<void> submitHomework({
    required String studentCode,
    required String assignmentId,
    required String submissionText,
    required File? videoFile,
    required List<String> attachmentUrls,
    required Function(double) onProgress,
  }) async {
    try {
      String? videoUrl;

      // Upload video if provided
      if (videoFile != null) {
        videoUrl = await _uploadHomeworkVideo(
          studentCode: studentCode,
          assignmentId: assignmentId,
          videoFile: videoFile,
          onProgress: onProgress,
        );
      }

      await _supabase.from('homework_submissions').insert({
        'student_code': studentCode,
        'assignment_id': assignmentId,
        'submission_text': submissionText,
        'video_url': videoUrl,
        'attachment_urls': attachmentUrls,
        'submitted_at': DateTime.now().toIso8601String(),
        'status': 'submitted',
      });
    } catch (e) {
      throw Exception('Failed to submit homework: $e');
    }
  }

  // Upload homework video
  Future<String> _uploadHomeworkVideo({
    required String studentCode,
    required String assignmentId,
    required File videoFile,
    required Function(double) onProgress,
  }) async {
    try {
      onProgress(0.1);

      final fileName = 'homework_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = 'homework/$studentCode/$assignmentId/$fileName';

      // Upload video
      await _supabase.storage.from('homework_videos').uploadBinary(
            filePath,
            await videoFile.readAsBytes(),
            fileOptions: const FileOptions(upsert: true),
          );

      onProgress(1.0);

      return _supabase.storage.from('homework_videos').getPublicUrl(filePath);
    } catch (e) {
      throw Exception('Failed to upload homework video: $e');
    }
  }

  // Get homework submissions for a student
  Future<List<Map<String, dynamic>>> getHomeworkSubmissions(
      String studentCode) async {
    try {
      final response = await _supabase
          .from('homework_submissions')
          .select('''
            *,
            homework_assignments (
              title,
              due_date,
              max_points,
              lessons (
                title,
                subject
              )
            )
          ''')
          .eq('student_code', studentCode)
          .order('submitted_at', ascending: false);

      return response;
    } catch (e) {
      throw Exception('Failed to load homework submissions: $e');
    }
  }

  // Validate video file
  void validateVideoFile(File videoFile) {
    final fileSize = videoFile.lengthSync();
    const maxSize = 200 * 1024 * 1024; // 200MB for homework

    if (fileSize > maxSize) {
      throw Exception('Video file too large. Maximum size is 200MB');
    }

    final extension = path.extension(videoFile.path).toLowerCase();
    final allowedExtensions = ['.mp4', '.mov', '.avi'];

    if (!allowedExtensions.contains(extension)) {
      throw Exception('Unsupported video format. Please use MP4, MOV, or AVI');
    }
  }
}
