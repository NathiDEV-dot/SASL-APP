// lib/core/services/homework_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // Submit homework
  Future<void> submitHomework({
    required String studentCode,
    required String assignmentId,
    required String submissionText,
    required List<String> attachmentUrls,
  }) async {
    try {
      await _supabase.from('homework_submissions').insert({
        'student_code': studentCode,
        'assignment_id': assignmentId,
        'submission_text': submissionText,
        'attachment_urls': attachmentUrls,
        'submitted_at': DateTime.now().toIso8601String(),
        'status': 'submitted',
      });
    } catch (e) {
      throw Exception('Failed to submit homework: $e');
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
}
