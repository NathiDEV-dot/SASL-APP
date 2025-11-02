// ignore: unused_import
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveSessionData {
  final String id;
  final String title;
  final String description;
  final String educatorId;
  final String educatorName;
  final DateTime scheduledTime;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationMinutes;
  final String status; // scheduled, live, ended, cancelled
  final String? meetingUrl;
  final String? recordingUrl;
  final int participantCount;
  final String subject;
  final String grade;
  final DateTime createdAt;
  final DateTime updatedAt;

  LiveSessionData({
    required this.id,
    required this.title,
    required this.description,
    required this.educatorId,
    required this.educatorName,
    required this.scheduledTime,
    this.startedAt,
    this.endedAt,
    required this.durationMinutes,
    required this.status,
    this.meetingUrl,
    this.recordingUrl,
    required this.participantCount,
    required this.subject,
    required this.grade,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LiveSessionData.fromJson(Map<String, dynamic> json) {
    return LiveSessionData(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      educatorId: json['educator_id'] as String,
      educatorName: json['educator_name'] as String? ?? 'Unknown Educator',
      scheduledTime: DateTime.parse(json['scheduled_time'] as String),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      durationMinutes: json['duration_minutes'] as int? ?? 60,
      status: json['status'] as String? ?? 'scheduled',
      meetingUrl: json['meeting_url'] as String?,
      recordingUrl: json['recording_url'] as String?,
      participantCount: json['participant_count'] as int? ?? 0,
      subject: json['subject'] as String? ?? 'General',
      grade: json['grade'] as String? ?? 'All Grades',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'educator_id': educatorId,
      'educator_name': educatorName,
      'scheduled_time': scheduledTime.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_minutes': durationMinutes,
      'status': status,
      'meeting_url': meetingUrl,
      'recording_url': recordingUrl,
      'participant_count': participantCount,
      'subject': subject,
      'grade': grade,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isUpcoming =>
      status == 'scheduled' && scheduledTime.isAfter(DateTime.now());
  bool get isLive => status == 'live';
  bool get isEnded => status == 'ended';
  bool get isCancelled => status == 'cancelled';
  bool get canJoin =>
      isLive ||
      (isUpcoming && scheduledTime.difference(DateTime.now()).inMinutes <= 5);
}

class LiveSessionsService {
  final SupabaseClient _client = Supabase.instance.client;

  // Create a new live session
  Future<LiveSessionData> createLiveSession({
    required String title,
    required String description,
    required DateTime scheduledTime,
    required int durationMinutes,
    required String subject,
    required String grade,
    required String educatorId,
    String? educatorName,
  }) async {
    try {
      // First, get educator name if not provided
      String finalEducatorName =
          educatorName ?? await _getEducatorName(educatorId);

      // Generate a unique meeting URL (in real implementation, this would be from a video conferencing service)
      final meetingUrl = _generateMeetingUrl();

      final response = await _client
          .from('live_sessions')
          .insert({
            'title': title,
            'description': description,
            'scheduled_time': scheduledTime.toIso8601String(),
            'duration_minutes': durationMinutes,
            'subject': subject,
            'grade': grade,
            'educator_id': educatorId,
            'educator_name': finalEducatorName,
            'status': 'scheduled',
            'meeting_url': meetingUrl,
            'participant_count': 0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('*')
          .single();

      return LiveSessionData.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create live session: $e');
    }
  }

  // Get educator's name from profiles table
  Future<String> _getEducatorName(String educatorId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('first_name, last_name')
          .eq('id', educatorId)
          .single();

      final firstName = response['first_name'] as String? ?? '';
      final lastName = response['last_name'] as String? ?? '';
      return '$firstName $lastName'.trim();
    } catch (e) {
      return 'Educator';
    }
  }

  // Generate a unique meeting URL (placeholder - integrate with actual video service)
  String _generateMeetingUrl() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    return 'https://meet.signsync.academy/session-$timestamp-$random';
  }

  // Get all live sessions for an educator
  Future<List<LiveSessionData>> getEducatorSessions(String educatorId) async {
    try {
      final response = await _client
          .from('live_sessions')
          .select('*')
          .eq('educator_id', educatorId)
          .order('scheduled_time', ascending: false);

      return response
          .map<LiveSessionData>((json) => LiveSessionData.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch live sessions: $e');
    }
  }

  // Get upcoming live sessions for students (based on their grade)
  Future<List<LiveSessionData>> getUpcomingSessionsForGrade(
      String grade) async {
    try {
      final response = await _client
          .from('live_sessions')
          .select('*')
          .eq('grade', grade)
          .eq('status', 'scheduled')
          .gte('scheduled_time', DateTime.now().toIso8601String())
          .order('scheduled_time', ascending: true);

      return response
          .map<LiveSessionData>((json) => LiveSessionData.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch upcoming sessions: $e');
    }
  }

  // Start a live session
  Future<void> startLiveSession(String sessionId) async {
    try {
      await _client.from('live_sessions').update({
        'status': 'live',
        'started_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
    } catch (e) {
      throw Exception('Failed to start live session: $e');
    }
  }

  // End a live session
  Future<void> endLiveSession(String sessionId, {String? recordingUrl}) async {
    try {
      await _client.from('live_sessions').update({
        'status': 'ended',
        'ended_at': DateTime.now().toIso8601String(),
        'recording_url': recordingUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
    } catch (e) {
      throw Exception('Failed to end live session: $e');
    }
  }

  // Cancel a live session
  Future<void> cancelLiveSession(String sessionId) async {
    try {
      await _client.from('live_sessions').update({
        'status': 'cancelled',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
    } catch (e) {
      throw Exception('Failed to cancel live session: $e');
    }
  }

  // Update participant count
  Future<void> updateParticipantCount(String sessionId, int count) async {
    try {
      await _client.from('live_sessions').update({
        'participant_count': count,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
    } catch (e) {
      throw Exception('Failed to update participant count: $e');
    }
  }

  // Get live session by ID
  Future<LiveSessionData> getSessionById(String sessionId) async {
    try {
      final response = await _client
          .from('live_sessions')
          .select('*')
          .eq('id', sessionId)
          .single();

      return LiveSessionData.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch session: $e');
    }
  }

  // Edit live session details
  Future<LiveSessionData> updateLiveSession({
    required String sessionId,
    String? title,
    String? description,
    DateTime? scheduledTime,
    int? durationMinutes,
    String? subject,
    String? grade,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (scheduledTime != null) {
        updates['scheduled_time'] = scheduledTime.toIso8601String();
      }
      if (durationMinutes != null) {
        updates['duration_minutes'] = durationMinutes;
      }
      if (subject != null) updates['subject'] = subject;
      if (grade != null) updates['grade'] = grade;

      final response = await _client
          .from('live_sessions')
          .update(updates)
          .eq('id', sessionId)
          .select('*')
          .single();

      return LiveSessionData.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update live session: $e');
    }
  }

  // Get session statistics for educator
  Future<Map<String, dynamic>> getSessionStatistics(String educatorId) async {
    try {
      final response = await _client
          .from('live_sessions')
          .select('status, participant_count')
          .eq('educator_id', educatorId);

      int totalSessions = response.length;
      int upcomingSessions =
          response.where((s) => s['status'] == 'scheduled').length;
      int completedSessions =
          response.where((s) => s['status'] == 'ended').length;
      int liveSessions = response.where((s) => s['status'] == 'live').length;

      int totalParticipants = response.fold(0, (sum, session) {
        return sum + (session['participant_count'] as int? ?? 0);
      });

      return {
        'total_sessions': totalSessions,
        'upcoming_sessions': upcomingSessions,
        'completed_sessions': completedSessions,
        'live_sessions': liveSessions,
        'total_participants': totalParticipants,
        'average_participants':
            totalSessions > 0 ? totalParticipants ~/ totalSessions : 0,
      };
    } catch (e) {
      throw Exception('Failed to fetch session statistics: $e');
    }
  }

  // Get students enrolled in educator's classes (for invitation)
  Future<List<Map<String, dynamic>>> getStudentsForInvitation(
      String educatorId) async {
    try {
      // Get educator's grade
      final educatorResponse = await _client
          .from('profiles')
          .select('grade')
          .eq('id', educatorId)
          .single();

      final educatorGrade = educatorResponse['grade'] as String?;

      if (educatorGrade == null) {
        return [];
      }

      // Get students from pre_verified_users for this grade
      final studentsResponse = await _client
          .from('pre_verified_users')
          .select('student_code, first_name, last_name, grade')
          .eq('role', 'student')
          .eq('grade', educatorGrade)
          .order('first_name');

      return studentsResponse.map((student) {
        return {
          'id': student['student_code'],
          'name': '${student['first_name']} ${student['last_name']}',
          'grade': student['grade'],
          'student_code': student['student_code'],
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch students: $e');
    }
  }
}
