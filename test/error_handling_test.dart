import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Error Handling and Edge Cases', () {
    test('Handles malformed date strings', () {
      String safeFormatDate(String dateString) {
        try {
          final date = DateTime.parse(dateString);
          return '${date.day}/${date.month}/${date.year}';
        } catch (e) {
          return 'Invalid Date';
        }
      }
      
      expect(safeFormatDate('2024-01-15'), '15/1/2024');
      expect(safeFormatDate('invalid-date'), 'Invalid Date');
      expect(safeFormatDate(''), 'Invalid Date');
    });

    test('Handles missing student data gracefully', () {
      final studentWithMissingData = {
        'first_name': null,
        'last_name': null,
        'grade': null,
      };

      String getStudentDisplayName(Map<String, dynamic> student) {
        final firstName = student['first_name'] ?? 'Unknown';
        final lastName = student['last_name'] ?? 'Student';
        return '$firstName $lastName';
      }

      expect(getStudentDisplayName(studentWithMissingData), 'Unknown Student');
    });

    test('Validates assignment data completeness', () {
      bool isValidAssignment(Map<String, dynamic> assignment) {
        return assignment['id'] != null && 
               assignment['title'] != null &&
               assignment['due_date'] != null;
      }

      final validAssignment = {
        'id': '1', 
        'title': 'Math',
        'due_date': '2024-01-15'
      };
      final invalidAssignment = {
        'id': '1',
        'title': null,
        'due_date': '2024-01-15'
      };

      expect(isValidAssignment(validAssignment), true);
      expect(isValidAssignment(invalidAssignment), false);
    });
  });
}