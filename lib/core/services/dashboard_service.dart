import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardService {
  final SupabaseClient _client = Supabase.instance.client;

  // PUBLIC METHODS FOR TESTING - FULLY IMPLEMENTED
  bool isValidUuid(String uuid) {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(uuid);
  }

  String formatTimeDifference(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  Map<String, dynamic> processEducatorData(
    Map<String, dynamic> educator,
    List<dynamic> classes,
    List<dynamic> enrollments,
    List<dynamic> students,
    List<dynamic> lessons,
    int totalLessons,
    int publishedLessons,
    int draftLessons,
    String? educatorGrade,
  ) {
    // Create student map for easy lookup - using student_code as key
    final studentMap = <String, Map<String, dynamic>>{};
    for (final student in students) {
      final studentCode = student['student_code'] as String;
      studentMap[studentCode] = {
        'id': student['id'],
        'first_name': student['first_name'],
        'last_name': student['last_name'],
        'grade': student['grade'],
        'student_code': studentCode,
      };
    }

    // Process classes and enrollments (for when classes exist)
    final classesByGrade = <String, List<Map<String, dynamic>>>{};
    final allStudents = <Map<String, dynamic>>[];
    final seenStudents = <String>{};
    final subjects = <String>{};

    final uniqueStudents = <String>{};

    for (final classData in classes) {
      final grade = classData['grade'] as String? ?? 'Unknown Grade';
      final subject = classData['subject'] as String? ?? 'Unknown Subject';
      subjects.add(subject);

      // Get enrollments for this class
      final classEnrollments =
          enrollments.where((e) => e['class_id'] == classData['id']).toList();

      for (final enrollment in classEnrollments) {
        uniqueStudents.add(enrollment['student_code'] as String);
      }

      // Add to classes by grade
      if (!classesByGrade.containsKey(grade)) {
        classesByGrade[grade] = [];
      }

      classesByGrade[grade]!.add({
        'class_id': classData['id'],
        'subject': subject,
        'student_count': classEnrollments.length,
        'students': classEnrollments
            .map((e) {
              final studentCode = e['student_code'] as String;
              return studentMap[studentCode];
            })
            .where((s) => s != null)
            .toList(),
      });

      // Build unique student list from enrollments
      for (final enrollment in classEnrollments) {
        final studentCode = enrollment['student_code'] as String;
        if (!seenStudents.contains(studentCode) &&
            studentMap.containsKey(studentCode)) {
          seenStudents.add(studentCode);
          allStudents.add(studentMap[studentCode]!);
        }
      }
    }

    // If no students from enrollments, use all students from the educator's grade
    if (allStudents.isEmpty && students.isNotEmpty) {
      allStudents.addAll(students.map((student) => {
            'id': student['id'],
            'first_name': student['first_name'],
            'last_name': student['last_name'],
            'grade': student['grade'],
            'student_code': student['student_code'],
          }));
      uniqueStudents.addAll(students.map((s) => s['student_code'] as String));
    }

    // Sort students by name
    allStudents.sort((a, b) {
      final nameA = '${a['first_name']} ${a['last_name']}';
      final nameB = '${b['first_name']} ${b['last_name']}';
      return nameA.compareTo(nameB);
    });

    // Extract subjects from lessons (only this educator's lessons)
    final lessonSubjects = lessons
        .map<String>((lesson) => lesson['subject'] as String? ?? 'Unknown')
        .toSet()
        .toList();

    // Determine grades taught - use educator's grade if no classes exist
    final gradesTaught = classesByGrade.isNotEmpty
        ? classesByGrade.keys.toList()
        : (educatorGrade != null ? [educatorGrade] : []);

    return {
      'educator': educator,
      'stats': {
        'total_classes': classes.length,
        'total_students': uniqueStudents.length,
        'published_lessons': publishedLessons,
        'total_lessons': totalLessons,
        'draft_lessons': draftLessons,
        'completion_rate': totalLessons > 0
            ? (publishedLessons / totalLessons * 100).round()
            : 0,
      },
      'classes_by_grade': classesByGrade,
      'subjects': lessonSubjects,
      'grades_taught': gradesTaught,
      'all_students': allStudents,
      'recent_lessons': lessons.take(5).toList(),
      'debug_info': {
        'educator_id': educator['id'],
        'educator_grade': educatorGrade,
        'lessons_queried': lessons.length,
        'classes_queried': classes.length,
        'students_queried': students.length,
        'students_from_pre_verified': students.length,
        'students_from_enrollments': seenStudents.length,
        'lesson_educator_ids': lessons
            .map((l) => l['educator_id'])
            .toSet()
            .toList(),
      },
    };
  }

  Map<String, int> calculateLessonStatistics(List<dynamic> lessons) {
    final totalLessons = lessons.length;
    final publishedLessons = lessons.where((lesson) => lesson['is_published'] == true).length;
    final draftLessons = totalLessons - publishedLessons;

    return {
      'total': totalLessons,
      'published': publishedLessons,
      'drafts': draftLessons,
    };
  }

  List<Map<String, dynamic>> mergeStudents(
    List<dynamic> preVerifiedStudents,
    List<dynamic> profileStudents,
  ) {
    final merged = <Map<String, dynamic>>[];
    final seenStudentCodes = <String>{};

    // Add pre-verified students
    for (final student in preVerifiedStudents) {
      final studentCode = student['student_code'] as String;
      if (!seenStudentCodes.contains(studentCode)) {
        seenStudentCodes.add(studentCode);
        merged.add({
          'id': student['student_code'],
          'first_name': student['first_name'],
          'last_name': student['last_name'],
          'grade': student['grade'],
          'student_code': studentCode,
        });
      }
    }

    // Add profile students (avoiding duplicates)
    for (final student in profileStudents) {
      final studentCode = student['student_code'] as String?;
      if (studentCode != null && !seenStudentCodes.contains(studentCode)) {
        seenStudentCodes.add(studentCode);
        merged.add({
          'id': student['id'],
          'first_name': student['first_name'],
          'last_name': student['last_name'],
          'grade': student['grade'],
          'student_code': studentCode,
        });
      }
    }

    return merged;
  }

  // EXISTING MAIN METHODS
  Future<Map<String, dynamic>> getEducatorData(String educatorId) async {
    try {
      debugPrint('🔍 Loading educator data for ID: $educatorId');

      // Validate the educatorId format
      if (!isValidUuid(educatorId)) {
        debugPrint('❌ Invalid educator ID format: $educatorId');
        throw Exception('Invalid educator ID format');
      }

      // Get educator basic info
      final educatorResponse = await _client
          .from('profiles')
          .select('id, first_name, last_name, grade, role')
          .eq('id', educatorId)
          .single();

      debugPrint(
          '✅ Educator profile loaded: ${educatorResponse['first_name']} ${educatorResponse['last_name']}');
      debugPrint('📊 Educator grade: ${educatorResponse['grade']}');

      // Get ONLY this educator's lessons with proper filtering
      final lessonsResponse = await _client
          .from('lessons')
          .select(
              'id, title, is_published, created_at, subject, grade, educator_id')
          .eq('educator_id', educatorId)
          .order('created_at', ascending: false);

      debugPrint(
          '📚 Lessons found: ${lessonsResponse.length} for educator $educatorId');

      // Calculate lesson statistics
      final lessonStats = calculateLessonStatistics(lessonsResponse);
      final totalLessons = lessonStats['total']!;
      final publishedLessons = lessonStats['published']!;
      final draftLessons = lessonStats['drafts']!;

      debugPrint(
          '📊 Lesson stats - Total: $totalLessons, Published: $publishedLessons, Drafts: $draftLessons');

      // Get educator's classes (if classes system exists)
      List<dynamic> classesResponse = [];
      List<dynamic> enrollmentsResponse = [];

      try {
        classesResponse = await _client
            .from('classes')
            .select('id, subject, grade, educator_id')
            .eq('educator_id', educatorId);

        debugPrint('🏫 Classes found: ${classesResponse.length}');

        // Get enrollments if classes exist
        final classIds =
            classesResponse.map<String>((c) => c['id'] as String).toList();
        if (classIds.isNotEmpty) {
          enrollmentsResponse = await _client
              .from('class_enrollments')
              .select('class_id, student_code')
              .inFilter('class_id', classIds);
          debugPrint('🎓 Enrollments found: ${enrollmentsResponse.length}');
        }
      } catch (e) {
        debugPrint('⚠️ Classes data not available: $e');
        // Continue without classes data
      }

      // Get students from pre_verified_users table
      List<dynamic> studentsResponse = [];
      final educatorGrade = educatorResponse['grade'] as String?;

      if (educatorGrade != null && educatorGrade.isNotEmpty) {
        debugPrint(
            '🎯 Getting students for grade: $educatorGrade from pre_verified_users');

        try {
          // Get students from pre_verified_users table
          final preVerifiedStudents = await _client
              .from('pre_verified_users')
              .select('student_code, first_name, last_name, grade, school_name')
              .eq('role', 'student')
              .eq('grade', educatorGrade)
              .order('first_name');

          debugPrint(
              '👥 Students found in pre_verified_users: ${preVerifiedStudents.length}');

          // Also check profiles table for any students that might exist there
          try {
            final profilesStudents = await _client
                .from('profiles')
                .select('id, first_name, last_name, grade, student_code')
                .eq('role', 'student')
                .eq('grade', educatorGrade)
                .order('first_name');

            debugPrint(
                '👥 Students found in profiles table: ${profilesStudents.length}');

            // Merge students from both sources
            studentsResponse = mergeStudents(preVerifiedStudents, profilesStudents);
          } catch (e) {
            debugPrint('⚠️ Could not query profiles table for students: $e');
            studentsResponse = preVerifiedStudents.map((student) => {
              'id': student['student_code'],
              'first_name': student['first_name'],
              'last_name': student['last_name'],
              'grade': student['grade'],
              'student_code': student['student_code'],
            }).toList();
          }
        } catch (e) {
          debugPrint('❌ Error querying pre_verified_users: $e');
          studentsResponse = [];
        }

        debugPrint(
            '🎯 Total students for $educatorGrade: ${studentsResponse.length}');
      } else {
        debugPrint('⚠️ No grade specified for educator');
      }

      // Process the data
      return processEducatorData(
        educatorResponse,
        classesResponse,
        enrollmentsResponse,
        studentsResponse,
        lessonsResponse,
        totalLessons,
        publishedLessons,
        draftLessons,
        educatorGrade,
      );
    } catch (e) {
      debugPrint('❌ Error getting educator data: $e');
      rethrow;
    }
  }

  // Get recent activity specifically for this educator
  Future<List<Map<String, dynamic>>> getRecentActivity(
      String educatorId) async {
    try {
      final activities = <Map<String, dynamic>>[];

      // Get recent lesson creations - FIXED: Filter by educator_id
      final recentLessons = await _client
          .from('lessons')
          .select('title, created_at, is_published, subject, educator_id')
          .eq('educator_id', educatorId)
          .order('created_at', ascending: false)
          .limit(5);

      debugPrint(
          '📋 Recent lessons for educator $educatorId: ${recentLessons.length}');

      for (final lesson in recentLessons) {
        activities.add({
          'type': 'lesson',
          'title':
              '${lesson['is_published'] == true ? 'Published' : 'Created'} lesson: ${lesson['title']}',
          'subtitle': 'Subject: ${lesson['subject']}',
          'time': formatTimeDifference(DateTime.parse(lesson['created_at'])),
          'icon': Icons.video_library_rounded,
          'color': const Color(0xFF4361EE),
          'lesson_data': lesson,
        });
      }

      // If no lessons, add a welcome message
      if (activities.isEmpty) {
        activities.add({
          'type': 'welcome',
          'title': 'Welcome to your dashboard!',
          'subtitle': 'Create your first lesson to get started',
          'time': 'Just now',
          'icon': Icons.emoji_events_rounded,
          'color': const Color(0xFFF59E0B),
        });
      }

      return activities;
    } catch (e) {
      debugPrint('❌ Error getting recent activity: $e');
      return [];
    }
  }

  // Get lesson statistics for this educator
  Future<Map<String, int>> getLessonStatistics(String educatorId) async {
    try {
      // Get all lessons for this educator
      final lessons = await _client
          .from('lessons')
          .select('is_published, educator_id')
          .eq('educator_id', educatorId);

      return calculateLessonStatistics(lessons);
    } catch (e) {
      debugPrint('❌ Error getting lesson statistics: $e');
      return {'total': 0, 'published': 0, 'drafts': 0};
    }
  }
}
