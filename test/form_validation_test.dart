import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Form Validation', () {
    test('validates required fields for lesson creation', () {
      Map<String, String> validateLessonForm({
        String title = '',
        String description = '',
        String subject = '',
        String grade = '',
        bool hasVideo = false,
        bool publishImmediately = true,
        DateTime? scheduledDate,
      }) {
        final errors = <String, String>{};

        if (title.isEmpty) {
          errors['title'] = 'Lesson title is required';
        } else if (title.length < 3) {
          errors['title'] = 'Title must be at least 3 characters';
        }

        if (subject.isEmpty) {
          errors['subject'] = 'Subject is required';
        }

        if (grade.isEmpty) {
          errors['grade'] = 'Grade level is required';
        }

        if (!hasVideo) {
          errors['video'] = 'Video content is required';
        }

        if (!publishImmediately && scheduledDate == null) {
          errors['schedule'] = 'Scheduled date is required for future publishing';
        }

        if (!publishImmediately && scheduledDate != null) {
          if (scheduledDate.isBefore(DateTime.now())) {
            errors['schedule'] = 'Scheduled date must be in the future';
          }
        }

        return errors;
      }

      // Test valid form
      expect(validateLessonForm(
        title: 'Mathematics Advanced Calculus',
        subject: 'Mathematics',
        grade: 'Grade 11',
        hasVideo: true,
        publishImmediately: true,
      ), isEmpty);

      // Test empty title
      expect(validateLessonForm(
        title: '',
        subject: 'Mathematics',
        grade: 'Grade 11',
        hasVideo: true,
      )['title'], 'Lesson title is required');

      // Test short title
      expect(validateLessonForm(
        title: 'AB',
        subject: 'Mathematics',
        grade: 'Grade 11',
        hasVideo: true,
      )['title'], 'Title must be at least 3 characters');

      // Test missing video
      expect(validateLessonForm(
        title: 'Valid Title',
        subject: 'Mathematics',
        grade: 'Grade 11',
        hasVideo: false,
      )['video'], 'Video content is required');

      // Test scheduled publishing without date
      expect(validateLessonForm(
        title: 'Valid Title',
        subject: 'Mathematics',
        grade: 'Grade 11',
        hasVideo: true,
        publishImmediately: false,
        scheduledDate: null,
      )['schedule'], 'Scheduled date is required for future publishing');

      // Test past scheduled date
      expect(validateLessonForm(
        title: 'Valid Title',
        subject: 'Mathematics',
        grade: 'Grade 11',
        hasVideo: true,
        publishImmediately: false,
        scheduledDate: DateTime.now().subtract(const Duration(days: 1)),
      )['schedule'], 'Scheduled date must be in the future');
    });

    test('validates description length limits', () {
      String? validateDescription(String? description) {
        if (description == null) return null;
        if (description.length > 500) {
          return 'Description must be less than 500 characters';
        }
        return null;
      }

      expect(validateDescription(null), isNull);
      expect(validateDescription('Short description'), isNull);
      expect(validateDescription('A' * 501), 'Description must be less than 500 characters');
    });
  });
}