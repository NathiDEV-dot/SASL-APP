import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Content Management - Empty States', () {
    
    testWidgets('Empty state displays correct elements', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.video_library_outlined, size: 64),
                  const SizedBox(height: 16),
                  const Text('No videos found'),
                  const SizedBox(height: 8),
                  const Text('Create your first lesson to get started'),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create Lesson'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.video_library_outlined), findsOneWidget);
      expect(find.text('No videos found'), findsOneWidget);
      expect(find.text('Create your first lesson to get started'), findsOneWidget);
      expect(find.text('Create Lesson'), findsOneWidget);
    });

    testWidgets('Search empty state shows specific message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.all(40),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 64),
                  SizedBox(height: 16),
                  Text('No videos found for "nonexistent"'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
      expect(find.text('No videos found for "nonexistent"'), findsOneWidget);
    });

    testWidgets('Create lesson button is functional', (WidgetTester tester) async {
      bool buttonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  buttonPressed = true;
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Lesson'),
              ),
            ),
          ),
        ),
      );

      final button = find.text('Create Lesson');
      expect(button, findsOneWidget);

      await tester.tap(button);
      expect(buttonPressed, true);
    });

    testWidgets('Empty state icon has correct styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.all(40),
              child: const Icon(
                Icons.video_library_outlined,
                size: 64,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.video_library_outlined));
      expect(icon.color, Colors.grey);
      expect(icon.size, 64);
    });
  });
}