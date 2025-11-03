// ignore_for_file: unnecessary_cast, unnecessary_null_comparison, unused_element

import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class StudentService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _loggerName = 'StudentService';

  // Get student progress statistics - FIXED FOR YOUR SCHEMA
  Future<Map<String, dynamic>> getStudentProgress(String studentCode) async {
    try {
      // Get student info from pre_verified_users
      final studentResponse = await _supabase
          .from('pre_verified_users')
          .select('grade')
          .eq('student_code', studentCode)
          .single();

      final grade = studentResponse['grade'] as String? ?? 'unknown';

      // Get total lessons for this grade
      final lessonsResponse = await _supabase
          .from('lessons')
          .select('id')
          .eq('grade', grade)
          .eq('is_published', true)
          .count(CountOption.exact);

      final totalLessons = lessonsResponse.count ?? 0;

      // Get completed lessons - FIXED COLUMN NAMES
      final completedResponse = await _supabase
          .from('student_progress')
          .select('lesson_id')
          .eq('completed', true);

      final completedLessons = completedResponse.length;
      final progressPercentage = totalLessons > 0
          ? ((completedLessons / totalLessons) * 100).round()
          : 0;

      _logInfo(
          'Progress for $studentCode: $completedLessons/$totalLessons completed ($progressPercentage%)');

      return {
        'total_lessons': totalLessons,
        'completed_lessons': completedLessons,
        'progress_percentage': progressPercentage,
      };
    } catch (e, stackTrace) {
      _logError('Error in getStudentProgress: $e', e, stackTrace);
      return {
        'total_lessons': 0,
        'completed_lessons': 0,
        'progress_percentage': 0,
      };
    }
  }

  // Get lessons by student's grade - FIXED FOREIGN KEY
  Future<List<Map<String, dynamic>>> getLessonsByGrade(String grade) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('''
            *,
            profiles!fk_lessons_educator(
              id,
              first_name,
              last_name,
              avatar_url
            )
          ''')
          .eq('is_published', true)
          .eq('grade', grade)
          .order('created_at', ascending: false);

      _logInfo('Fetched ${response.length} lessons for grade: $grade');
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e, stackTrace) {
      _logError('Error in getLessonsByGrade: $e', e, stackTrace);
      return [];
    }
  }

  // Get newest lessons - FIXED
  Future<List<Map<String, dynamic>>> getNewestLessons(String grade,
      {int limit = 10}) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('''
            *,
            profiles!fk_lessons_educator(
              id,
              first_name,
              last_name,
              avatar_url
            )
          ''')
          .eq('is_published', true)
          .eq('grade', grade)
          .order('created_at', ascending: false)
          .limit(limit);

      _logInfo('Fetched ${response.length} newest lessons for grade: $grade');
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e, stackTrace) {
      _logError('Error in getNewestLessons: $e', e, stackTrace);
      return [];
    }
  }

  // Get recommended lessons - simplified version
  Future<List<Map<String, dynamic>>> getRecommendedLessons(
      String studentCode, String grade) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('''
            *,
            profiles!fk_lessons_educator(
              id,
              first_name,
              last_name,
              avatar_url
            )
          ''')
          .eq('is_published', true)
          .eq('grade', grade)
          .order('view_count', ascending: false)
          .limit(6);

      _logInfo(
          'Fetched ${response.length} recommended lessons for grade: $grade');
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e, stackTrace) {
      _logError('Error in getRecommendedLessons: $e', e, stackTrace);
      return [];
    }
  }

  // Get popular lessons - FIXED COLUMN NAME (view_count instead of views)
  Future<List<Map<String, dynamic>>> getPopularLessons(String grade,
      {int limit = 5}) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('''
            *,
            profiles!fk_lessons_educator(
              id,
              first_name,
              last_name,
              avatar_url
            )
          ''')
          .eq('is_published', true)
          .eq('grade', grade)
          .order('view_count', ascending: false)
          .limit(limit);

      _logInfo('Fetched ${response.length} popular lessons for grade: $grade');
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e, stackTrace) {
      _logError('Error in getPopularLessons: $e', e, stackTrace);
      return [];
    }
  }

  // Get subjects by grade - FIXED
  // Get subjects by grade - USING PREDEFINED SUBJECTS
  Future<List<String>> getSubjectsByGrade(String grade) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('subject')
          .eq('grade', grade)
          .eq('is_published', true);

      // Get unique subjects from database
      final dbSubjects = response
          .map((item) => item['subject'] as String?)
          .where((subject) => subject != null && subject.isNotEmpty)
          .map((subject) => subject!)
          .toSet()
          .toList();

      // If no subjects found in database, return predefined subjects
      if (dbSubjects.isEmpty) {
        _logInfo(
            'No subjects found in DB for grade: $grade, using predefined subjects');
        return getAvailableSubjects();
      }

      _logInfo('Found ${dbSubjects.length} unique subjects for grade: $grade');
      return dbSubjects;
    } catch (e, stackTrace) {
      _logError('Error in getSubjectsByGrade: $e', e, stackTrace);
      return getAvailableSubjects(); // Fallback to predefined subjects
    }
  }

