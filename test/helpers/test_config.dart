import 'package:flutter_test/flutter_test.dart';

// Helper for future integration tests
class TestConfig {
  static const testEmail = 'test@transorange.school.za';
  static const testPassword = 'Educator123!';
  static const testStudentCode = 'STU123456';
  
  static Map<String, dynamic> mockEducatorProfile() {
    return {
      'id': 'test-educator-123',
      'first_name': 'Test',
      'last_name': 'Educator',
      'email': testEmail,
      'grade': 'Grade 1',
      'school_name': 'Test School',
    };
  }
  
  static Map<String, dynamic> mockStudentProfile() {
    return {
      'student_code': testStudentCode,
      'first_name': 'Test',
      'last_name': 'Student',
      'grade': 'Grade 1',
    };
  }
}
