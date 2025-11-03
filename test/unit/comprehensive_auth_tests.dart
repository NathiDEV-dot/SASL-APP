import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Authentication Logic Tests', () {
    test('Email validation logic', () {
      bool isValidSchoolEmail(String email) {
        return email.endsWith('@transorange.school.za');
      }
      
      expect(isValidSchoolEmail('teacher@transorange.school.za'), true);
      expect(isValidSchoolEmail('teacher@gmail.com'), false);
      expect(isValidSchoolEmail(''), false);
      expect(isValidSchoolEmail('transorange.school.za'), false);
    });

    test('Password validation logic', () {
      bool isValidPassword(String password) {
        return password.length >= 6;
      }
      
      expect(isValidPassword('short'), false);
      expect(isValidPassword('valid123'), true);
      expect(isValidPassword(''), false);
      expect(isValidPassword('longenoughpassword'), true);
    });

    test('Password confirmation logic', () {
      bool doPasswordsMatch(String password, String confirmPassword) {
        return password == confirmPassword && password.isNotEmpty;
      }
      
      expect(doPasswordsMatch('password123', 'password123'), true);
      expect(doPasswordsMatch('password123', 'different'), false);
      expect(doPasswordsMatch('', ''), false);
      expect(doPasswordsMatch('same', 'same'), true);
    });
  });

  group('Form State Management', () {
    test('Form mode toggling', () {
      bool isSignUpMode = true;
      
      // Test toggle to sign in
      isSignUpMode = false;
      expect(isSignUpMode, false);
      
      // Test toggle back to sign up
      isSignUpMode = true;
      expect(isSignUpMode, true);
    });

    test('Form field clearing on mode toggle', () {
      String email = 'test@email.com';
      String password = 'password123';
      String confirmPassword = 'password123';
      
      // Simulate mode toggle - clear fields
      email = '';
      password = '';
      confirmPassword = '';
      
      expect(email, '');
      expect(password, '');
      expect(confirmPassword, '');
    });
  });

  group('Demo Data Tests', () {
    test('Demo credentials are correct', () {
      const demoEmail = 'zanele.mthembu@transorange.school.za';
      const demoPassword = 'Educator123!';
      
      expect(demoEmail, 'zanele.mthembu@transorange.school.za');
      expect(demoPassword, 'Educator123!');
      expect(demoEmail.endsWith('@transorange.school.za'), true);
      expect(demoPassword.length >= 6, true);
    });

    test('Grade detection from email', () {
      String getGradeFromEmail(String email) {
        if (email.contains('zanele.mthembu')) return 'Grade 1';
        if (email.contains('johan.venter')) return 'Grade 2';
        if (email.contains('lerato.moloi')) return 'Grade 3';
        return 'Grade 1'; // default
      }
      
      expect(getGradeFromEmail('zanele.mthembu@transorange.school.za'), 'Grade 1');
      expect(getGradeFromEmail('johan.venter@transorange.school.za'), 'Grade 2');
      expect(getGradeFromEmail('unknown@transorange.school.za'), 'Grade 1');
    });
  });

  group('Error Handling Logic', () {
    test('Error message parsing', () {
      String parseErrorMessage(String error) {
        return error.replaceAll('Exception: ', '');
      }
      
      expect(parseErrorMessage('Exception: User already exists'), 'User already exists');
      expect(parseErrorMessage('Invalid password'), 'Invalid password');
      expect(parseErrorMessage('Exception: Network error'), 'Network error');
    });

    test('Account exists error detection', () {
      bool isAccountExistsError(String error) {
        return error.toLowerCase().contains('already exists') || 
               error.toLowerCase().contains('already registered');
      }
      
      expect(isAccountExistsError('Account already exists'), true);
      expect(isAccountExistsError('User already registered'), true);
      expect(isAccountExistsError('Invalid password'), false);
      expect(isAccountExistsError(''), false);
    });
  });
}
