// lib/pages/educator/auth_screen.dart
// ignore_for_file: deprecated_member_use, prefer_const_constructors, unused_element

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signsync_academy/core/services/auth_service.dart';

class EducatorAuthScreen extends StatefulWidget {
  const EducatorAuthScreen({super.key});

  @override
  State<EducatorAuthScreen> createState() => _EducatorAuthScreenState();
}

class _EducatorAuthScreenState extends State<EducatorAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSignUpMode = true;

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }

  void _navigateToWelcomeScreen() {
    Navigator.pushReplacementNamed(context, '/welcome');
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (_isSignUpMode) {
          await _educatorSignUp();
        } else {
          await _educatorLogin();
        }
      } catch (e) {
        String errorMessage = e.toString().replaceAll('Exception: ', '');

        if (errorMessage.contains('already exists')) {
          _showErrorWithAction(
            'An account already exists. Would you like to sign in instead?',
            () {
              setState(() {
                _isSignUpMode = false;
              });
            },
          );
        } else {
          _showError(errorMessage);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _educatorSignUp() async {
    debugPrint('🔄 Starting educator signup for: ${_emailController.text}');

    final authResponse = await _authService.educatorSignUp(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (authResponse != null && authResponse.user != null) {
      _showSuccess(
          'Account created successfully! Welcome to SignSync Academy.');

      // Link educator to their classes
      await _linkEducatorToClasses(authResponse.user!.id);

      // Navigate to dashboard
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/educator/dashboard');
      }
    }
  }

  Future<void> _educatorLogin() async {
    final authResponse = await _authService.educatorLogin(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (authResponse != null && authResponse.user != null) {
      // Use the correct method name: getEducatorProfileById
      final educatorInfo =
          await _authService.getEducatorProfileById(authResponse.user!.id);
      final educatorName = educatorInfo != null
          ? '${educatorInfo['first_name']} ${educatorInfo['last_name']}'
          : 'Educator';

      _showSuccess('Welcome back, $educatorName!');

      // Navigate to dashboard immediately
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/educator/dashboard');
      }
    }
  }

  Future<void> _linkEducatorToClasses(String educatorId) async {
    try {
      await Supabase.instance.client.from('classes').update({
        'educator_id': educatorId,
      }).eq('grade', _getEducatorGradeFromEmail());

      debugPrint(
          '✅ Educator linked to classes for grade: ${_getEducatorGradeFromEmail()}');
    } catch (e) {
      debugPrint('⚠️ Could not link educator to classes: $e');
    }
  }

  String _getEducatorGradeFromEmail() {
    final email = _emailController.text.trim();
    if (email.contains('zanele.mthembu')) return 'Grade 1';
    if (email.contains('johan.venter')) return 'Grade 2';
    if (email.contains('lerato.moloi')) return 'Grade 3';
    if (email.contains('sarah.ndlovu')) return 'Grade 4';
    if (email.contains('thabo.mokoena')) return 'Grade 5';
    if (email.contains('nadia.vanwyk')) return 'Grade 6';
    if (email.contains('bongani.zulu')) return 'Grade 7';
    if (email.contains('maria.botha')) return 'Grade 8';
    if (email.contains('sipho.khumalo')) return 'Grade 9';
    if (email.contains('annelise.dewet')) return 'Grade 10';
    if (email.contains('kgosi.malema')) return 'Grade 11';
    if (email.contains('elizabeth.smith')) return 'Grade 12';
    return 'Grade 1';
  }

  void _toggleAuthMode() {
    setState(() {
      _isSignUpMode = !_isSignUpMode;
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorWithAction(String message, VoidCallback action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(child: Text(message)),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                action();
              },
              child: const Text(
                'SIGN IN',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF667EEA),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // Enhanced Header with better back button
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: _navigateToWelcomeScreen,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _isSignUpMode ? 'Educator Sign Up' : 'Educator Login',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _getCardColor(),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 40),
                          _buildTextFieldWithIcon(
                            controller: _emailController,
                            label: 'School Email',
                            hintText: 'your.name@transorange.school.za',
                            icon: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Please enter your school email';
                              }
                              if (!value.endsWith('@transorange.school.za')) {
                                return 'Please use your school email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          _buildTextFieldWithIcon(
                            controller: _passwordController,
                            label: 'Password',
                            hintText: 'Enter your password',
                            icon: Icons.lock_rounded,
                            isPassword: _obscurePassword,
                            textInputAction: _isSignUpMode
                                ? TextInputAction.next
                                : TextInputAction.done,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: _getIconColor(),
                              ),
                              onPressed: _togglePasswordVisibility,
                            ),
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          if (_isSignUpMode) ...[
                            _buildTextFieldWithIcon(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password',
                              hintText: 'Confirm your password',
                              icon: Icons.lock_outline_rounded,
                              isPassword: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: _getIconColor(),
                                ),
                                onPressed: _toggleConfirmPasswordVisibility,
                              ),
                              validator: (value) {
                                if (value!.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                          // Enhanced Info Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667EEA).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF667EEA).withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: const Color(0xFF667EEA),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _isSignUpMode
                                        ? 'Use your pre-registered school email to create your educator account'
                                        : 'Sign in with your school credentials',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _getTextColor().withOpacity(0.8),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildSubmitButton(),
                          const SizedBox(height: 24),
                          _buildToggleAuthMode(),
                          const SizedBox(height: 32),
                          // Security Info Section
                          _buildSecurityInfo(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Enhanced Hero Icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667EEA).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.school_rounded,
            color: Colors.white,
            size: 50,
          ),
        ),
        const SizedBox(height: 28),
        // Enhanced Title
        Text(
          _isSignUpMode ? 'Educator Sign Up' : 'Educator Portal',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: _getTextColor(),
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        // Enhanced Subtitle
        Text(
          _isSignUpMode
              ? 'Create your account to access your teaching dashboard and manage classes'
              : 'Access your teaching dashboard and manage your classes',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: _getTextColor().withOpacity(0.7),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldWithIcon({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    bool isPassword = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _getTextColor(),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            obscureText: isPassword,
            validator: validator,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: _getHintColor()),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                child: Icon(icon, color: _getIconColor(), size: 24),
              ),
              suffixIcon: suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF667EEA),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: _getTextFieldBackgroundColor(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
            style: TextStyle(
              color: _getTextColor(),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667EEA).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _isLoading
            ? Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF667EEA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              )
            : ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isSignUpMode
                          ? Icons.person_add_rounded
                          : Icons.login_rounded,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isSignUpMode ? 'Create Account' : 'Sign In',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildToggleAuthMode() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isSignUpMode
              ? 'Already have an account?'
              : 'Need to create an account?',
          style: TextStyle(
            color: _getTextColor().withOpacity(0.7),
            fontSize: 15,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _isLoading ? null : _toggleAuthMode,
          child: Text(
            _isSignUpMode ? 'Sign In' : 'Sign Up',
            style: const TextStyle(
              color: Color(0xFF667EEA),
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF667EEA).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF667EEA).withOpacity(0.2),
        ),
      ),
      child: const Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.security_rounded,
                color: Color(0xFF667EEA),
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Secure Educator Access',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF667EEA),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Your school email ensures secure access to the educator portal with appropriate permissions and class management capabilities.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF667EEA),
              height: 1.4,
            ),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }

  // Color methods
  Color _getTextFieldBackgroundColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2D2D3E)
        : const Color(0xFFF8FAFC);
  }

  Color _getTextColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1A202C);
  }

  Color _getCardColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E1E2E)
        : Colors.white;
  }

  Color _getBorderColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3D3D4E)
        : const Color(0xFFE2E8F0);
  }

  Color _getHintColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF888888)
        : const Color(0xFF718096);
  }

  Color _getIconColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF888888)
        : const Color(0xFF718096);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
