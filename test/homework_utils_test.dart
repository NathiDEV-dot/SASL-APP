import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  group('Homework Utility Functions', () {
    test('Date formatting function', () {
      String formatDate(DateTime date) {
        return '${date.day}/${date.month}/${date.year}';
      }
      
      expect(formatDate(DateTime(2024, 12, 25)), '25/12/2024');
      expect(formatDate(DateTime(2024, 1, 5)), '5/1/2024');
    });

    test('Status color mapping', () {
      Color getStatusColor(String status) {
        switch (status) {
          case 'graded':
            return Colors.green;
          case 'submitted':
            return Colors.blue;
          case 'late':
            return Colors.orange;
          default:
            return Colors.grey;
        }
      }
      
      expect(getStatusColor('graded'), Colors.green);
      expect(getStatusColor('submitted'), Colors.blue);
      expect(getStatusColor('late'), Colors.orange);
      expect(getStatusColor('pending'), Colors.grey);
    });

    test('Assignment overdue detection', () {
      bool isAssignmentOverdue(DateTime dueDate) {
        return dueDate.isBefore(DateTime.now());
      }
      
      expect(isAssignmentOverdue(DateTime(2020, 1, 1)), true);
      expect(isAssignmentOverdue(DateTime(2030, 1, 1)), false);
    });

    test('Assignment submission check', () {
      bool isAssignmentSubmitted(
        String assignmentId, 
        List<Map<String, dynamic>> submissions
      ) {
        return submissions.any((sub) => sub['assignment_id'] == assignmentId);
      }
      
      final submissions = [
        {'assignment_id': '1', 'submission_text': 'Test 1'},
        {'assignment_id': '2', 'submission_text': 'Test 2'},
      ];
      
      expect(isAssignmentSubmitted('1', submissions), true);
      expect(isAssignmentSubmitted('3', submissions), false);
    });
  });
}