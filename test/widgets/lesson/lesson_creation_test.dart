import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signsync_academy/pages/educator/lesson_creation.dart';

void main() {
  testWidgets('LessonCreation screen renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonCreation(),
      ),
    );

    expect(find.text('Create New Lesson'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('LessonCreation shows all main sections', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonCreation(),
      ),
    );

    expect(find.text('Lesson Video'), findsOneWidget);
    expect(find.text('Lesson Details'), findsOneWidget);
    expect(find.text('Publishing Options'), findsOneWidget);
  });

  testWidgets('LessonCreation has video selection buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonCreation(),
      ),
    );

    expect(find.text('Choose Video'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
    expect(find.byIcon(Icons.video_library_rounded), findsOneWidget);
    expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);
  });

  testWidgets('LessonCreation has form fields for lesson details', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonCreation(),
      ),
    );

    expect(find.text('Lesson Title *'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Subject *'), findsOneWidget);
    expect(find.text('Grade'), findsOneWidget);
  });

  testWidgets('LessonCreation has publishing options', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonCreation(),
      ),
    );

    expect(find.text('Publish Now'), findsOneWidget);
    expect(find.text('Schedule for Later'), findsOneWidget);
    expect(find.byIcon(Icons.rocket_launch_rounded), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
  });

  testWidgets('LessonCreation has create/publish button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonCreation(),
      ),
    );

    expect(find.text('Publish Lesson Now'), findsOneWidget);
  });

  testWidgets('LessonCreation uses correct theme colors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonCreation(),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xFF4361EE));
  });

  testWidgets('LessonCreation has scrollable content', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonCreation(),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('LessonCreation shows video selection placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonCreation(),
      ),
    );

    expect(find.text('Add your lesson video'), findsOneWidget);
    expect(find.text('MP4, MOV, AVI, MKV, or WEBM • Max 500MB'), findsOneWidget);
  });

  testWidgets('LessonCreation has subject dropdown', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonCreation(),
      ),
    );

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('LessonCreation has back button in app bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonCreation(),
      ),
    );

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });
}
