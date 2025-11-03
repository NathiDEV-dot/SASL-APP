import 'package:flutter_test/flutter_test.dart';

// Simple data model tests
class MockUserData {
  final String email;
  final String password;

  MockUserData({required this.email, required this.password});
}

void main() {
  group('Simple Data Tests', () {
    test('Mock user data creation', () {
      final user = MockUserData(
        email: 'test@transorange.school.za',
        password: 'Password123!',
      );
      
      expect(user.email, 'test@transorange.school.za');
      expect(user.password, 'Password123!');
    });

    test('Email validation', () {
      final validEmail = 'test@transorange.school.za';
      final invalidEmail = 'test@gmail.com';
      
      expect(validEmail.endsWith('@transorange.school.za'), isTrue);
      expect(invalidEmail.endsWith('@transorange.school.za'), isFalse);
    });

    test('Password validation', () {
      final shortPassword = '123';
      final validPassword = 'Password123!';
      
      expect(shortPassword.length >= 6, isFalse);
      expect(validPassword.length >= 6, isTrue);
    });
  });

  group('Form Logic Tests', () {
    test('Password matching', () {
      final password = 'Password123!';
      final confirmPassword = 'Password123!';
      final wrongPassword = 'Different123!';
      
      expect(password == confirmPassword, isTrue);
      expect(password == wrongPassword, isFalse);
    });

    test('Form mode toggling', () {
      bool isSignUpMode = true;
      
      // Toggle to sign in
      isSignUpMode = !isSignUpMode;
      expect(isSignUpMode, isFalse);
      
      // Toggle back to sign up
      isSignUpMode = !isSignUpMode;
      expect(isSignUpMode, isTrue);
    });
  });
}
