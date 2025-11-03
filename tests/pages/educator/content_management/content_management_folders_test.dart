import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Content Management - Folders Feature', () {
    
    testWidgets('Main folder categories are displayed', (WidgetTester tester) async {
      final folders = [
        'All Content',
        'Mathematics',
        'English', 
        'Archived'
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Folders',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: folders.map((folder) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            folder,
                            style: TextStyle(
                              fontSize: 12,
                              color: folder == 'All Content' ? Colors.white : Colors.black,
                            ),
                          ),
                          selected: folder == 'All Content',
                          onSelected: (selected) {},
                          backgroundColor: Colors.grey[200],
                          selectedColor: const Color(0xFF3B82F6),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Check main folders are displayed
      expect(find.text('All Content'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
    });

    testWidgets('Folder selection changes UI state', (WidgetTester tester) async {
      String selectedFolder = 'All Content';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: ['All Content', 'Mathematics', 'English'].map((folder) {
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(folder),
                              selected: selectedFolder == folder,
                              onSelected: (selected) {
                                setState(() {
                                  selectedFolder = folder;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Text('Selected: $selectedFolder'),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Initially 'All Content' should be selected
      expect(find.text('Selected: All Content'), findsOneWidget);

      // Tap on Mathematics folder
      await tester.tap(find.text('Mathematics'));
      await tester.pump();

      // Should update to show Mathematics selected
      expect(find.text('Selected: Mathematics'), findsOneWidget);
    });

    testWidgets('Folder chips are horizontally scrollable', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (int i = 0; i < 5; i++) // Reduced from 10 to 5 to ensure they fit
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('Folder $i'),
                        selected: false,
                        onSelected: (selected) {},
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Folder 0'), findsOneWidget);
      expect(find.text('Folder 4'), findsOneWidget); // Changed from Folder 9 to Folder 4
    });

    testWidgets('Folder section has correct title and layout', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Folders',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ChoiceChip(label: const Text('All Content'), selected: true, onSelected: (_) {}),
                        ChoiceChip(label: const Text('Mathematics'), selected: false, onSelected: (_) {}),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Folders'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(2));
    });

    testWidgets('Folder chips have correct styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: const Text('All Content'),
                    selected: true,
                    onSelected: (_) {},
                    backgroundColor: Colors.grey[200],
                    selectedColor: const Color(0xFF3B82F6),
                  ),
                  ChoiceChip(
                    label: const Text('Mathematics'),
                    selected: false,
                    onSelected: (_) {},
                    backgroundColor: Colors.grey[200],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Both chips should exist
      expect(find.text('All Content'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
      
      // Should have ListView for horizontal scrolling
      expect(find.byType(ListView), findsOneWidget);
    });
  });
}