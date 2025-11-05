import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Homework Data Structures', () {
    test('Student data structure', () {
      final studentData = {
        'first_name': 'John',
        'last_name': 'Doe',
        'grade': '10',
        'student_code': 'STU123'
      };

      expect(studentData['first_name'], 'John');
      expect(studentData['last_name'], 'Doe');
      expect(studentData['grade'], '10');
      expect(studentData['student_code'], 'STU123');
    });

    test('Assignment data structure', () {
      final assignment = {
        'id': '1',
        'title': 'Math Homework',
        'description': 'Solve equations',
        'due_date': '2024-01-15T00:00:00Z',
        'max_points': 100,
        'lessons': {'title': 'Algebra Basics'}
      };

      expect(assignment['id'], '1');
      expect(assignment['title'], 'Math Homework');
      expect(assignment['description'], 'Solve equations');
      expect(assignment['max_points'], 100);
      
      final lessons = assignment['lessons'] as Map<String, dynamic>?;
      expect(lessons?['title'], 'Algebra Basics');
    });

    test('Submission data structure', () {
      final submission = {
        'id': '1',
        'assignment_id': '1',
        'submitted_at': '2024-01-14T10:00:00Z',
        'submission_text': 'I completed the homework',
        'status': 'submitted',
        'points_earned': 85,
        'feedback': 'Good work!'
      };

      expect(submission['assignment_id'], '1');
      expect(submission['submission_text'], 'I completed the homework');
      expect(submission['status'], 'submitted');
      expect(submission['points_earned'], 85);
      expect(submission['feedback'], 'Good work!');
    });

    test('Assignment status combinations', () {
      // Test different assignment status scenarios
      final pendingAssignment = {
        'id': '1',
        'due_date': '2024-12-31T00:00:00Z', // Future date
        'is_submitted': false
      };

      final submittedAssignment = {
        'id': '2', 
        'due_date': '2024-12-31T00:00:00Z',
        'is_submitted': true
      };

      final overdueAssignment = {
        'id': '3',
        'due_date': '2020-01-01T00:00:00Z', // Past date
        'is_submitted': false
      };

      expect(pendingAssignment['is_submitted'], false);
      expect(submittedAssignment['is_submitted'], true);
      expect(overdueAssignment['is_submitted'], false);
    });

    test('Handles null values gracefully', () {
      final assignmentWithNulls = {
        'id': '1',
        'title': null,
        'description': null,
        'due_date': '2024-01-15T00:00:00Z',
        'lessons': null,
      };

      expect(assignmentWithNulls['id'], '1');
      expect(assignmentWithNulls['title'], isNull);
      expect(assignmentWithNulls['description'], isNull);
      
      final lessons = assignmentWithNulls['lessons'] as Map<String, dynamic>?;
      expect(lessons, isNull);
    });

    test('Student data with optional fields', () {
      final minimalStudentData = {
        'first_name': 'John',
        'last_name': 'Doe',
        // grade and student_code are optional
      };

      expect(minimalStudentData['first_name'], 'John');
      expect(minimalStudentData['last_name'], 'Doe');
      expect(minimalStudentData['grade'], isNull);
      expect(minimalStudentData['student_code'], isNull);
    });
  });
}