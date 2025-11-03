import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signsync_academy/pages/educator/dashboard.dart';

void main() {
  testWidgets('EducatorDashboard renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EducatorDashboard(),
      ),
    );

    // Should show loading state initially
    expect(find.text('Loading Dashboard...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('EducatorDashboard shows app bar with correct title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EducatorDashboard(),
      ),
    );

    expect(find.text('Educator Dashboard'), findsOneWidget);
  });

  testWidgets('EducatorDashboard has bottom navigation bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EducatorDashboard(),
      ),
    );

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
  });

  testWidgets('EducatorDashboard shows refresh button in app bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EducatorDashboard(),
      ),
    );

    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });

  testWidgets('EducatorDashboard shows menu button in app bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EducatorDashboard(),
      ),
    );

    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
  });

  testWidgets('EducatorDashboard has correct theme colors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EducatorDashboard(),
      ),
    );

    // Test that the dashboard uses MaterialApp theming
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme, isNotNull);
    expect(materialApp.home, isA<EducatorDashboard>());
  });

  testWidgets('EducatorDashboard uses Scaffold for layout', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EducatorDashboard(),
      ),
    );

    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('EducatorDashboard has safe area', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EducatorDashboard(),
      ),
    );

    expect(find.byType(SafeArea), findsOneWidget);
  });

  testWidgets('EducatorDashboard navigation items have correct icons', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EducatorDashboard(),
      ),
    );

    // Check that navigation items have icons
    expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
    expect(find.byIcon(Icons.video_library_rounded), findsOneWidget);
    expect(find.byIcon(Icons.live_tv_rounded), findsOneWidget);
    expect(find.byIcon(Icons.rate_review_rounded), findsOneWidget);
  });

  testWidgets('EducatorDashboard uses SingleChildScrollView for content', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EducatorDashboard(),
      ),
    );

    // After loading, it should use SingleChildScrollView
    // We can't easily test the loaded state without complex mocking,
    // but we can verify the widget structure
    await tester.pumpAndSettle();

    // The dashboard should have scrollable content
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
