import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Tab bar displays and switches correctly', (WidgetTester tester) async {
    int selectedTab = 0;
    String currentContent = 'Assignments Content';

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Column(
                children: [
                  // Tab Bar
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Assignments Tab
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                selectedTab = 0;
                                currentContent = 'Assignments Content';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: selectedTab == 0 ? Colors.blue : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Assignments',
                                    style: TextStyle(
                                      fontWeight: selectedTab == 0 ? FontWeight.bold : FontWeight.normal,
                                      color: selectedTab == 0 ? Colors.blue : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: selectedTab == 0 ? Colors.blue : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '3',
                                      style: TextStyle(
                                        color: selectedTab == 0 ? Colors.white : Colors.grey[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Submissions Tab
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                selectedTab = 1;
                                currentContent = 'Submissions Content';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: selectedTab == 1 ? Colors.blue : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Submissions',
                                    style: TextStyle(
                                      fontWeight: selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                                      color: selectedTab == 1 ? Colors.blue : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: selectedTab == 1 ? Colors.blue : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '5',
                                      style: TextStyle(
                                        color: selectedTab == 1 ? Colors.white : Colors.grey[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Center(
                      child: Text(currentContent),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    // Initial state - Assignments tab active
    expect(find.text('Assignments'), findsOneWidget);
    expect(find.text('Submissions'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Assignments Content'), findsOneWidget);

    // Tap on submissions tab
    await tester.tap(find.text('Submissions'));
    await tester.pumpAndSettle();

    // Verify the tab changed
    expect(find.text('Submissions Content'), findsOneWidget);
  });
}