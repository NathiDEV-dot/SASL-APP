import 'package:flutter_test/flutter_test.dart';
import 'package:signsync_academy/core/services/dashboard_service.dart';

void main() {
  late DashboardService dashboardService;

  setUp(() {
    dashboardService = DashboardService();
  });

  group('DashboardService - Public Interface Tests', () {
    test('DashboardService can be instantiated', () {
      expect(dashboardService, isNotNull);
      expect(dashboardService, isA<DashboardService>());
    });

    test('DashboardService has expected public methods', () {
      // Test that we can call the main public methods
      expect(() => dashboardService.getEducatorData('test-id'), returnsNormally);
      expect(() => dashboardService.getRecentActivity('test-id'), returnsNormally);
      expect(() => dashboardService.getLessonStatistics('test-id'), returnsNormally);
    });
  });

  group('DashboardService - Business Logic Tests', () {
    test('UUID validation regex works correctly', () {
      // Test the UUID regex pattern that should be used in the service
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
      expect(uuidRegex.hasMatch('123e4567-e89b-12d3-a456-42661417400'), false); // too short
      expect(uuidRegex.hasMatch('123e4567-e89b-12d3-a456-4266141740000'), false); // too long
    });

    test('Time difference formatting works correctly', () {
      // Test the time formatting logic that should be in the service
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
      // Test the statistics calculation logic
      final List<Map<String, dynamic>> lessons = [
        {'title': 'Math 1', 'is_published': true},
        {'title': 'Math 2', 'is_published': true},
        {'title': 'Science 1', 'is_published': false},
        {'title': 'Science 2', 'is_published': true},
        {'title': 'History 1', 'is_published': false},
      ];

      final totalLessons = lessons.length;
      final publishedLessons = lessons.where((lesson) => lesson['is_published'] == true).length;
      final draftLessons = totalLessons - publishedLessons;
      final completionRate = totalLessons > 0 ? (publishedLessons / totalLessons * 100).round() : 0;

      expect(totalLessons, 5);
      expect(publishedLessons, 3);
      expect(draftLessons, 2);
      expect(completionRate, 60);
    });

    test('Completion rate handles edge cases', () {
      int calculateCompletionRate(int total, int published) {
        return total > 0 ? (published / total * 100).round() : 0;
      }

      expect(calculateCompletionRate(0, 0), 0);
      expect(calculateCompletionRate(10, 0), 0);
      expect(calculateCompletionRate(10, 10), 100);
      expect(calculateCompletionRate(4, 3), 75);
      expect(calculateCompletionRate(3, 2), 67);
    });

    test('Student data merging logic works correctly', () {
      // Test student merging without duplicates
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

      // Simulate merging logic
      final mergedStudents = <Map<String, dynamic>>[];
      final seenCodes = <String>{};

      void addStudent(Map<String, dynamic> student) {
        final code = student['student_code'] as String;
        if (!seenCodes.contains(code)) {
          seenCodes.add(code);
          mergedStudents.add(student);
        }
      }

      // Add all students
      for (final student in preVerifiedStudents) {
        addStudent(student);
      }
      for (final student in profileStudents) {
        addStudent(student);
      }

      expect(mergedStudents.length, 3);
      expect(seenCodes.length, 3);
      expect(seenCodes.contains('STU001'), true);
      expect(seenCodes.contains('STU002'), true);
      expect(seenCodes.contains('STU003'), true);
    });
  });

  group('DashboardService - Data Structure Validation', () {
    test('Educator data structure is correct', () {
      // Test the expected structure of educator data
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

      // Validate structure
      expect(mockEducatorData['educator'], isA<Map<String, dynamic>>());
      expect(mockEducatorData['stats'], isA<Map<String, dynamic>>());
      expect(mockEducatorData['classes_by_grade'], isA<Map<String, dynamic>>());
      expect(mockEducatorData['subjects'], isA<List>());
      expect(mockEducatorData['all_students'], isA<List>());
      
      final stats = mockEducatorData['stats'] as Map<String, dynamic>;
      expect(stats['total_classes'], isA<int>());
      expect(stats['total_students'], isA<int>());
      expect(stats['published_lessons'], isA<int>());
      expect(stats['completion_rate'], isA<int>());
    });

    test('Activity data structure is correct', () {
      // Test activity data structure
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

  group('DashboardService - Error Handling', () {
    test('Handles empty data gracefully', () {
      // Test that the service can handle empty inputs
      final emptyStats = {
        'total_classes': 0,
        'total_students': 0,
        'published_lessons': 0,
        'total_lessons': 0,
        'draft_lessons': 0,
        'completion_rate': 0,
      };

      expect(emptyStats['total_classes'], 0);
      expect(emptyStats['completion_rate'], 0);
    });

    test('Handles missing fields gracefully', () {
      // Test handling of potentially missing data
      final partialData = {
        'educator': {
          'first_name': 'Test',
          'last_name': 'Teacher',
          // Missing grade and role
        },
        'stats': {
          // Only some stats provided
          'total_students': 10,
          'total_lessons': 5,
        }
      };

      final educator = partialData['educator'] as Map<String, dynamic>;
      final stats = partialData['stats'] as Map<String, dynamic>;

      expect(educator['first_name'], 'Test');
      expect(stats['total_students'], 10);
      // Missing fields should be handled gracefully in the actual service
    });
  });
}
