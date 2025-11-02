import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class StudentService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _loggerName = 'StudentService';

  // Get all available lessons for students (newest first)
  Future<List<Map<String, dynamic>>> getAvailableLessons() async {
    try {
      final response = await _supabase.from('lessons').select('''
            *,
            profiles!educator_id (
              id,
              first_name,
              last_name,
              avatar_url
            )
          ''').eq('is_published', true).order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e, stackTrace) {
      _logError('Error fetching available lessons', e, stackTrace);
      return [];
    }
  }

  // Get lessons by student's grade (newest first) - FIXED
  Future<List<Map<String, dynamic>>> getLessonsByGrade(String grade) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('''
            *,
            profiles!educator_id (
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
      _logError('Error fetching lessons by grade: $grade', e, stackTrace);
      return [];
    }
  }

  // Get lessons by subject (newest first)
  Future<List<Map<String, dynamic>>> getLessonsBySubject(String subject) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('''
            *,
            profiles!educator_id (
              id,
              first_name,
              last_name,
              avatar_url
            )
          ''')
          .eq('is_published', true)
          .eq('subject', subject)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e, stackTrace) {
      _logError('Error fetching lessons by subject: $subject', e, stackTrace);
      return [];
    }
  }

  // Get student's progress data using student code
  Future<Map<String, dynamic>> getStudentProgress(String studentCode) async {
    try {
      // Get completed lessons count from student_progress
      final completedResponse = await _supabase
          .from('student_progress')
          .select('lesson_id')
          .eq('student_code', studentCode)
          .eq('completed', true);

      final completedCount = completedResponse.length;

      // Get total available lessons count
      final totalResponse =
          await _supabase.from('lessons').select('id').eq('is_published', true);

      final totalCount = totalResponse.length;

      // Calculate progress percentage
      final progressPercentage =
          totalCount > 0 ? (completedCount / totalCount * 100).round() : 0;

      return {
        'completed_lessons': completedCount,
        'total_lessons': totalCount,
        'progress_percentage': progressPercentage,
        'current_streak': 7,
      };
    } catch (e, stackTrace) {
      _logError('Error fetching student progress for student: $studentCode', e,
          stackTrace);
      return {
        'completed_lessons': 0,
        'total_lessons': 0,
        'progress_percentage': 0,
        'current_streak': 0,
      };
    }
  }

  // Get recommended lessons for student (based on grade and completed subjects)
  Future<List<Map<String, dynamic>>> getRecommendedLessons(
      String studentCode, String grade) async {
    try {
      // Get student's completed subjects to recommend similar content
      final progressResponse =
          await _supabase.from('student_progress').select('''
            lessons:lesson_id (
              subject
            )
          ''').eq('student_code', studentCode).eq('completed', true);

      final completedSubjects = progressResponse
          .map((item) {
            final lessons = item['lessons'] as Map<String, dynamic>?;
            return lessons?['subject'] as String?;
          })
          .whereType<String>()
          .toSet()
          .toList();

      // If student has completed lessons, recommend similar subjects
      if (completedSubjects.isNotEmpty) {
        final response = await _supabase
            .from('lessons')
            .select('''
              *,
              profiles!educator_id (
                id,
                first_name,
                last_name,
                avatar_url
              )
            ''')
            .eq('is_published', true)
            .eq('grade', grade)
            .inFilter('subject', completedSubjects)
            .order('created_at', ascending: false)
            .limit(5);

        return (response as List).cast<Map<String, dynamic>>();
      } else {
        // Return newest lessons from student's grade
        final response = await _supabase
            .from('lessons')
            .select('''
              *,
              profiles!educator_id (
                id,
                first_name,
                last_name,
                avatar_url
              )
            ''')
            .eq('is_published', true)
            .eq('grade', grade)
            .order('created_at', ascending: false)
            .limit(5);

        return (response as List).cast<Map<String, dynamic>>();
      }
    } catch (e, stackTrace) {
      _logError('Error fetching recommended lessons for student: $studentCode',
          e, stackTrace);
      return [];
    }
  }

  // Get newest lessons (for dashboard)
  Future<List<Map<String, dynamic>>> getNewestLessons({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('''
            *,
            profiles!educator_id (
              id,
              first_name,
              last_name,
              avatar_url
            )
          ''')
          .eq('is_published', true)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e, stackTrace) {
      _logError('Error fetching newest lessons', e, stackTrace);
      return [];
    }
  }

  // Get popular lessons (most viewed)
  Future<List<Map<String, dynamic>>> getPopularLessons({int limit = 5}) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('''
            *,
            profiles!educator_id (
              id,
              first_name,
              last_name,
              avatar_url
            )
          ''')
          .eq('is_published', true)
          .order('views', ascending: false)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e, stackTrace) {
      _logError('Error fetching popular lessons', e, stackTrace);
      return [];
    }
  }

  // Mark lesson as completed using student code
  Future<void> markLessonCompleted(String studentCode, String lessonId) async {
    try {
      await _supabase.from('student_progress').upsert({
        'student_code': studentCode,
        'lesson_id': lessonId,
        'completed': true,
        'completed_at': DateTime.now().toIso8601String(),
        'progress_percentage': 100,
      });
      _logInfo('Lesson $lessonId marked as completed for student $studentCode');
    } catch (e, stackTrace) {
      _logError(
        'Error marking lesson $lessonId as completed for student $studentCode',
        e,
        stackTrace,
      );
    }
  }

  // Get lesson details by ID
  Future<Map<String, dynamic>> getLessonById(String lessonId) async {
    try {
      final response = await _supabase.from('lessons').select('''
            *,
            profiles!educator_id (
              id,
              first_name,
              last_name,
              avatar_url,
              bio
            )
          ''').eq('id', lessonId).single();

      return response;
    } catch (e, stackTrace) {
      _logError('Error fetching lesson details: $lessonId', e, stackTrace);
      return {};
    }
  }

  // Increment lesson views
  Future<void> incrementLessonViews(String lessonId) async {
    try {
      await _supabase.rpc('increment_views', params: {'lesson_id': lessonId});
      _logInfo('Views incremented for lesson: $lessonId');
    } catch (e, stackTrace) {
      _logError(
          'Failed to increment views for lesson: $lessonId', e, stackTrace);
    }
  }

  // Search lessons
  Future<List<Map<String, dynamic>>> searchLessons(String query) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('''
            *,
            profiles!educator_id (
              id,
              first_name,
              last_name,
              avatar_url
            )
          ''')
          .eq('is_published', true)
          .or('title.ilike.%$query%,description.ilike.%$query%,subject.ilike.%$query%')
          .order('created_at', ascending: false)
          .limit(20);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e, stackTrace) {
      _logError('Error searching lessons with query: $query', e, stackTrace);
      return [];
    }
  }

  // Get student's favorite lessons using student code
  Future<List<Map<String, dynamic>>> getFavoriteLessons(
      String studentCode) async {
    try {
      final response = await _supabase.from('student_favorites').select('''
            lessons:lesson_id (
              *,
              profiles!educator_id (
                id,
                first_name,
                last_name,
                avatar_url
              )
            )
          ''').eq('student_code', studentCode).eq('lessons.is_published', true);

      return response
          .map((item) => item['lessons'] as Map<String, dynamic>)
          .where((lesson) => lesson.isNotEmpty)
          .toList();
    } catch (e, stackTrace) {
      _logError('Error fetching favorite lessons for student: $studentCode', e,
          stackTrace);
      return [];
    }
  }

  // Toggle favorite status using student code
  Future<void> toggleFavorite(
      String studentCode, String lessonId, bool isCurrentlyFavorite) async {
    try {
      if (isCurrentlyFavorite) {
        await _supabase
            .from('student_favorites')
            .delete()
            .eq('student_code', studentCode)
            .eq('lesson_id', lessonId);
        _logInfo(
            'Lesson $lessonId removed from favorites for student $studentCode');
      } else {
        await _supabase.from('student_favorites').insert({
          'student_code': studentCode,
          'lesson_id': lessonId,
          'created_at': DateTime.now().toIso8601String(),
        });
        _logInfo(
            'Lesson $lessonId added to favorites for student $studentCode');
      }
    } catch (e, stackTrace) {
      _logError(
        'Error toggling favorite for lesson $lessonId, student $studentCode',
        e,
        stackTrace,
      );
    }
  }

  // Get lesson progress for a specific student and lesson using student code
  Future<Map<String, dynamic>?> getLessonProgress(
      String studentCode, String lessonId) async {
    try {
      final response = await _supabase
          .from('student_progress')
          .select('*')
          .eq('student_code', studentCode)
          .eq('lesson_id', lessonId)
          .maybeSingle();

      return response;
    } catch (e, stackTrace) {
      _logError(
        'Error fetching lesson progress for lesson $lessonId, student $studentCode',
        e,
        stackTrace,
      );
      return null;
    }
  }

  // Get unique subjects from lessons
  Future<List<String>> getAvailableSubjects() async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('subject')
          .eq('is_published', true);

      final subjects = response
          .map((item) => item['subject'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      return subjects;
    } catch (e, stackTrace) {
      _logError('Error fetching available subjects', e, stackTrace);
      return [];
    }
  }

  // Get unique subjects for a specific grade
  Future<List<String>> getSubjectsByGrade(String grade) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('subject')
          .eq('is_published', true)
          .eq('grade', grade);

      final subjects = response
          .map((item) => item['subject'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      return subjects;
    } catch (e, stackTrace) {
      _logError('Error fetching subjects for grade: $grade', e, stackTrace);
      return [];
    }
  }

  // Private logging methods
  void _logError(String message, dynamic error, StackTrace stackTrace) {
    developer.log(
      message,
      error: error,
      stackTrace: stackTrace,
      name: _loggerName,
      level: 1000, // SEVERE level
    );
  }

  void _logInfo(String message) {
    developer.log(
      message,
      name: _loggerName,
      level: 800, // INFO level
    );
  }

  // ignore: unused_element
  void _logWarning(String message) {
    developer.log(
      message,
      name: _loggerName,
      level: 900, // WARNING level
    );
  }
}
