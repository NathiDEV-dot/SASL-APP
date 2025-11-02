// services/submission_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SubmissionService {
  final SupabaseClient _supabase;

  SubmissionService() : _supabase = Supabase.instance.client;

  // Get all submissions for the current educator
  Future<List<Map<String, dynamic>>> getEducatorSubmissions() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('submissions')
          .select('''
            *,
            assignments:assignment_id (
              title,
              description,
              due_date,
              subject,
              grade_level
            ),
            students:student_id (
              first_name,
              last_name,
              student_code,
              grade
            ),
            lessons:lesson_id (
              title,
              subject
            )
          ''')
          .eq('educator_id', user.id)
          .order('submitted_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch submissions: $e');
    }
  }

  // Get submissions filtered by status
  Future<List<Map<String, dynamic>>> getSubmissionsByStatus(
      String status) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('submissions')
          .select('''
            *,
            assignments:assignment_id (
              title,
              description,
              due_date,
              subject,
              grade_level
            ),
            students:student_id (
              first_name,
              last_name,
              student_code,
              grade
            )
          ''')
          .eq('educator_id', user.id)
          .eq('status', status)
          .order('submitted_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch submissions: $e');
    }
  }

  // Grade a submission
  Future<void> gradeSubmission({
    required String submissionId,
    required String grade,
    required String feedback,
    required int rating,
  }) async {
    try {
      await _supabase.from('submissions').update({
        'grade': grade,
        'feedback': feedback,
        'rating': rating,
        'status': 'graded',
        'graded_at': DateTime.now().toIso8601String(),
      }).eq('id', submissionId);
    } catch (e) {
      throw Exception('Failed to grade submission: $e');
    }
  }

  // Update submission status
  Future<void> updateSubmissionStatus(
      String submissionId, String status) async {
    try {
      await _supabase.from('submissions').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', submissionId);
    } catch (e) {
      throw Exception('Failed to update submission status: $e');
    }
  }

  // Get submission statistics
  Future<Map<String, dynamic>> getSubmissionStats() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get total submissions count
      final totalResponse = await _supabase
          .from('submissions')
          .select('id')
          .eq('educator_id', user.id)
          .count(CountOption.exact);

      // Get pending submissions count
      final pendingResponse = await _supabase
          .from('submissions')
          .select('id')
          .eq('educator_id', user.id)
          .eq('status', 'pending')
          .count(CountOption.exact);

      // Get overdue submissions count
      final overdueResponse = await _supabase
          .from('submissions')
          .select('id')
          .eq('educator_id', user.id)
          .eq('status', 'pending')
          .lt('due_date', DateTime.now().toIso8601String())
          .count(CountOption.exact);

      return {
        'total': totalResponse.count,
        'pending': pendingResponse.count,
        'overdue': overdueResponse.count,
        'graded': totalResponse.count - pendingResponse.count,
      };
    } catch (e) {
      throw Exception('Failed to fetch submission stats: $e');
    }
  }

  // Search submissions
  Future<List<Map<String, dynamic>>> searchSubmissions(String query) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Search in student names and assignment titles
      final response = await _supabase
          .from('submissions')
          .select('''
            *,
            assignments:assignment_id (
              title,
              description,
              due_date,
              subject
            ),
            students:student_id (
              first_name,
              last_name,
              student_code
            )
          ''')
          .eq('educator_id', user.id)
          .or('students.first_name.ilike.%$query%,students.last_name.ilike.%$query%,assignments.title.ilike.%$query%')
          .order('submitted_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to search submissions: $e');
    }
  }
}
