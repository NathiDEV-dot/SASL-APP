// ignore_for_file: unused_import

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class ContentManagementService {
  final SupabaseClient _client;
  final ImagePicker _imagePicker = ImagePicker();

  ContentManagementService() : _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getEducatorLessons(
      String educatorId) async {
    try {
      final response = await _client
          .from('lessons')
          .select('''
            id,
            title,
            subject,
            grade,
            duration,
            video_url,
            thumbnail_url,
            is_published,
            created_at,
            updated_at,
            description,
            educator_id
          ''')
          .eq('educator_id', educatorId)
          .neq('video_url', '')
          .order('created_at', ascending: false);

      return await _enhanceLessonData(response);
    } catch (e) {
      debugPrint('❌ Error fetching lessons: $e');
      throw Exception('Failed to load lessons: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getContentStats(String educatorId) async {
    try {
      final lessons = await getEducatorLessons(educatorId);
      final totalLessons = lessons.length;
      final publishedLessons =
          lessons.where((lesson) => lesson['is_published'] == true).length;
      final totalViews =
          lessons.fold(0, (sum, lesson) => sum + (lesson['views'] as int));

      return {
        'total_videos': totalLessons,
        'published_videos': publishedLessons,
        'total_views': totalViews,
      };
    } catch (e) {
      debugPrint('❌ Error fetching content stats: $e');
      return {
        'total_videos': 0,
        'published_videos': 0,
        'total_views': 0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> _enhanceLessonData(
      List<dynamic> lessons) async {
    final enhancedLessons = <Map<String, dynamic>>[];

    for (final lesson in lessons) {
      try {
        final videoUrl = lesson['video_url'] as String? ?? '';
        if (videoUrl.isEmpty) continue;

        // Get analytics
        final analytics = await getLessonAnalytics(lesson['id'] as String);

        // Format duration
        final durationSeconds = lesson['duration'] as int? ?? 0;
        final durationText =
            _formatDuration(Duration(seconds: durationSeconds));

        // Subject styling
        final subject = lesson['subject'] as String? ?? 'General';
        final iconData = _getSubjectIcon(subject);
        final color = _getSubjectColor(subject);

        // Ensure thumbnail exists
        String thumbnailUrl = lesson['thumbnail_url'] as String? ?? '';
        if (thumbnailUrl.isEmpty) {
          thumbnailUrl =
              'https://via.placeholder.com/300x200/3B82F6/FFFFFF?text=Lesson+Video';
        }

        enhancedLessons.add({
          'id': lesson['id'],
          'title': lesson['title'],
          'subject': subject,
          'duration': durationSeconds,
          'duration_text': durationText,
          'video_url': videoUrl,
          'thumbnail_url': thumbnailUrl,
          'is_published': lesson['is_published'] ?? false,
          'description': lesson['description'],
          'views': analytics['total_views'],
          'students': analytics['unique_students'],
          'icon': iconData,
          'color': color,
        });
      } catch (e) {
        debugPrint('❌ Error enhancing lesson data: $e');
      }
    }

    return enhancedLessons;
  }

  Future<Map<String, dynamic>> getLessonAnalytics(String lessonId) async {
    try {
      final viewsResponse = await _client
          .from('lesson_views')
          .select('user_id')
          .eq('lesson_id', lessonId);

      final totalViews = viewsResponse.length;
      final uniqueStudents =
          viewsResponse.map((view) => view['user_id']).toSet().length;

      return {
        'total_views': totalViews,
        'unique_students': uniqueStudents,
      };
    } catch (e) {
      return {
        'total_views': 0,
        'unique_students': 0,
      };
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  IconData _getSubjectIcon(String subject) {
    final subjectIcons = {
      'Mathematics': Icons.calculate_rounded,
      'English': Icons.menu_book_rounded,
      'South African Sign Language': Icons.sign_language_rounded,
      'Technology': Icons.computer_rounded,
      'Economic Management Sciences': Icons.trending_up_rounded,
      'Life Orientation': Icons.self_improvement_rounded,
    };
    return subjectIcons[subject] ?? Icons.play_lesson_rounded;
  }

  Color _getSubjectColor(String subject) {
    final subjectColors = {
      'Mathematics': const Color(0xFF3B82F6),
      'English': const Color(0xFF8B5CF6),
      'South African Sign Language': const Color(0xFF06B6D4),
      'Technology': const Color(0xFF10B981),
      'Economic Management Sciences': const Color(0xFFF59E0B),
      'Life Orientation': const Color(0xFFEC4899),
    };
    return subjectColors[subject] ?? const Color(0xFF6B7280);
  }

  // Other methods remain the same...
  Future<void> updateLessonTitle(String lessonId, String newTitle) async {
    await _client.from('lessons').update({
      'title': newTitle,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', lessonId);
  }

  Future<void> updateLessonDescription(
      String lessonId, String newDescription) async {
    await _client.from('lessons').update({
      'description': newDescription,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', lessonId);
  }

  Future<void> deleteLesson(String lessonId) async {
    await _client.from('lessons').delete().eq('id', lessonId);
  }

  Future<File?> pickVideoFromGallery() async {
    final XFile? video =
        await _imagePicker.pickVideo(source: ImageSource.gallery);
    return video != null ? File(video.path) : null;
  }
}
