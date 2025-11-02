// ignore_for_file: unused_local_variable

import 'package:flutter_test/flutter_test.dart';

class Lesson {
  final String id;
  final String title;
  final String? description;
  final String subject;
  final String grade;
  final Duration duration;
  final String educatorId;
  final bool isPublished;
  final DateTime? scheduledPublish;
  final DateTime createdAt;

  Lesson({
    required this.id,
    required this.title,
    this.description,
    required this.subject,
    required this.grade,
    required this.duration,
    required this.educatorId,
    this.isPublished = false,
    this.scheduledPublish,
    required this.createdAt,
  });

  Lesson copyWith({
    String? id,
    String? title,
    String? description,
    String? subject,
    String? grade,
    Duration? duration,
    String? educatorId,
    bool? isPublished,
    DateTime? scheduledPublish,
    DateTime? createdAt,
  }) {
    return Lesson(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
      duration: duration ?? this.duration,
      educatorId: educatorId ?? this.educatorId,
      isPublished: isPublished ?? this.isPublished,
      scheduledPublish: scheduledPublish ?? this.scheduledPublish,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'subject': subject,
      'grade': grade,
      'duration_seconds': duration.inSeconds,
      'educator_id': educatorId,
      'is_published': isPublished,
      'scheduled_publish': scheduledPublish?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

void main() {
  group('Data Models', () {
    test('Lesson model creation and serialization', () {
      final lesson = Lesson(
        id: 'lesson-123',
        title: 'Advanced Calculus',
        description: 'Derivatives and applications',
        subject: 'Mathematics',
        grade: 'Grade 12',
        duration: const Duration(minutes: 45),
        educatorId: 'educator-456',
        isPublished: true,
        createdAt: DateTime(2024, 1, 15),
      );

      expect(lesson.id, 'lesson-123');
      expect(lesson.title, 'Advanced Calculus');
      expect(lesson.subject, 'Mathematics');
      expect(lesson.grade, 'Grade 12');
      expect(lesson.duration.inMinutes, 45);
      expect(lesson.isPublished, isTrue);

      final json = lesson.toJson();
      expect(json['id'], 'lesson-123');
      expect(json['title'], 'Advanced Calculus');
      expect(json['duration_seconds'], 2700);
      expect(json['is_published'], isTrue);
    });

    test('Lesson copyWith creates updated instance', () {
      final original = Lesson(
        id: 'original',
        title: 'Original Title',
        subject: 'Math',
        grade: 'Grade 10',
        duration: const Duration(minutes: 30),
        educatorId: 'educator-1',
        createdAt: DateTime(2024, 1, 1),
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        subject: 'Science',
        isPublished: true,
      );

      expect(updated.title, 'Updated Title');
      expect(updated.subject, 'Science');
      expect(updated.grade, 'Grade 10'); // unchanged
      expect(updated.isPublished, isTrue);
      expect(updated.id, 'original'); // unchanged
    });

    test('Scheduled lesson validation', () {
      final futureDate = DateTime.now().add(const Duration(days: 1));
      final pastDate = DateTime.now().subtract(const Duration(days: 1));

      final scheduledLesson = Lesson(
        id: 'scheduled-123',
        title: 'Scheduled Lesson',
        subject: 'Mathematics',
        grade: 'Grade 11',
        duration: const Duration(minutes: 60),
        educatorId: 'educator-456',
        isPublished: false,
        scheduledPublish: futureDate,
        createdAt: DateTime.now(),
      );

      expect(scheduledLesson.isPublished, isFalse);
      expect(scheduledLesson.scheduledPublish, futureDate);
    });
  });
}