// Mock data for lesson creation tests
class MockLessonData {
  static Map<String, dynamic> get validLessonData {
    return {
      'title': 'Mathematics Basics',
      'subject': 'Mathematics',
      'grade': 'Grade 10',
      'durationSeconds': 3600,
      'educatorId': 'educator-123',
      'description': 'Basic algebra concepts for beginners',
      'isPublished': true,
      'scheduledPublish': null,
    };
  }

  static Map<String, dynamic> get scheduledLessonData {
    return {
      'title': 'Science Experiment',
      'subject': 'Science',
      'grade': 'Grade 11',
      'durationSeconds': 1800,
      'educatorId': 'educator-123',
      'description': 'Chemistry lab demonstration',
      'isPublished': false,
      'scheduledPublish': DateTime.now().add(const Duration(days: 1)),
    };
  }

  static List<String> get availableSubjects {
    return [
      'Mathematics',
      'English',
      'South African Sign Language',
      'Technology',
      'Economic Management Sciences',
      'Life Orientation'
    ];
  }

  static List<String> get availableGrades {
    return [
      'Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5',
      'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10',
      'Grade 11', 'Grade 12'
    ];
  }

  static Map<String, dynamic> get videoValidationTestCases {
    return {
      'valid_mp4': {
        'size': 50 * 1024 * 1024, // 50MB
        'extension': '.mp4',
        'shouldPass': true
      },
      'valid_mov': {
        'size': 80 * 1024 * 1024, // 80MB
        'extension': '.mov',
        'shouldPass': true
      },
      'too_large': {
        'size': 600 * 1024 * 1024, // 600MB
        'extension': '.mp4',
        'shouldPass': false
      },
      'invalid_extension': {
        'size': 10 * 1024 * 1024, // 10MB
        'extension': '.txt',
        'shouldPass': false
      },
      'very_large': {
        'size': 150 * 1024 * 1024, // 150MB
        'extension': '.mp4',
        'shouldPass': false
      }
    };
  }

  static Map<String, dynamic> get scheduleTimeTestCases {
    final now = DateTime.now();
    return {
      'valid_future': {
        'time': now.add(const Duration(hours: 2)),
        'shouldPass': true
      },
      'too_soon': {
        'time': now.add(const Duration(minutes: 3)),
        'shouldPass': false
      },
      'past': {
        'time': now.subtract(const Duration(hours: 1)),
        'shouldPass': false
      },
      'exactly_5_minutes': {
        'time': now.add(const Duration(minutes: 5, seconds: 1)),
        'shouldPass': true
      }
    };
  }
}
