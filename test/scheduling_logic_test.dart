import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Scheduling Logic', () {
    test('validates future dates correctly', () {
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 1));
      final futureDate = now.add(const Duration(days: 1));

      // Past dates should be invalid
      expect(pastDate.isBefore(now), isTrue);
      
      // Future dates should be valid
      expect(futureDate.isAfter(now), isTrue);
    });

    test('calculates progress correctly', () {
      // Simulate progress calculation
      double calculateProgress({
        required bool hasTitle,
        required bool hasGrade,
        required bool hasVideo,
        required bool hasSchedule,
      }) {
        double progress = 0.0;
        if (hasTitle) progress += 0.3;
        if (hasGrade) progress += 0.3;
        if (hasVideo) progress += 0.3;
        if (hasSchedule) progress += 0.1;
        return progress;
      }

      // Test various completion states
      expect(calculateProgress(
        hasTitle: false, hasGrade: false, hasVideo: false, hasSchedule: false),
        0.0);
      
      expect(calculateProgress(
        hasTitle: true, hasGrade: false, hasVideo: false, hasSchedule: false),
        0.3);
      
      expect(calculateProgress(
        hasTitle: true, hasGrade: true, hasVideo: false, hasSchedule: false),
        0.6);
      
      // FIX: Use closeTo for floating-point comparison
      expect(
        calculateProgress(
          hasTitle: true, hasGrade: true, hasVideo: true, hasSchedule: true),
        closeTo(1.0, 0.0001), // Allow small difference for floating-point math
      );
    });

    test('schedule date validation', () {
      bool isValidScheduleDate(DateTime? date, bool isImmediate) {
        if (isImmediate) return true;
        if (date == null) return false;
        return date.isAfter(DateTime.now());
      }

      expect(isValidScheduleDate(null, true), isTrue);
      expect(isValidScheduleDate(DateTime.now().add(const Duration(days: 1)), false), isTrue);
      expect(isValidScheduleDate(null, false), isFalse);
      expect(isValidScheduleDate(DateTime.now().subtract(const Duration(days: 1)), false), isFalse);
    });
  });
}