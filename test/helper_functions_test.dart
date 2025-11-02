import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Duration Formatting Helper', () {
    String formatDuration(Duration duration) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);

      if (hours > 0) {
        return '${hours}h ${minutes}m ${seconds}s';
      } else if (minutes > 0) {
        return '${minutes}m ${seconds}s';
      } else {
        return '${seconds}s';
      }
    }

    test('formats hours, minutes, seconds correctly', () {
      expect(formatDuration(const Duration(hours: 2, minutes: 30, seconds: 45)), 
          '2h 30m 45s');
    });

    test('formats minutes and seconds correctly', () {
      expect(formatDuration(const Duration(minutes: 15, seconds: 30)), 
          '15m 30s');
    });

    test('formats seconds only correctly', () {
      expect(formatDuration(const Duration(seconds: 45)), 
          '45s');
    });

    test('handles zero duration correctly', () {
      expect(formatDuration(Duration.zero), 
          '0s');
    });
  });

  group('Date Formatting Helper', () {
    String formatDate(DateTime date) {
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final weekdays = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
      ];
      
      return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
    }

    String formatTime(TimeOfDay time) {
      final hour = time.hourOfPeriod;
      final minute = time.minute.toString().padLeft(2, '0');
      final period = time.period == DayPeriod.am ? 'AM' : 'PM';
      return '$hour:$minute $period';
    }

    test('formats date correctly', () {
      final testDate = DateTime(2024, 3, 15); // Friday, March 15, 2024
      expect(formatDate(testDate), 'Friday, 15 March 2024');
    });

    test('formats AM time correctly', () {
      expect(formatTime(const TimeOfDay(hour: 9, minute: 5)), '9:05 AM');
    });

    test('formats PM time correctly', () {
      expect(formatTime(const TimeOfDay(hour: 14, minute: 30)), '2:30 PM');
    });

    test('formats noon correctly', () {
      expect(formatTime(const TimeOfDay(hour: 12, minute: 0)), '12:00 PM');
    });

    test('formats midnight correctly', () {
      expect(formatTime(const TimeOfDay(hour: 0, minute: 0)), '12:00 AM');
    });
  });

  group('Form Validation Logic', () {
    bool validateForm({
      required String title,
      required String subject,
      required String grade,
      required bool hasVideo,
      required bool publishImmediately,
      required DateTime? scheduledDate,
    }) {
      if (title.isEmpty) return false;
      if (subject.isEmpty) return false;
      if (grade.isEmpty) return false;
      if (!hasVideo) return false;
      
      if (!publishImmediately && scheduledDate == null) {
        return false;
      }
      
      return true;
    }

    test('validates complete form for immediate publishing', () {
      expect(validateForm(
        title: 'Math Lesson',
        subject: 'Mathematics',
        grade: 'Grade 10',
        hasVideo: true,
        publishImmediately: true,
        scheduledDate: null,
      ), isTrue);
    });

    test('validates complete form for scheduled publishing', () {
      expect(validateForm(
        title: 'Science Lesson',
        subject: 'Science',
        grade: 'Grade 8',
        hasVideo: true,
        publishImmediately: false,
        scheduledDate: DateTime.now().add(const Duration(days: 1)),
      ), isTrue);
    });

    test('rejects form with missing title', () {
      expect(validateForm(
        title: '',
        subject: 'Mathematics',
        grade: 'Grade 10',
        hasVideo: true,
        publishImmediately: true,
        scheduledDate: null,
      ), isFalse);
    });

    test('rejects form without video', () {
      expect(validateForm(
        title: 'Math Lesson',
        subject: 'Mathematics',
        grade: 'Grade 10',
        hasVideo: false,
        publishImmediately: true,
        scheduledDate: null,
      ), isFalse);
    });

    test('rejects scheduled publishing without date', () {
      expect(validateForm(
        title: 'Math Lesson',
        subject: 'Mathematics',
        grade: 'Grade 10',
        hasVideo: true,
        publishImmediately: false,
        scheduledDate: null,
      ), isFalse);
    });
  });
}