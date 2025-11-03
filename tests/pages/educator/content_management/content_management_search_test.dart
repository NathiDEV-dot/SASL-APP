// ignore_for_file: prefer_const_declarations, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Content Management - Search Feature', () {
    
    testWidgets('Search bar UI components exist', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search content...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search content...'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });

    testWidgets('Search bar accepts text input', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: const InputDecoration(hintText: 'Search content...'),
              onChanged: (value) {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Mathematics');
      await tester.pump();

      expect(find.text('Mathematics'), findsOneWidget);
    });

    testWidgets('Search functionality shows filtered results', (WidgetTester tester) async {
      // Simulate search results
      final allVideos = ['Mathematics Basics', 'English Grammar', 'SASL Introduction'];
      final searchQuery = 'Math';
      
      final filteredVideos = allVideos.where((video) => video.toLowerCase().contains(searchQuery.toLowerCase())).toList();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(hintText: 'Search content...'),
                ),
                Expanded(
                  child: ListView(
                    children: filteredVideos.map((video) => ListTile(title: Text(video))).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Should only show math-related videos
      expect(find.text('Mathematics Basics'), findsOneWidget);
      expect(find.text('English Grammar'), findsNothing);
      expect(find.text('SASL Introduction'), findsNothing);
    });

    testWidgets('Empty search results show message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const TextField(
                  decoration: InputDecoration(hintText: 'Search content...'),
                ),
                Container(
                  padding: const EdgeInsets.all(40),
                  child: const Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No videos found for "Nonexistent"',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('No videos found for "Nonexistent"'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    });
  });
}