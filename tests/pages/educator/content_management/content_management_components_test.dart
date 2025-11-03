// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Helper method to build stat cards (moved to top level)
Widget _buildStatCard({required String value, required String label}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3B82F6),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF2D3748),
        ),
      ),
    ],
  );
}

void main() {
  group('Content Management - UI Components', () {
    
    testWidgets('Stats card displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard(value: '10', label: 'Videos'),
                  _buildStatCard(value: '8', label: 'Published'),
                  _buildStatCard(value: '1500', label: 'Total Views'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
      expect(find.text('Total Views'), findsOneWidget);
    });

    testWidgets('Folder chips display correctly', (WidgetTester tester) async {
      final folders = [
        'All Content',
        'Mathematics', 
        'English',
        'South African Sign Language',
        'Technology',
        'Economic Management Sciences',
        'Life Orientation',
        'Archived'
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: folders.map((folder) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(folder),
                      selected: false,
                      onSelected: (selected) {},
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('All Content'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('Search bar UI works', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: InputDecoration(
                hintText: 'Search content...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Search content...'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });

    testWidgets('Empty state displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.video_library_outlined,
                  size: 64,
                  color: Colors.grey.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No videos found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your first lesson to get started',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
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
      );

      expect(find.text('No videos found'), findsOneWidget);
      expect(find.text('Create your first lesson to get started'), findsOneWidget);
      expect(find.text('Create Lesson'), findsOneWidget);
    });
  });
}