// Predefined subjects list
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

  // Record lesson view - FIXED
  Future<void> recordLessonView(String studentCode, String lessonId) async {
    try {
      // First get student ID from pre_verified_users
      final studentResponse = await _supabase
          .from('pre_verified_users')
          .select('id')
          .eq('student_code', studentCode)
          .single();

      final studentId = studentResponse['id'] as String;

      await _supabase.from('lesson_views').upsert({
        'student_id': studentId,
        'lesson_id': lessonId,
        'viewed_at': DateTime.now().toIso8601String(),
      });

      // Increment lesson view_count
      await _supabase.from('lessons').update({
        'view_count': _supabase.rpc('increment', params: {'x': 1})
      }).eq('id', lessonId);

      _logInfo(
          'Lesson view recorded for student: $studentCode, lesson: $lessonId');
    } catch (e, stackTrace) {
      _logError('Error recording lesson view', e, stackTrace);
    }
  }

  // Mark lesson as completed - FIXED COLUMN NAMES
  Future<bool> markLessonCompleted(String studentCode, String lessonId) async {
    try {
      // First get student ID from pre_verified_users
      final studentResponse = await _supabase
          .from('pre_verified_users')
          .select('id')
          .eq('student_code', studentCode)
          .single();

      final studentId = studentResponse['id'] as String;

      await _supabase.from('student_progress').upsert({
        'student_id': studentId,
        'lesson_id': lessonId,
        'completed': true,
        'progress_percentage': 100,
        'completed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      _logInfo(
          'Lesson marked as completed: $lessonId for student: $studentCode');
      return true;
    } catch (e, stackTrace) {
      _logError('Error marking lesson as completed', e, stackTrace);
      return false;
    }
  }

  // Get student's enrolled classes
  Future<List<Map<String, dynamic>>> getEnrolledClasses(
      String studentCode) async {
    try {
      final response = await _supabase.from('class_enrollments').select('''
            *,
            classes!class_enrollments_class_id_fkey(
              id,
              name,
              subject,
              grade_level,
              educator_id
            )
          ''').eq('student_code', studentCode);

      _logInfo(
          'Fetched ${response.length} enrolled classes for student: $studentCode');
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e, stackTrace) {
      _logError('Error fetching enrolled classes for student: $studentCode', e,
          stackTrace);
      return [];
    }
  }

  // Search lessons - FIXED
  Future<List<Map<String, dynamic>>> searchLessons(
      String query, String grade) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('''
            *,
            profiles!fk_lessons_educator(
              id,
              first_name,
              last_name,
              avatar_url
            )
          ''')
          .eq('is_published', true)
          .eq('grade', grade)
          .or('title.ilike.%$query%,description.ilike.%$query%,subject.ilike.%$query%')
          .order('created_at', ascending: false);

      _logInfo(
          'Found ${response.length} lessons for search: "$query" in grade: $grade');
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e, stackTrace) {
      _logError('Error searching lessons: $query', e, stackTrace);
      return [];
    }
  }

  // Get lesson with video URL and details - FIXED
  Future<Map<String, dynamic>> getLessonWithVideo(String lessonId) async {
    try {
      final response = await _supabase.from('lessons').select('''
            *,
            profiles!fk_lessons_educator(
              id,
              first_name,
              last_name,
              avatar_url,
              subject_specialization
            )
          ''').eq('id', lessonId).single();

      final lesson = response as Map<String, dynamic>;

      // Log video URL for debugging
      final videoUrl = lesson['video_url'] as String?;
      _logInfo('Lesson $lessonId video URL: ${videoUrl ?? 'NOT AVAILABLE'}');

      return lesson;
    } catch (e, stackTrace) {
      _logError('Error fetching lesson with video: $lessonId', e, stackTrace);
      return {};
    }
  }

  // Check if lesson is completed by student - FIXED
  Future<bool> isLessonCompleted(String studentCode, String lessonId) async {
    try {
      // First get student ID from pre_verified_users
      final studentResponse = await _supabase
          .from('pre_verified_users')
          .select('id')
          .eq('student_code', studentCode)
          .single();

      final studentId = studentResponse['id'] as String;

      final response = await _supabase
          .from('student_progress')
          .select('completed')
          .eq('student_id', studentId)
          .eq('lesson_id', lessonId)
          .single()
          .catchError((_) => null);

      return response != null && response['completed'] == true;
    } catch (e, stackTrace) {
      _logError('Error checking lesson completion status', e, stackTrace);
      return false;
    }
  }

  // Private logging methods
  void _logError(String message, dynamic error, StackTrace stackTrace) {
    developer.log(
      message,
      error: error,
      stackTrace: stackTrace,
      name: _loggerName,
      level: 1000,
    );
  }

  void _logInfo(String message) {
    developer.log(
      message,
      name: _loggerName,
      level: 800,
    );
  }

  void _logWarning(String message) {
    developer.log(
      message,
      name: _loggerName,
      level: 900,
    );
  }
}
