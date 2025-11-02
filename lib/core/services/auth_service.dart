import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // EDUCATOR: Sign up with pre-verified accounts
  Future<AuthResponse?> educatorSignUp(String email, String password) async {
    try {
      debugPrint('🔄 Attempting educator signup: $email');

      // Check if educator exists in pre_verified_users
      final preVerifiedResponse = await _client
          .from('pre_verified_users')
          .select()
          .eq('email', email)
          .eq('role', 'educator')
          .maybeSingle();

      if (preVerifiedResponse == null) {
        throw Exception('Email not found in pre-verified educators list.');
      }

      // Check if pre-verified user is already used
      if (preVerifiedResponse['is_used'] == true) {
        throw Exception(
            'Educator account already exists. Please sign in instead.');
      }

      // Sign up with Supabase Auth
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'role': 'educator',
          'first_name': preVerifiedResponse['first_name'],
          'last_name': preVerifiedResponse['last_name'],
          'grade': preVerifiedResponse['grade'],
          'school_name': preVerifiedResponse['school_name'],
        },
      );

      if (authResponse.user == null) {
        if (authResponse.user?.identities?.isEmpty ?? true) {
          throw Exception(
              'Educator account already exists. Please sign in instead.');
        }
        throw Exception('Signup failed. Please try again.');
      }

      // Create educator profile immediately
      await _createEducatorProfileFromAuth(
          authResponse.user!, preVerifiedResponse);

      // Mark pre-verified user as used
      await _client
          .from('pre_verified_users')
          .update({'is_used': true}).eq('email', email);

      // Link educator to their classes
      await _linkEducatorToClasses(
          authResponse.user!.id, preVerifiedResponse['grade']);

      debugPrint(
          '✅ Educator signup successful for: ${preVerifiedResponse['first_name']} ${preVerifiedResponse['last_name']}');
      return authResponse;
    } catch (e) {
      debugPrint('❌ Educator signup error: $e');

      if (e.toString().contains('User already registered') ||
          e.toString().contains('already exists') ||
          e.toString().contains('identity_id')) {
        throw Exception(
            'Educator account already exists. Please sign in instead.');
      } else {
        throw Exception(
            'Signup failed: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  // EDUCATOR: Login with existing accounts - FIXED VERSION
  Future<AuthResponse?> educatorLogin(String email, String password) async {
    try {
      debugPrint('🔄 Attempting educator login: $email');

      // Sign in with Supabase Auth
      final authResponse = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Invalid email or password');
      }

      // Get educator profile with better error handling
      final educatorProfile = await _getEducatorProfile(authResponse.user!.id);

      if (educatorProfile == null) {
        // Try to create profile if it doesn't exist
        debugPrint(
            '⚠️ Profile not found, attempting to create from pre-verified data...');
        final preVerified = await _client
            .from('pre_verified_users')
            .select()
            .eq('email', email)
            .eq('role', 'educator')
            .maybeSingle();

        if (preVerified != null) {
          final createdProfile = await _createEducatorProfileFromAuth(
              authResponse.user!, preVerified);
          if (createdProfile != null) {
            debugPrint('✅ Created educator profile successfully');
          } else {
            await _client.auth.signOut();
            throw Exception(
                'Unable to create educator profile. Please contact administrator.');
          }
        } else {
          await _client.auth.signOut();
          throw Exception(
              'Educator profile not found. Please contact administrator.');
        }
      } else {
        debugPrint('✅ Found existing educator profile');
      }

      final educatorName = educatorProfile != null
          ? '${educatorProfile['first_name']} ${educatorProfile['last_name']}'
          : 'Educator';

      debugPrint('✅ Educator login successful: $educatorName');
      return authResponse;
    } catch (e) {
      debugPrint('❌ Educator login error: $e');

      if (e.toString().contains('Invalid login credentials')) {
        throw Exception('Invalid email or password');
      } else if (e.toString().contains('Email not confirmed')) {
        throw Exception('Please verify your email address');
      } else if (e.toString().contains('row-level security') ||
          e.toString().contains('RLS')) {
        throw Exception(
            'Database configuration issue. Please contact administrator.');
      } else {
        throw Exception(
            'Educator login failed: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  // FIXED: Get educator profile with better error handling (PRIVATE VERSION)
  Future<Map<String, dynamic>?> _getEducatorProfile(String educatorId) async {
    try {
      debugPrint('🔄 Getting educator profile for: $educatorId');

      final response = await _client
          .from('profiles')
          .select()
          .eq('id', educatorId)
          .eq('role', 'educator')
          .maybeSingle();

      if (response == null) {
        debugPrint('❌ No educator profile found for ID: $educatorId');
        return null;
      }

      debugPrint('✅ Educator profile retrieved successfully');
      return response;
    } catch (e) {
      debugPrint('❌ Error getting educator profile: $e');

      // Check if it's an RLS policy error
      if (e.toString().contains('row-level security') ||
          e.toString().contains('RLS') ||
          e.toString().contains('policy')) {
        debugPrint('🔒 RLS Policy Error - profiles table may need policies');
        throw Exception('Database access issue. Please contact administrator.');
      }

      return null;
    }
  }

  // Create educator profile from auth user data
  Future<Map<String, dynamic>?> _createEducatorProfileFromAuth(
      User user, Map<String, dynamic> preVerifiedData) async {
    try {
      debugPrint('🔄 Creating educator profile from auth user...');

      final newProfile = {
        'id': user.id,
        'role': 'educator',
        'first_name': preVerifiedData['first_name'],
        'last_name': preVerifiedData['last_name'],
        'grade': preVerifiedData['grade'],
        'school_name': preVerifiedData['school_name'],
        'subject_specialization': 'General Education',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response =
          await _client.from('profiles').insert(newProfile).select().single();

      debugPrint('✅ Created new educator profile successfully');
      return response;
    } catch (e) {
      debugPrint('❌ Error creating educator profile: $e');
      return null;
    }
  }

  // Improved class linking
  Future<void> _linkEducatorToClasses(String educatorId, String grade) async {
    try {
      await _client
          .from('classes')
          .update({'educator_id': educatorId})
          .eq('grade', grade)
          .eq('academic_year', '2024');

      debugPrint('✅ Educator linked to classes for grade: $grade');
    } catch (e) {
      debugPrint('⚠️ Could not link educator to classes: $e');
      // Don't throw error - this is non-critical
    }
  }

  // STUDENT: Simplified login with student code only
  Future<Map<String, dynamic>?> studentLogin(String studentCode) async {
    try {
      debugPrint('🔄 Attempting student login with code: $studentCode');

      final preVerifiedResponse = await _client
          .from('pre_verified_users')
          .select()
          .eq('student_code', studentCode)
          .eq('role', 'student')
          .maybeSingle();

      if (preVerifiedResponse == null) {
        throw Exception('Student code not found in our records');
      }

      final classEnrollments =
          await _client.from('class_enrollments').select('''
            class_id,
            classes (
              id,
              grade,
              subject,
              educator_id,
              profiles!classes_educator_id_fkey (
                first_name,
                last_name
              )
            )
          ''').eq('student_code', studentCode);

      debugPrint('✅ Student login successful');
      return {
        'student_info': preVerifiedResponse,
        'enrollments': classEnrollments,
        'login_type': 'student'
      };
    } catch (e) {
      debugPrint('❌ Student login error: $e');
      throw Exception(
          'Student login failed: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  // PARENT: Login with student code validation
  Future<Map<String, dynamic>?> parentLogin(String studentCode) async {
    try {
      debugPrint('🔄 Attempting parent login for student: $studentCode');

      // Verify student exists
      final studentResponse = await _client
          .from('pre_verified_users')
          .select()
          .eq('student_code', studentCode)
          .eq('role', 'student')
          .maybeSingle();

      if (studentResponse == null) {
        throw Exception('Student code not found in our records');
      }

      final studentData = studentResponse;

      // Get student's classes and progress
      final classEnrollments =
          await _client.from('class_enrollments').select('''
            class_id,
            classes (
              id,
              grade,
              subject,
              educator_id,
              profiles!classes_educator_id_fkey (
                first_name,
                last_name
              )
            )
          ''').eq('student_code', studentCode);

      debugPrint('✅ Parent login successful for student: $studentCode');

      return {
        'student_info': studentData,
        'enrollments': classEnrollments,
        'login_type': 'parent'
      };
    } catch (e) {
      debugPrint('❌ Parent login error: $e');
      throw Exception(
          'Parent login failed: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  // EDUCATOR: Get educator's classes and students
  Future<Map<String, dynamic>?> getEducatorClasses(String educatorId) async {
    try {
      final classes = await _client.from('classes').select('''
            *,
            class_enrollments (
              student_code,
              pre_verified_users!class_enrollments_student_code_fkey (
                first_name,
                last_name,
                grade
              )
            )
          ''').eq('educator_id', educatorId).eq('academic_year', '2024');

      int totalStudents = 0;
      int totalClasses = classes.length;

      for (var classData in classes) {
        final enrollments = classData['class_enrollments'] as List?;
        totalStudents += enrollments?.length ?? 0;
      }

      return {
        'classes': classes,
        'total_classes': totalClasses,
        'total_students': totalStudents,
      };
    } catch (e) {
      debugPrint('❌ Error getting educator classes: $e');
      return null;
    }
  }

  // EDUCATOR: Get educator profile (public version)
  Future<Map<String, dynamic>?> getEducatorProfileById(
      String educatorId) async {
    try {
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', educatorId)
          .eq('role', 'educator')
          .maybeSingle();

      return profile;
    } catch (e) {
      debugPrint('❌ Error getting educator profile: $e');
      return null;
    }
  }

  // Get student profile by student code
  Future<Map<String, dynamic>?> getStudentProfile(String studentCode) async {
    try {
      final profile = await _client
          .from('pre_verified_users')
          .select()
          .eq('student_code', studentCode)
          .eq('role', 'student')
          .maybeSingle();

      return profile;
    } catch (e) {
      debugPrint('❌ Error getting student profile: $e');
      return null;
    }
  }

  // Get student attendance data
  Future<List<dynamic>?> getStudentAttendance(String studentCode) async {
    try {
      final attendance = await _client.from('attendance').select('''
            *,
            classes (
              subject,
              grade
            )
          ''').eq('student_code', studentCode).order('date', ascending: false);

      return attendance;
    } catch (e) {
      debugPrint('❌ Error getting student attendance: $e');
      return null;
    }
  }

  // COMMON: Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
    debugPrint('✅ User signed out');
  }

  // Check if user is educator (has auth session)
  bool get isEducatorLoggedIn => _client.auth.currentUser != null;

  // Get current user (for educators)
  User? get currentUser => _client.auth.currentUser;

  // Check if user session is valid
  bool get hasValidSession => _client.auth.currentSession != null;

  // Get current session
  Session? get currentSession => _client.auth.currentSession;

  // Check if user is authenticated
  bool get isAuthenticated => _client.auth.currentUser != null;

  // Get user ID
  String? get userId => _client.auth.currentUser?.id;

  // Get user email
  String? get userEmail => _client.auth.currentUser?.email;

  // Get user role from metadata
  String? get userRole =>
      _client.auth.currentUser?.userMetadata?['role'] as String?;

  // Refresh session
  Future<void> refreshSession() async {
    try {
      await _client.auth.refreshSession();
      debugPrint('✅ Session refreshed successfully');
    } catch (e) {
      debugPrint('❌ Error refreshing session: $e');
      rethrow;
    }
  }

  // Check if email is confirmed
  bool get isEmailConfirmed =>
      _client.auth.currentUser?.emailConfirmedAt != null;

  // Get user creation time
  String? get userCreatedAt => _client.auth.currentUser?.createdAt;

  // Get last sign in time
  String? get lastSignIn => _client.auth.currentUser?.lastSignInAt;

  // Check if user is anonymous
  bool get isAnonymous => _client.auth.currentUser?.isAnonymous ?? false;

  // Get user app metadata
  Map<String, dynamic>? get appMetadata =>
      _client.auth.currentUser?.appMetadata;

  // Get user metadata
  Map<String, dynamic>? get userMetadata =>
      _client.auth.currentUser?.userMetadata;

  // Get user identities
  List<UserIdentity>? get userIdentities =>
      _client.auth.currentUser?.identities;

  // Get user factors
  List<Factor>? get userFactors => _client.auth.currentUser?.factors;

  // Check if MFA is enabled
  bool get isMFAEnabled =>
      _client.auth.currentUser?.factors?.isNotEmpty ?? false;

  // Get phone number
  String? get phoneNumber => _client.auth.currentUser?.phone;

  // Check if phone is confirmed
  bool get isPhoneConfirmed =>
      _client.auth.currentUser?.phoneConfirmedAt != null;

  // Get user role from app metadata
  String? get roleFromAppMetadata =>
      _client.auth.currentUser?.appMetadata?['role'] as String?;

  // Get user provider
  String? get provider =>
      _client.auth.currentUser?.appMetadata?['provider'] as String?;

  // Get user providers
  List<String>? get providers =>
      _client.auth.currentUser?.appMetadata?['providers'] as List<String>?;

  // Check if user has specific role
  bool hasRole(String role) {
    final userRole = _client.auth.currentUser?.userMetadata?['role'] as String?;
    final appRole = _client.auth.currentUser?.appMetadata?['role'] as String?;
    return userRole == role || appRole == role;
  }

  // Check if user is admin
  bool get isAdmin => hasRole('admin') || hasRole('super_admin');

  // Check if user is super admin
  bool get isSuperAdmin => hasRole('super_admin');

  // Check if user is moderator
  bool get isModerator => hasRole('moderator');

  // Get user display name
  String? get displayName {
    final metadata = _client.auth.currentUser?.userMetadata;
    if (metadata != null) {
      final firstName = metadata['first_name'] as String?;
      final lastName = metadata['last_name'] as String?;
      if (firstName != null && lastName != null) {
        return '$firstName $lastName';
      }
      return metadata['full_name'] as String?;
    }
    return _client.auth.currentUser?.email;
  }

  // Get user first name
  String? get firstName =>
      _client.auth.currentUser?.userMetadata?['first_name'] as String?;

  // Get user last name
  String? get lastName =>
      _client.auth.currentUser?.userMetadata?['last_name'] as String?;

  // Get user avatar URL
  String? get avatarUrl =>
      _client.auth.currentUser?.userMetadata?['avatar_url'] as String?;

  // Get user grade (for educators/students)
  String? get grade =>
      _client.auth.currentUser?.userMetadata?['grade'] as String?;

  // Get user school name
  String? get schoolName =>
      _client.auth.currentUser?.userMetadata?['school_name'] as String?;

  // Get user subject specialization
  String? get subjectSpecialization =>
      _client.auth.currentUser?.userMetadata?['subject_specialization']
          as String?;

  // Get user student code
  String? get studentCode =>
      _client.auth.currentUser?.userMetadata?['student_code'] as String?;

  // Get user parent code
  String? get parentCode =>
      _client.auth.currentUser?.userMetadata?['parent_of_student_code']
          as String?;

  // Get user linked student code
  String? get linkedStudentCode =>
      _client.auth.currentUser?.userMetadata?['linked_student_code'] as String?;

  // Get user phone number from metadata
  String? get phoneFromMetadata =>
      _client.auth.currentUser?.userMetadata?['phone_number'] as String?;

  // Get user avatar URL from metadata
  String? get avatarUrlFromMetadata =>
      _client.auth.currentUser?.userMetadata?['avatar_url'] as String?;

  // Check if user has complete profile
  bool get hasCompleteProfile {
    return firstName != null &&
        lastName != null &&
        schoolName != null &&
        grade != null;
  }

  // Get user profile completeness percentage
  double get profileCompleteness {
    int completedFields = 0;
    int totalFields = 4; // firstName, lastName, schoolName, grade

    if (firstName != null && firstName!.isNotEmpty) completedFields++;
    if (lastName != null && lastName!.isNotEmpty) completedFields++;
    if (schoolName != null && schoolName!.isNotEmpty) completedFields++;
    if (grade != null && grade!.isNotEmpty) completedFields++;

    return completedFields / totalFields;
  }

  // Check if user needs to complete profile
  bool get needsProfileCompletion => profileCompleteness < 1.0;

  // Get user profile status
  String get profileStatus {
    if (!isAuthenticated) return 'not_authenticated';
    if (!hasCompleteProfile) return 'incomplete';
    return 'complete';
  }

  // Get user account age in days
  int? get accountAgeInDays {
    final createdAt = userCreatedAt;
    if (createdAt == null) return null;
    return DateTime.now().difference(createdAt as DateTime).inDays;
  }

  // Check if user is new (less than 7 days)
  bool get isNewUser {
    final age = accountAgeInDays;
    return age != null && age < 7;
  }

  // Check if user is active (signed in within last 30 days)
  bool get isActiveUser {
    final lastSignIn = this.lastSignIn;
    if (lastSignIn == null) return false;
    return DateTime.now().difference(lastSignIn as DateTime).inDays < 30;
  }

  // Get user activity status
  String get activityStatus {
    if (!isAuthenticated) return 'offline';
    if (!isActiveUser) return 'inactive';
    return 'active';
  }
}
