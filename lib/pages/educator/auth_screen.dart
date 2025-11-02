// lib/pages/educator/auth_screen.dart
// ignore_for_file: deprecated_member_use

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

  void _fillDemoCredentials() {
    setState(() {
      _emailController.text = 'zanele.mthembu@transorange.school.za';
      _passwordController.text = 'Educator123!';
      _confirmPasswordController.text = 'Educator123!';
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isSignUpMode ? 'Educator Sign Up' : 'Educator Login',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getCardColor(),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 32),
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
                          const SizedBox(height: 20),
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
                          const SizedBox(height: 20),
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
                            const SizedBox(height: 20),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed:
                                  _isLoading ? null : _fillDemoCredentials,
                              icon: const Icon(Icons.visibility_rounded,
                                  size: 18),
                              label: const Text('Fill Demo Credentials'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF667EEA),
                                side:
                                    const BorderSide(color: Color(0xFF667EEA)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              _isSignUpMode
                                  ? 'Create your educator account using your pre-registered school email'
                                  : 'Sign in to your educator account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: _getTextColor().withOpacity(0.7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          _buildSubmitButton(),
                          const SizedBox(height: 20),
                          _buildToggleAuthMode(),
                          const SizedBox(height: 30),
                          _buildEducatorAccountsInfo(),
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
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667EEA).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child:
              const Icon(Icons.school_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 20),
        Text(
          _isSignUpMode ? 'Educator Sign Up' : 'Educator Portal',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: _getTextColor(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _isSignUpMode
              ? 'Create your account to access your teaching dashboard'
              : 'Access your teaching dashboard and manage your classes',
          style: TextStyle(
            fontSize: 16,
            color: _getTextColor().withOpacity(0.7),
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
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
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
              prefixIcon: Icon(icon, color: _getIconColor()),
              suffixIcon: suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _getBorderColor()),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _getBorderColor()),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF667EEA), width: 2),
              ),
              filled: true,
              fillColor: _getTextFieldBackgroundColor(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: TextStyle(color: _getTextColor(), fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF667EEA),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _isSignUpMode ? 'Create Account' : 'Sign In',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEducatorAccountsInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isSignUpMode ? Icons.person_add_rounded : Icons.info_rounded,
                color: Colors.blue,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _isSignUpMode
                    ? 'Pre-registered Educators'
                    : 'Educator Accounts',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isSignUpMode
                ? 'Use your pre-registered school email to create your account'
                : 'All educators use password: Educator123!',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildEducatorChip('Grade 1: Zanele Mthembu'),
              _buildEducatorChip('Grade 2: Johan Venter'),
              _buildEducatorChip('Grade 3: Lerato Moloi'),
              _buildEducatorChip('Grade 4: Sarah Ndlovu'),
              _buildEducatorChip('Grade 5: Thabo Mokoena'),
              _buildEducatorChip('Grade 6: Nadia van Wyk'),
              _buildEducatorChip('Grade 7: Bongani Zulu'),
              _buildEducatorChip('Grade 8: Maria Botha'),
              _buildEducatorChip('Grade 9: Sipho Khumalo'),
              _buildEducatorChip('Grade 10: Annelise de Wet'),
              _buildEducatorChip('Grade 11: Kgosi Malema'),
              _buildEducatorChip('Grade 12: Elizabeth Smith'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEducatorChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: Colors.blue[800],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Color methods
  Color _getTextFieldBackgroundColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2D2D3E)
        : const Color(0xFFF0F4F8);
  }

  Color _getTextColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF2D3748);
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
