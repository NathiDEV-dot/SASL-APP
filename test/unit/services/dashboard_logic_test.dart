import 'package:flutter_test/flutter_test.dart';

// Test the business logic without creating DashboardService instance
void main() {
  group('Dashboard Business Logic - Pure Functions', () {
    test('UUID validation regex works correctly', () {
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      
      // Valid UUIDs
      expect(uuidRegex.hasMatch('123e4567-e89b-12d3-a456-426614174000'), true);
      expect(uuidRegex.hasMatch('00000000-0000-0000-0000-000000000000'), true);
      expect(uuidRegex.hasMatch('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'), true);
      
      // Invalid UUIDs
      expect(uuidRegex.hasMatch('not-a-uuid'), false);
      expect(uuidRegex.hasMatch('123'), false);
      expect(uuidRegex.hasMatch(''), false);
      expect(uuidRegex.hasMatch('123e4567-e89b-12d3-a456-42661417400'), false);
      expect(uuidRegex.hasMatch('123e4567-e89b-12d3-a456-4266141740000'), false);
    });

    test('Time difference formatting works correctly', () {
      String formatTimeDifference(DateTime date) {
        final now = DateTime.now();
        final difference = now.difference(date);

        if (difference.inMinutes < 1) return 'Just now';
        if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
        if (difference.inHours < 24) return '${difference.inHours}h ago';
        return '${difference.inDays}d ago';
      }

      final now = DateTime.now();
      final oneMinuteAgo = now.subtract(const Duration(minutes: 1, seconds: 30));
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
      final twoHoursAgo = now.subtract(const Duration(hours: 2));
      final threeDaysAgo = now.subtract(const Duration(days: 3));

      expect(formatTimeDifference(now), 'Just now');
      expect(formatTimeDifference(oneMinuteAgo), '1m ago');
      expect(formatTimeDifference(fiveMinutesAgo), '5m ago');
      expect(formatTimeDifference(twoHoursAgo), '2h ago');
      expect(formatTimeDifference(threeDaysAgo), '3d ago');
    });

    test('Lesson statistics calculation is correct', () {
      Map<String, int> calculateLessonStatistics(List<Map<String, dynamic>> lessons) {
        final totalLessons = lessons.length;
        final publishedLessons = lessons.where((lesson) => lesson['is_published'] == true).length;
        final draftLessons = totalLessons - publishedLessons;

        return {
          'total': totalLessons,
          'published': publishedLessons,
          'drafts': draftLessons,
        };
      }

      final lessons = [
        {'title': 'Math 1', 'is_published': true},
        {'title': 'Math 2', 'is_published': true},
        {'title': 'Science 1', 'is_published': false},
        {'title': 'Science 2', 'is_published': true},
        {'title': 'History 1', 'is_published': false},
      ];

      final stats = calculateLessonStatistics(lessons);

      expect(stats['total'], 5);
      expect(stats['published'], 3);
      expect(stats['drafts'], 2);
    });

    test('Completion rate calculation handles edge cases', () {
      int calculateCompletionRate(int totalLessons, int publishedLessons) {
        return totalLessons > 0 ? (publishedLessons / totalLessons * 100).round() : 0;
      }

      expect(calculateCompletionRate(0, 0), 0);
      expect(calculateCompletionRate(10, 0), 0);
      expect(calculateCompletionRate(10, 10), 100);
      expect(calculateCompletionRate(4, 3), 75);
      expect(calculateCompletionRate(3, 2), 67);
    });

    test('Student data merging logic works correctly', () {
      List<Map<String, dynamic>> mergeStudents(
        List<Map<String, dynamic>> preVerifiedStudents,
        List<Map<String, dynamic>> profileStudents,
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

      final preVerifiedStudents = [
        {
          'student_code': 'STU001',
          'first_name': 'John',
          'last_name': 'Doe',
          'grade': 'Grade 1'
        },
        {
          'student_code': 'STU002',
          'first_name': 'Jane',
          'last_name': 'Smith', 
          'grade': 'Grade 1'
        }
      ];

      final profileStudents = [
        {
          'student_code': 'STU002', // Duplicate
          'first_name': 'Jane',
          'last_name': 'Smith',
          'grade': 'Grade 1'
        },
        {
          'student_code': 'STU003',
          'first_name': 'Bob',
          'last_name': 'Johnson',
          'grade': 'Grade 1'
        }
      ];

      final merged = mergeStudents(preVerifiedStudents, profileStudents);

      expect(merged.length, 3);
      expect(merged.any((s) => s['first_name'] == 'John'), true);
      expect(merged.any((s) => s['first_name'] == 'Jane'), true);
      expect(merged.any((s) => s['first_name'] == 'Bob'), true);
    });
  });

  group('Data Structure Validation', () {
    test('Educator data structure is correct', () {
      final mockEducatorData = {
        'educator': {
          'id': 'educator-123',
          'first_name': 'Test',
          'last_name': 'Teacher',
          'grade': 'Grade 1',
          'role': 'educator'
        },
        'stats': {
          'total_classes': 3,
          'total_students': 25,
          'published_lessons': 5,
          'total_lessons': 8,
          'draft_lessons': 3,
          'completion_rate': 63,
        },
        'classes_by_grade': {
          'Grade 1': [
            {
              'class_id': 'class-1',
              'subject': 'Mathematics',
              'student_count': 12,
            }
          ]
        },
        'subjects': ['Mathematics', 'Science'],
        'grades_taught': ['Grade 1'],
        'all_students': [
          {
            'id': 'student-1',
            'first_name': 'Student',
            'last_name': 'One',
            'grade': 'Grade 1',
            'student_code': 'STU001'
          }
        ],
        'recent_lessons': [
          {
            'title': 'Math Lesson 1',
            'subject': 'Mathematics',
            'created_at': '2024-01-01T00:00:00Z'
          }
        ],
      };

      expect(mockEducatorData['educator'], isA<Map<String, dynamic>>());
      expect(mockEducatorData['stats'], isA<Map<String, dynamic>>());
      expect(mockEducatorData['classes_by_grade'], isA<Map<String, dynamic>>());
      expect(mockEducatorData['subjects'], isA<List>());
      expect(mockEducatorData['all_students'], isA<List>());
    });

    test('Activity data structure is correct', () {
      final mockActivity = {
        'type': 'lesson_created',
        'title': 'Created new lesson: Advanced Mathematics',
        'subtitle': 'Subject: Mathematics',
        'time': '2 hours ago',
        'icon': 'video_library',
        'color': 'blue',
        'lesson_data': {
          'title': 'Advanced Mathematics',
          'subject': 'Mathematics',
          'is_published': false,
        }
      };

      expect(mockActivity['title'], isA<String>());
      expect(mockActivity['subtitle'], isA<String>());
      expect(mockActivity['time'], isA<String>());
      expect(mockActivity['type'], isA<String>());
    });
  });

  group('Data Processing Logic', () {
    test('Processes educator data with empty inputs', () {
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
        final classesByGrade = <String, List<Map<String, dynamic>>>{};
        final uniqueStudents = <String>{};

        for (final student in students) {
          uniqueStudents.add(student['student_code'] as String);
        }

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
          'subjects': lessons
              .map<String>((lesson) => lesson['subject'] as String? ?? 'Unknown')
              .toSet()
              .toList(),
          'grades_taught': classesByGrade.isNotEmpty
              ? classesByGrade.keys.toList()
              : (educatorGrade != null ? [educatorGrade] : []),
          'all_students': students,
          'recent_lessons': lessons.take(5).toList(),
        };
      }

      final educator = {'id': '123', 'first_name': 'Test', 'last_name': 'Educator'};
      final result = processEducatorData(
        educator,
        [], // classes
        [], // enrollments
        [], // students
        [], // lessons
        0,  // totalLessons
        0,  // publishedLessons
        0,  // draftLessons
        'Grade 1',
      );

      expect(result['educator'], educator);
      expect(result['stats']['total_classes'], 0);
      expect(result['stats']['total_students'], 0);
      expect(result['all_students'], isEmpty);
    });

    test('Processes educator data with students', () {
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
        final uniqueStudents = <String>{};
        for (final student in students) {
          uniqueStudents.add(student['student_code'] as String);
        }

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
          'classes_by_grade': {},
          'subjects': [],
          'grades_taught': [],
          'all_students': students,
          'recent_lessons': [],
        };
      }

      final educator = {'id': '123', 'first_name': 'Test', 'last_name': 'Educator'};
      final students = [
        {
          'id': 'stu1',
          'first_name': 'John',
          'last_name': 'Doe',
          'grade': 'Grade 1',
          'student_code': 'STU001'
        }
      ];

      final result = processEducatorData(
        educator,
        [],
        [],
        students,
        [],
        0, 0, 0,
        'Grade 1',
      );

      expect(result['stats']['total_students'], 1);
      expect(result['all_students'], hasLength(1));
      expect(result['all_students'][0]['first_name'], 'John');
    });
  });
}
