// ignore_for_file: prefer_adjacent_string_concatenation

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('basic math works', () {
    expect(1 + 1, 2);
  });

  test('string concatenation works', () {
    expect('Hello' + ' ' + 'World', 'Hello World');
  });

  test('list operations work', () {
    final list = [1, 2, 3];
    expect(list.length, 3);
    expect(list.contains(2), isTrue);
  });

  test('duration formatting logic', () {
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

    expect(formatDuration(const Duration(hours: 1, minutes: 30, seconds: 45)), 
        '1h 30m 45s');
    expect(formatDuration(const Duration(minutes: 5, seconds: 30)), 
        '5m 30s');
  });
}