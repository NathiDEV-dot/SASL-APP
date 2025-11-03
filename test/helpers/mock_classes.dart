import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Simple mocks without Flutter dependencies first
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockAuthClient extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {}
class MockSession extends Mock implements Session {}
class MockAuthResponse extends Mock implements AuthResponse {}
