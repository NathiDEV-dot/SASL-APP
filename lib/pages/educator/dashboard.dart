// ignore_for_file: deprecated_member_use, unused_field, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/dashboard_service.dart';
import 'content_management.dart';
import 'live_session.dart';
import 'review_submissions.dart';
import 'student_list.dart';
import 'lesson_creation.dart';

class EducatorDashboard extends StatefulWidget {
  const EducatorDashboard({super.key});

  @override
  State<EducatorDashboard> createState() => _EducatorDashboardState();
}

class _EducatorDashboardState extends State<EducatorDashboard> {
  int _currentIndex = 0;
  Map<String, dynamic>? _educatorData;
  bool _isLoading = true;
  String? _errorMessage;
  late final DashboardService _dashboardService;
  List<Map<String, dynamic>> _recentActivity = [];

  // Professional color palette
  final Color _primaryColor = const Color(0xFF4361EE);
  final Color _secondaryColor = const Color(0xFF3A0CA3);
  final Color _accentColor = const Color(0xFF4CC9F0);
  final Color _successColor = const Color(0xFF4ADE80);
  final Color _warningColor = const Color(0xFFF59E0B);
  final Color _errorColor = const Color(0xFFEF4444);
  final Color _infoColor = const Color(0xFF06B6D4);

  @override
  void initState() {
    super.initState();
    _dashboardService = DashboardService();
    _loadEducatorData();
  }

  Future<void> _loadEducatorData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        debugPrint('👤 Loading dashboard for user: ${user.id}');

        // Load main educator data
        final data = await _dashboardService.getEducatorData(user.id);

        // Load recent activity
        final activity = await _dashboardService.getRecentActivity(user.id);

        setState(() {
          _educatorData = data;
          _recentActivity = activity;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No user logged in. Please sign in again.';
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading educator data: $e');

      String errorMessage = 'Failed to load dashboard data';
      if (e.toString().contains('Invalid input syntax for type uuid')) {
        errorMessage = 'Account configuration issue. Please contact support.';
      } else if (e.toString().contains('JWT')) {
        errorMessage = 'Session expired. Please sign in again.';
      } else if (e.toString().contains('connection')) {
        errorMessage = 'Network connection failed. Please check your internet.';
      }

      setState(() {
        _isLoading = false;
        _errorMessage = errorMessage;
      });
    }
  }

  // Navigation methods
  void _navigateToContentManagement() {
    setState(() => _currentIndex = 1);
  }

