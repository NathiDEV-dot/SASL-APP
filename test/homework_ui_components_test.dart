import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Student info header displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: const Text(
                    'JD',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'John Doe',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Grade: 10 • Code: STU123',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
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

    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Grade: 10 • Code: STU123'), findsOneWidget);
    expect(find.text('JD'), findsOneWidget);
  });

  testWidgets('Assignment card displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Math Homework',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Pending',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Lesson: Algebra Basics',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Solve equations',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Due: 15/1/2024'),
                          ElevatedButton(
                            onPressed: () {},
                            child: const Text('Submit'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Math Homework'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Solve equations'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
  });

  testWidgets('Empty state displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.assignment, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No Assignments',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have no pending homework assignments',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('No Assignments'), findsOneWidget);
    expect(find.text('You have no pending homework assignments'), findsOneWidget);
    expect(find.byIcon(Icons.assignment), findsOneWidget);
  });

  testWidgets('Submission card displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Math Homework',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('I completed the homework'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Submitted: 14/1/2024'),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'GRADED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Score: 85/100',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Feedback: Good work!',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Math Homework'), findsOneWidget);
    expect(find.text('I completed the homework'), findsOneWidget);
    expect(find.text('GRADED'), findsOneWidget);
    expect(find.text('Score: 85/100'), findsOneWidget);
    expect(find.text('Feedback: Good work!'), findsOneWidget);
  });
}