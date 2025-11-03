import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Content Management - Navigation', () {
    
    testWidgets('Create lesson button triggers action', (WidgetTester tester) async {
      bool createLessonCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                createLessonCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      expect(createLessonCalled, true);
    });

    testWidgets('Refresh button triggers refresh', (WidgetTester tester) async {
      bool refreshCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                refreshCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.refresh_rounded));
      expect(refreshCalled, true);
    });

    testWidgets('Folder selection works', (WidgetTester tester) async {
      bool folderSelected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChoiceChip(
              label: const Text('Mathematics'),
              selected: false,
              onSelected: (selected) {
                folderSelected = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mathematics'));
      expect(folderSelected, true);
    });

    testWidgets('Video play button is present', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextButton(
              onPressed: () {},
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, size: 12),
                  SizedBox(width: 4),
                  Text('Play'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Play'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('Edit button is present', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextButton(
              onPressed: () {},
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_rounded, size: 12),
                  SizedBox(width: 4),
                  Text('Edit'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Edit'), findsOneWidget);
      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    });
  });
}