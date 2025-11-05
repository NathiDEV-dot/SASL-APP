import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Assignment Sorting and Filtering', () {
    test('Sorts assignments by due date', () {
      final assignments = [
        {'id': '1', 'due_date': DateTime(2024, 1, 20)},
        {'id': '2', 'due_date': DateTime(2024, 1, 10)},
        {'id': '3', 'due_date': DateTime(2024, 1, 15)},
      ];

      assignments.sort((a, b) {
        final dateA = a['due_date'] as DateTime;
        final dateB = b['due_date'] as DateTime;
        return dateA.compareTo(dateB);
      });

      expect(assignments[0]['id'], '2'); // Earliest
      expect(assignments[1]['id'], '3');
      expect(assignments[2]['id'], '1'); // Latest
    });

    test('Filters submitted assignments', () {
      final submissions = [
        {'assignment_id': '1', 'status': 'submitted'},
        {'assignment_id': '2', 'status': 'graded'},
        {'assignment_id': '3', 'status': 'pending'},
      ];

      final submitted = submissions.where((sub) => 
        sub['status'] == 'submitted' || sub['status'] == 'graded'
      ).toList();

      expect(submitted.length, 2);
      expect(submitted[0]['assignment_id'], '1');
      expect(submitted[1]['assignment_id'], '2');
    });

    test('Groups assignments by status', () {
      final assignments = [
        {'id': '1', 'status': 'pending'},
        {'id': '2', 'status': 'submitted'},
        {'id': '3', 'status': 'pending'},
        {'id': '4', 'status': 'graded'},
      ];

      final pending = assignments.where((a) => a['status'] == 'pending');
      final submitted = assignments.where((a) => 
        a['status'] == 'submitted' || a['status'] == 'graded'
      );

      expect(pending.length, 2);
      expect(submitted.length, 2);
    });
  });
}