  void _navigateToCreateLesson() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LessonCreation(),
      ),
    );
  }

  void _navigateToStudentList() {
    if (_educatorData != null) {
      final students = _educatorData!['all_students'] as List<dynamic>;
      final educator = _educatorData!['educator'];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudentList(
            students: students,
            educatorName: '${educator['first_name']} ${educator['last_name']}',
          ),
        ),
      );
    }
  }

  void _navigateToClassesList() {
    if (_educatorData != null) {
      final classesByGrade =
          _educatorData!['classes_by_grade'] as Map<String, dynamic>;
      _showClassesDialog(classesByGrade);
    }
  }

  void _showClassesDialog(Map<String, dynamic> classesByGrade) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('My Classes'),
        content: SizedBox(
          width: double.maxFinite,
          child: classesByGrade.isEmpty
              ? const Text('No classes found for your grade.')
              : ListView(
                  shrinkWrap: true,
                  children: classesByGrade.keys.map((grade) {
                    final classes = classesByGrade[grade] as List<dynamic>;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          grade,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...classes
                            .map((classData) => ListTile(
                                  leading: const Icon(Icons.class_rounded),
                                  title: Text(classData['subject'] ??
                                      'Unknown Subject'),
                                  subtitle: Text(
                                      '${classData['student_count'] ?? 0} students'),
                                  trailing: const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16),
                                ))
                            .toList(),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _getBackgroundColor(isDark),
      appBar: _buildAppBar(isDark),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(isDark),
    );
  }

  AppBar _buildAppBar(bool isDark) {
    return AppBar(
      title: Text(
        'Educator Dashboard',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: _getTextColor(isDark),
          letterSpacing: -0.5,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: _getTextColor(isDark)),
          onPressed: _loadEducatorData,
          tooltip: 'Refresh',
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: _getTextColor(isDark)),
          onSelected: (value) {
            if (value == 'logout') {
              _handleLogout();
            } else if (value == 'support') {
              _showSupportDialog();
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem<String>(
              value: 'support',
              child: Row(
                children: [
                  Icon(Icons.help_outline_rounded),
                  SizedBox(width: 8),
                  Text('Get Help'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded),
                  SizedBox(width: 8),
                  Text('Sign Out'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Need Help?'),
        content: const Text(
          'If you\'re experiencing issues with your dashboard, please contact support with your educator details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _getCurrentBody(),
    );
  }

  Widget _getCurrentBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return const ContentManagement();
      case 2:
        return const LiveSession();
      case 3:
        return const ReviewSubmissions();
      default:
        return _buildHomeTab();
    }
  }

  // Missing methods - Add these
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: _getTextColor(),
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildHomeTab() {
    if (_educatorData == null && !_isLoading) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHeader(),
          const SizedBox(height: 24),
          _buildSectionHeader('Dashboard Overview'),
          const SizedBox(height: 16),
          _buildStatsGrid(),
          const SizedBox(height: 24),
          _buildSectionHeader('Quick Actions'),
          const SizedBox(height: 16),
          _buildQuickActions(),
          const SizedBox(height: 24),
          _buildSectionHeader('Recent Activity'),
          const SizedBox(height: 16),
          _buildRecentActivity(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    if (_isLoading) {
      return _buildLoadingWelcomeHeader();
    }

    if (_educatorData == null) {
      return _buildErrorWelcomeHeader();
    }

    final educator = _educatorData!['educator'];
    final stats = _educatorData!['stats'];
    final subjects = _educatorData!['subjects'] as List<String>;
    final grades = _educatorData!['grades_taught'] as List<String>;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getWelcomeGradientStart(),
            _getWelcomeGradientEnd(),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getBorderColor()),
      ),
      child: Row(
        children: [
          // Educator Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // Educator Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${educator['first_name']} ${educator['last_name']}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _getTextColor(),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${subjects.length} ${subjects.length == 1 ? 'Subject' : 'Subjects'} • ${grades.isEmpty ? 'All Grades' : grades.join(", ")}',
                  style: TextStyle(
                    fontSize: 14,
                    color: _getSecondaryTextColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Total Lessons Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: _primaryColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${stats['total_lessons']} Lessons',
                        style: TextStyle(
                          fontSize: 12,
                          color: _primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // Students Badge
                    if (stats['total_students'] > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getSuccessBackgroundColor(),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getSuccessBorderColor()),
                        ),
                        child: Text(
                          '${stats['total_students']} Students',
                          style: TextStyle(
                            fontSize: 12,
                            color: _successColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    // Classes Badge
                    if (stats['total_classes'] > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: _accentColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          '${stats['total_classes']} Classes',
                          style: TextStyle(
                            fontSize: 12,
                            color: _accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWelcomeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getBorderColor()),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _errorColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _errorColor.withOpacity(0.3)),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: _errorColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unable to Load Profile',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _getTextColor(),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please check your connection and try again',
                  style: TextStyle(
                    fontSize: 14,
                    color: _getSecondaryTextColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loadEducatorData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    if (_isLoading || _educatorData == null) {
      return _buildLoadingStats();
    }

    final stats = _educatorData!['stats'];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        // Total Students Card
        _buildStatCard(
          Icons.people_alt_rounded,
          '${stats['total_students']}',
          'Total Students',
          const [Color(0xFFF59E0B), Color(0xFFD97706)],
          onTap: _navigateToStudentList,
        ),

        // Total Classes Card
        _buildStatCard(
          Icons.school_rounded,
          '${stats['total_classes']}',
          'Total Classes',
          const [Color(0xFF4CC9F0), Color(0xFF0891B2)],
          onTap: _navigateToClassesList,
        ),

        // Published Lessons Card
        _buildStatCard(
          Icons.video_library_rounded,
          '${stats['published_lessons']}',
          'Published Lessons',
          const [Color(0xFF4361EE), Color(0xFF3A0CA3)],
          onTap: _navigateToContentManagement,
        ),

        // Total Lessons Card
        _buildStatCard(
          Icons.assignment_rounded,
          '${stats['total_lessons']}',
          'Total Lessons',
          const [Color(0xFF4ADE80), Color(0xFF16A34A)],
          onTap: _navigateToContentManagement,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      IconData icon, String value, String label, List<Color> gradientColors,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _getCardColor(),
            boxShadow: [
              BoxShadow(
                color: _getShadowColor(),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: _getBorderColor()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),

                // Value and Label
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _getTextColor(),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: _getSecondaryTextColor(),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      QuickAction(
        'Create New Lesson',
        Icons.add_circle_rounded,
        _primaryColor,
        onTap: _navigateToCreateLesson,
      ),
      QuickAction(
        'Manage Content',
        Icons.folder_open_rounded,
        _warningColor,
        onTap: _navigateToContentManagement,
      ),
      QuickAction(
        'Schedule Live Session',
        Icons.live_tv_rounded,
        _errorColor,
        onTap: () => setState(() => _currentIndex = 2),
      ),
      QuickAction(
        'Review Submissions',
        Icons.rate_review_rounded,
        _successColor,
        onTap: () => setState(() => _currentIndex = 3),
      ),
    ];

    return Column(
      children: actions.map((action) => _buildQuickActionItem(action)).toList(),
    );
  }

  Widget _buildQuickActionItem(QuickAction action) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _getBorderColor()),
            ),
            child: Row(
              children: [
                // Action Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getActionIconBackgroundColor(action.color),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _getActionIconBorderColor(action.color)),
                  ),
                  child: Icon(action.icon, color: action.color, size: 24),
                ),
                const SizedBox(width: 16),

                // Action Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _getTextColor(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to navigate',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getHintColor(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Chevron
                Icon(Icons.arrow_forward_ios_rounded,
                    color: _getHintColor(), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (_recentActivity.isEmpty) {
      return _buildEmptyActivity();
    }

    return Column(
      children: _recentActivity
          .map((activity) => _buildActivityItem(activity))
          .toList(),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: activity['onTap'] as VoidCallback?,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getBorderColor()),
            ),
            child: Row(
              children: [
                // Activity Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getActivityIconBackgroundColor(
                        activity['color'] as Color),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    activity['icon'] as IconData? ?? Icons.info_rounded,
                    color: activity['color'] as Color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Activity Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity['title'] as String? ?? 'Activity',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _getTextColor(),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity['subtitle'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getSecondaryTextColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity['time'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: _getHintColor(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Chevron (if tappable)
                if (activity['onTap'] != null)
                  Icon(Icons.chevron_right_rounded,
                      color: _getHintColor(), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getBorderColor()),
      ),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 48, color: _getHintColor()),
          const SizedBox(height: 12),
          Text(
            'No Recent Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _getTextColor(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your recent lessons and activities will appear here',
            style: TextStyle(
              fontSize: 14,
              color: _getSecondaryTextColor(),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Loading States
  Widget _buildLoadingWelcomeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getBorderColor()),
      ),
      child: Row(
        children: [
          // Loading avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _getHintColor().withOpacity(0.3),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 150,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _getHintColor().withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                ),
                Container(
                  width: 200,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _getHintColor().withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                ),
                Container(
                  width: 120,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _getHintColor().withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingStats() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: List.generate(
          4,
          (index) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _getCardColor(),
                ),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _primaryColor),
          const SizedBox(height: 16),
          Text(
            'Loading Dashboard...',
            style: TextStyle(
              fontSize: 16,
              color: _getTextColor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 80, color: _errorColor),
          const SizedBox(height: 24),
          Text(
            'Unable to Load Dashboard',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _getTextColor(),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _errorColor.withOpacity(0.3)),
            ),
            child: Text(
              _errorMessage ?? 'Unknown error occurred',
              style: TextStyle(
                fontSize: 14,
                color: _getTextColor(),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _loadEducatorData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Try Again'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _handleLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _errorColor,
                  side: BorderSide(color: _errorColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_rounded, size: 64, color: _getHintColor()),
          const SizedBox(height: 16),
          Text(
            'No Data Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _getTextColor(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unable to load educator data',
            style: TextStyle(
              fontSize: 14,
              color: _getSecondaryTextColor(),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadEducatorData,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // Bottom Navigation Bar
  BottomNavigationBar _buildBottomNavigationBar(bool isDark) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      type: BottomNavigationBarType.fixed,
      backgroundColor: _getCardColor(isDark),
      selectedItemColor: _primaryColor,
      unselectedItemColor: _getHintColor(isDark),
      selectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      elevation: 8,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_rounded),
          activeIcon: Icon(Icons.dashboard_rounded),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.video_library_rounded),
          activeIcon: Icon(Icons.video_library_rounded),
          label: 'Content',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.live_tv_rounded),
          activeIcon: Icon(Icons.live_tv_rounded),
          label: 'Live',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.rate_review_rounded),
          activeIcon: Icon(Icons.rate_review_rounded),
          label: 'Review',
        ),
      ],
    );
  }

  // Color Helper Methods
  Color _getBackgroundColor([bool? isDark]) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF0F0F1E) : const Color(0xFFF5F7FA);
  }

  Color _getTextColor([bool? isDark]) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    return dark ? Colors.white : const Color(0xFF1A202C);
  }

  Color _getSecondaryTextColor([bool? isDark]) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFFA0AEC0) : const Color(0xFF718096);
  }

  Color _getHintColor([bool? isDark]) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF718096) : const Color(0xFFA0AEC0);
  }

  Color _getCardColor([bool? isDark]) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF1E1E2E) : Colors.white;
  }

  Color _getBorderColor([bool? isDark]) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);
  }

  Color _getShadowColor([bool? isDark]) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    return dark
        ? Colors.black.withOpacity(0.4)
        : Colors.black.withOpacity(0.08);
  }

  Color _getWelcomeGradientStart() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const Color(0xFF1E3A8A).withOpacity(0.3)
        : const Color(0xFF4361EE).withOpacity(0.15);
  }

  Color _getWelcomeGradientEnd() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const Color(0xFF0EA5E9).withOpacity(0.15)
        : const Color(0xFF4CC9F0).withOpacity(0.08);
  }

  Color _getSuccessBackgroundColor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
  }

  Color _getSuccessBorderColor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF047857) : const Color(0xFF86EFAC);
  }

  Color _getActionIconBackgroundColor(Color baseColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? _darkenColor(baseColor, 0.8)
        : _lightenColor(baseColor, 0.9);
  }

  Color _getActionIconBorderColor(Color baseColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? _darkenColor(baseColor, 0.6)
        : _lightenColor(baseColor, 0.7);
  }

  Color _getActivityIconBackgroundColor(Color baseColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? _darkenColor(baseColor, 0.85)
        : _lightenColor(baseColor, 0.95);
  }

  Color _darkenColor(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red * factor).round(),
      (color.green * factor).round(),
      (color.blue * factor).round(),
    );
  }

  Color _lightenColor(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red + (255 - color.red) * factor).round(),
      (color.green + (255 - color.green) * factor).round(),
      (color.blue + (255 - color.blue) * factor).round(),
    );
  }
}

// Helper Classes
class QuickAction {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const QuickAction(this.title, this.icon, this.color, {this.onTap});
}

class ActivityItem {
  final String title;
  final String time;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const ActivityItem(this.title, this.time, this.icon, this.color,
      {this.onTap});
}
