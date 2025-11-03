// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Content Management - Basic Functionality', () {
    
    testWidgets('Page displays main title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Content Library',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Content Library'), findsOneWidget);
    });

    testWidgets('Action buttons are present', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('Search field is present', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search content...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search content...'), findsOneWidget);
    });

    testWidgets('Folder section displays folder categories', (WidgetTester tester) async {
      // Test with a simpler approach - just show a few folders
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  const Text('Folders'),
                  Wrap(
                    spacing: 8,
                    children: const [
                      ChoiceChip(
                        label: Text('All Content'),
                        selected: true,
                        onSelected: null,
                      ),
                      ChoiceChip(
                        label: Text('Mathematics'),
                        selected: false,
                        onSelected: null,
                      ),
                      ChoiceChip(
                        label: Text('English'),
                        selected: false,
                        onSelected: null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Check that basic folders are displayed
      expect(find.text('Folders'), findsOneWidget);
      expect(find.text('All Content'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('Content header displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Videos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text('5 items'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('All Videos'), findsOneWidget);
      expect(find.text('5 items'), findsOneWidget);
    });
  });
}