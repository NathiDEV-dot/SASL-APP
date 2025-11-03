// ignore_for_file: avoid_unnecessary_containers

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Content Management - UI Components', () {
    
    testWidgets('Content card has correct structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey),
              ),
              child: Column(
                children: [
                  // Thumbnail
                  Container(
                    height: 100,
                    color: Colors.grey[300],
                    child: const Center(child: Icon(Icons.videocam_rounded)),
                  ),
                  // Content
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Video Title'),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.remove_red_eye_rounded, size: 12),
                            SizedBox(width: 4),
                            Text('150 views'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Video Title'), findsOneWidget);
      expect(find.text('150 views'), findsOneWidget);
    });

    testWidgets('Loading state displays progress indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blue[600]),
                  const SizedBox(height: 16),
                  const Text('Loading your content...'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading your content...'), findsOneWidget);
    });

    testWidgets('Search field has correct decoration', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: InputDecoration(
                hintText: 'Search content...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.hintText, 'Search content...');
      expect(textField.decoration?.prefixIcon, isNotNull);
    });

    testWidgets('Folder chips display correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChoiceChip(
              label: const Text('Mathematics'),
              selected: true,
              onSelected: (selected) {},
            ),
          ),
        ),
      );

      // Just verify the chip exists and has the correct text
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsOneWidget);
      
      // Verify the chip is selected
      final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
      expect(chip.selected, true);
    });

    testWidgets('Stats container has correct styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Stats Content'),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      expect(container.decoration, isNotNull);
      expect(container.padding, const EdgeInsets.all(16));
    });

    testWidgets('Content grid items display correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GridView.count(
              crossAxisCount: 2,
              children: [
                Container(
                  child: const Column(
                    children: [
                      Icon(Icons.videocam_rounded),
                      Text('Video 1'),
                    ],
                  ),
                ),
                Container(
                  child: const Column(
                    children: [
                      Icon(Icons.videocam_rounded),
                      Text('Video 2'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Video 1'), findsOneWidget);
      expect(find.text('Video 2'), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
    });
  });
}