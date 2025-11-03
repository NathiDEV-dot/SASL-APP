import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Simple test setup
void setupTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Setup mock fallbacks
  registerFallbackValue(MockNavigatorObserver());
}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}
