import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Input Validation', () {
    test('Validates submission text', () {
      String? validateSubmission(String text) {
        if (text.isEmpty) return 'Submission cannot be empty';
        if (text.length < 10) return 'Submission too short (min 10 characters)';
        if (text.length > 1000) return 'Submission too long (max 1000 characters)';
        return null;
      }

      expect(validateSubmission(''), 'Submission cannot be empty');
      expect(validateSubmission('Short'), 'Submission too short (min 10 characters)');
      expect(validateSubmission('This is a valid homework submission that meets the minimum length requirement.'), null);
    });

    test('Validates file attachments', () {
      bool isValidFileType(String fileName) {
        final allowedExtensions = ['.pdf', '.doc', '.docx', '.txt', '.jpg', '.png'];
        return allowedExtensions.any((ext) => fileName.toLowerCase().endsWith(ext));
      }

      expect(isValidFileType('homework.pdf'), true);
      expect(isValidFileType('document.doc'), true);
      expect(isValidFileType('image.jpg'), true);
      expect(isValidFileType('script.exe'), false);
      expect(isValidFileType(''), false);
    });
  });
}