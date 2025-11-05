import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Assignment Status Logic', () {
    test('Determines correct assignment status', () {
      String getAssignmentStatus({
        required bool isSubmitted,
        required DateTime dueDate,
        required DateTime currentDate,
      }) {
        if (isSubmitted) return 'Submitted';
        if (currentDate.isAfter(dueDate)) return 'Overdue';
        return 'Pending';
      }

      final now = DateTime(2024, 1, 10);
      final futureDueDate = DateTime(2024, 1, 15);
      final pastDueDate = DateTime(2024, 1, 5);

      expect(
        getAssignmentStatus(
          isSubmitted: false,
          dueDate: futureDueDate,
          currentDate: now,
        ),
        'Pending',
      );

      expect(
        getAssignmentStatus(
          isSubmitted: false,
          dueDate: pastDueDate,
          currentDate: now,
        ),
        'Overdue',
      );

      expect(
        getAssignmentStatus(
          isSubmitted: true,
          dueDate: pastDueDate,
          currentDate: now,
        ),
        'Submitted',
      );
    });

    test('Calculates days until due', () {
      int daysUntilDue(DateTime dueDate, DateTime currentDate) {
        return dueDate.difference(currentDate).inDays;
      }

      final now = DateTime(2024, 1, 10);
      final dueIn5Days = DateTime(2024, 1, 15);
      final dueYesterday = DateTime(2024, 1, 9);

      expect(daysUntilDue(dueIn5Days, now), 5);
      expect(daysUntilDue(dueYesterday, now), -1);
    });
  });
}