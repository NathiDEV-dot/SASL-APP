// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:signsync_academy/core/services/student_service.dart';
import 'package:signsync_academy/pages/student/lesson_viewer.dart';
import 'package:signsync_academy/pages/student/homework_submission.dart';
import 'package:signsync_academy/pages/student/live_session.dart';
import 'dart:developer' as developer;

class StudentDashboard extends StatefulWidget {
  final Map<String, dynamic> studentData;

  const StudentDashboard({super.key, required this.studentData});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;
  final StudentService _studentService = StudentService();
  final String _loggerName = 'StudentDashboard';

  // Data states
  Map<String, dynamic> _studentProgress = {};
  List<Map<String, dynamic>> _newestLessons = [];
  List<Map<String, dynamic>> _recommendedLessons = [];
  List<Map<String, dynamic>> _popularLessons = [];
  List<Map<String, dynamic>> _gradeLessons = [];
  List<String> _gradeSubjects = [];
  List<Map<String, dynamic>> _homeworkAssignments = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Student info
  late Map<String, dynamic> _studentInfo;
  late String _studentCode;
  late String _grade;

  // Progress tracking
  Map<String, String> _homeworkAnswers = {};
  final Map<String, bool> _homeworkCompletion = {};
  final Map<String, bool> _lessonCompletion = {};
  int _totalLessons = 10; // Default total lessons
  int _completedLessons = 0;

  @override
  void initState() {
    super.initState();

    _studentInfo =
        (widget.studentData['student_info'] as Map<String, dynamic>?) ?? {};
    _studentCode = _studentInfo['student_code']?.toString() ?? 'unknown';
    _grade = _studentInfo['grade']?.toString() ?? 'unknown';

    _loadStudentData();
    _loadHomeworkData();
    _calculateProgress();
  }

  Future<void> _loadStudentData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final results = await Future.wait([
        _studentService.getStudentProgress(_studentCode),
        _studentService.getNewestLessons(_grade, limit: 10),
        _studentService.getRecommendedLessons(_studentCode, _grade),
        _studentService.getPopularLessons(_grade, limit: 5),
        _studentService.getLessonsByGrade(_grade),
        _studentService.getSubjectsByGrade(_grade),
      ], eagerError: true);

      if (results.length == 6) {
        setState(() {
          _studentProgress = results[0] as Map<String, dynamic>? ?? {};
          _newestLessons = results[1] as List<Map<String, dynamic>>? ?? [];
          _recommendedLessons = results[2] as List<Map<String, dynamic>>? ?? [];
          _popularLessons = results[3] as List<Map<String, dynamic>>? ?? [];
          _gradeLessons = results[4] as List<Map<String, dynamic>>? ?? [];
          _gradeSubjects = results[5] as List<String>? ?? [];
          _isLoading = false;
        });

        // Calculate total lessons from loaded data
        _totalLessons = _newestLessons.length +
            _recommendedLessons.length +
            _popularLessons.length +
            _gradeLessons.length;
        _calculateProgress();
      }
    } catch (e) {
      _logError('Failed to load student dashboard data', e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load data. Please try again.';
      });
    }
  }

  // ADDED: Missing homework data loading method
  Future<void> _loadHomeworkData() async {
    try {
      final homeworkData =
          await _studentService.getHomeworkAssignments(_studentCode);
      setState(() {
        _homeworkAssignments = homeworkData;
      });
    } catch (e) {
      _logError('Failed to load homework data', e);
    }
  }

  // ADDED: Missing progress calculation method
  void _calculateProgress() {
    int completed = 0;

    // Calculate completed lessons based on completion status
    for (var lesson in _newestLessons) {
      if (_lessonCompletion[lesson['id']] == true) completed++;
    }
    for (var lesson in _recommendedLessons) {
      if (_lessonCompletion[lesson['id']] == true) completed++;
    }
    for (var lesson in _popularLessons) {
      if (_lessonCompletion[lesson['id']] == true) completed++;
    }
    for (var lesson in _gradeLessons) {
      if (_lessonCompletion[lesson['id']] == true) completed++;
    }

    // Calculate completed homework
    for (var homework in _homeworkAssignments) {
      if (_homeworkCompletion[homework['id']] == true) completed++;
    }

    setState(() {
      _completedLessons = completed;
    });
  }

  // ADDED: Helper method to check if a lesson is completed
  bool _isLessonCompleted(Map<String, dynamic> lesson) {
    return _lessonCompletion[lesson['id']] == true;
  }

  void _navigateToLesson(Map<String, dynamic> lesson) {
    if (lesson.isEmpty) {
      _logWarning('Attempted to navigate to empty lesson');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LessonViewer(
          lesson: lesson,
          studentCode: _studentCode,
        ),
      ),
    );
  }

  void _showProfile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildProfileSheet(),
    );
  }

  void _logout() {
    _logInfo('User logging out');
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
  }

  Future<void> _refreshData() async {
    await _loadStudentData();
    await _loadHomeworkData();
  }

  // Homework Methods
  void _navigateToHomework(Map<String, dynamic> homework) {
    _logInfo('Navigating to homework: ${homework['title']}');

    if (homework['id'] == 'sasl_hl_p1_2023') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SASLHomeworkPage(
            homework: homework,
            answers: _homeworkAnswers,
            onAnswersUpdate: (Map<String, String> updatedAnswers) {
              setState(() {
                _homeworkAnswers = updatedAnswers;
                _homeworkCompletion[homework['id']] = true;
                _calculateProgress(); // Update progress when homework is completed
              });
            },
          ),
        ),
      );
    }
  }

  // Private logging methods
  void _logError(String message, dynamic error) {
    developer.log(message, error: error, name: _loggerName, level: 1000);
  }

  void _logInfo(String message) {
    developer.log(message, name: _loggerName, level: 800);
  }

  void _logWarning(String message) {
    developer.log(message, name: _loggerName, level: 900);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _buildCurrentTab(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        _getAppBarTitle(),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _getTextColor(),
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      actions: _currentIndex == 0 ? [_buildProfileButton()] : null,
    );
  }

  Widget _buildProfileButton() {
    return IconButton(
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF45a049)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 20),
      ),
      onPressed: _showProfile,
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'My Learning';
      case 1:
        return 'Lessons';
      case 2:
        return 'Homework';
      case 3:
        return 'Live Sessions';
      default:
        return 'My Learning';
    }
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildLessonsTab();
      case 2:
        return _buildHomeworkTab();
      case 3:
        return _buildLiveTab();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildWelcomeSection(),
            const SizedBox(height: 24),

            // Progress Cards Grid - COMPLETELY FIXED OVERFLOW
            _buildProgressCards(),
            const SizedBox(height: 24),

            // Quick Access Section
            _buildQuickAccessSection(),
            const SizedBox(height: 24),

            // Continue Learning
            if (_newestLessons.isNotEmpty) ...[
              _buildSectionHeader('Continue Learning', 'See All', () {
                setState(() => _currentIndex = 1);
              }),
              const SizedBox(height: 16),
              _buildLessonList(_newestLessons.take(2).toList()),
              const SizedBox(height: 24),
            ],

            // Recommended for You
            if (_recommendedLessons.isNotEmpty) ...[
              _buildSectionHeader('Recommended for You', 'View All', () {
                setState(() => _currentIndex = 1);
              }),
              const SizedBox(height: 16),
              _buildLessonGrid(_recommendedLessons.take(4).toList()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome Back, ${_studentInfo['first_name']?.toString() ?? 'Student'}!',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ready to learn something new today?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Grade $_grade',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCards() {
    final progress = _studentProgress['progress_percentage'] ?? 0;
    final completed = _studentProgress['completed_lessons'] ?? 0;
    final total = _studentProgress['total_lessons'] ?? 0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2, // Optimized aspect ratio
      children: [
        _buildProgressCard(
          'Learning Progress',
          '$progress%',
          Icons.trending_up,
          const Color(0xFF4CAF50),
          const Color(0xFFE8F5E8),
          '$completed/$total lessons',
        ),
        _buildProgressCard(
          'Active Lessons',
          '${_newestLessons.length}',
          Icons.play_circle_filled,
          const Color(0xFF2196F3),
          const Color(0xFFE3F2FD),
          'Lessons to explore',
        ),
        _buildProgressCard(
          'Subjects',
          '${_gradeSubjects.length}',
          Icons.menu_book,
          const Color(0xFF9C27B0),
          const Color(0xFFF3E5F5),
          'Available subjects',
        ),
        _buildProgressCard(
          'This Week',
          '${_studentProgress['weekly_study_time'] ?? '0'}h',
          Icons.access_time,
          const Color(0xFFFF9800),
          const Color(0xFFFFF3E0),
          'Time studied',
        ),
      ],
    );
  }

  Widget _buildProgressCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
    Color cardColor,
    String subtitle,
  ) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 120,
        maxHeight: 140,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              MainAxisAlignment.center, // Center content vertically
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32, // Smaller icon container
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18), // Smaller icon
                ),
                if (title == 'Learning Progress' &&
                    int.tryParse(value.replaceAll('%', '')) != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16, // Smaller main value
                fontWeight: FontWeight.bold,
                color: _getTextColor(),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getTextColor().withOpacity(0.8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: _getTextColor().withOpacity(0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Quick Access', '', () {}),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9, // Better aspect ratio for quick access
          children: [
            _buildQuickAccessItem(
                'Lessons', Icons.video_library, const Color(0xFF4CAF50), () {
              setState(() => _currentIndex = 1);
            }),
            _buildQuickAccessItem(
                'Homework', Icons.assignment, const Color(0xFF2196F3), () {
              setState(() => _currentIndex = 2);
            }),
            _buildQuickAccessItem(
                'Live', Icons.live_tv, const Color(0xFFE91E63), () {
              setState(() => _currentIndex = 3);
            }),
            _buildQuickAccessItem(
                'Subjects', Icons.subject, const Color(0xFFFF9800), () {
              _showSubjects();
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAccessItem(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 80,
          maxHeight: 90,
        ),
        decoration: BoxDecoration(
          color: _getCardColor(),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: _getTextColor(),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      String title, String actionText, VoidCallback onAction) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18, // Slightly smaller
            fontWeight: FontWeight.w700,
            color: _getTextColor(),
          ),
        ),
        if (actionText.isNotEmpty)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                actionText,
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLessonList(List<Map<String, dynamic>> lessons) {
    return Column(
      children: lessons.map((lesson) => _buildLessonCard(lesson)).toList(),
    );
  }

  Widget _buildLessonCard(Map<String, dynamic> lesson) {
    final educator = lesson['profiles'] as Map<String, dynamic>?;
    final educatorName = educator != null
        ? '${educator['first_name'] ?? ''} ${educator['last_name'] ?? ''}'
            .trim()
        : 'Unknown Educator';

    final subject = lesson['subject']?.toString() ?? 'General';
    final title = lesson['title']?.toString() ?? 'Untitled Lesson';
    final thumbnailUrl = lesson['thumbnail_url']?.toString();

    // Fix duration handling - your database uses 'duration' in seconds
    final durationSeconds = (lesson['duration'] as num?)?.toInt() ?? 0;
    final durationMinutes = (durationSeconds / 60).ceil();

    final views = (lesson['view_count'] as num?)?.toInt();
    final grade = lesson['grade']?.toString() ?? 'Unknown Grade';
    final isCompleted =
        _isLessonCompleted(lesson); // FIXED: Use the helper method

    return GestureDetector(
      onTap: () => _navigateToLesson(lesson),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(
          minHeight: 100,
          maxHeight: 120,
        ),
        decoration: BoxDecoration(
          color: _getCardColor(),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isCompleted ? const Color(0xFF4CAF50) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail/Icon Container
            Container(
              width: 80, // Smaller thumbnail
              height: 100,
              decoration: BoxDecoration(
                color: _getSubjectColor(subject).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                      child: Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              _getSubjectIcon(subject),
                              color: _getSubjectColor(subject),
                              size: 24,
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Icon(
                        _getSubjectIcon(subject),
                        color: _getSubjectColor(subject),
                        size: 24,
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Lesson Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Subject Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getSubjectColor(subject).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        subject,
                        style: TextStyle(
                          fontSize: 9,
                          color: _getSubjectColor(subject),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _getTextColor(),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Educator
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 12,
                          color: _getTextColor().withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            educatorName,
                            style: TextStyle(
                              fontSize: 11,
                              color: _getTextColor().withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Metadata
                    Row(
                      children: [
                        // Duration
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 10,
                              color: _getTextColor().withOpacity(0.5),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$durationMinutes min',
                              style: TextStyle(
                                fontSize: 10,
                                color: _getTextColor().withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 8),

                        // Grade
                        Row(
                          children: [
                            Icon(
                              Icons.grade,
                              size: 10,
                              color: _getTextColor().withOpacity(0.5),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              grade,
                              style: TextStyle(
                                fontSize: 10,
                                color: _getTextColor().withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Views (if available)
                        if (views != null)
                          Text(
                            '$views views',
                            style: TextStyle(
                              fontSize: 10,
                              color: _getTextColor().withOpacity(0.6),
                            ),
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
    );
  }

  Widget _buildLessonGrid(List<Map<String, dynamic>> lessons) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8, // Better aspect ratio
      ),
      itemCount: lessons.length,
      itemBuilder: (context, index) {
        final lesson = lessons[index];
        return _buildLessonGridCard(lesson);
      },
    );
  }

  Widget _buildLessonGridCard(Map<String, dynamic> lesson) {
    final subject = lesson['subject']?.toString() ?? 'General';
    final title = lesson['title']?.toString() ?? 'Untitled Lesson';
    final thumbnailUrl = lesson['thumbnail_url']?.toString();
    final durationSeconds = (lesson['duration'] as num?)?.toInt() ?? 0;
    final durationMinutes = (durationSeconds / 60).ceil();
    final educator = lesson['profiles'] as Map<String, dynamic>?;
    final educatorName = educator != null
        ? '${educator['first_name'] ?? ''} ${educator['last_name'] ?? ''}'
            .trim()
        : 'Unknown';
    final isCompleted =
        _isLessonCompleted(lesson); // FIXED: Use the helper method

    return Container(
      constraints: const BoxConstraints(
        minHeight: 160,
        maxHeight: 180,
      ),
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail/Icon Section
          Container(
            height: 80, // Smaller thumbnail
            width: double.infinity,
            decoration: BoxDecoration(
              color: _getSubjectColor(subject).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            _getSubjectIcon(subject),
                            color: _getSubjectColor(subject),
                            size: 24,
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Icon(
                      _getSubjectIcon(subject),
                      color: _getSubjectColor(subject),
                      size: 24,
                    ),
                  ),
          ),

          // Content Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _getSubjectColor(subject).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          subject,
                          style: TextStyle(
                            fontSize: 8,
                            color: _getSubjectColor(subject),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Title
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _getTextColor(),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Educator
                      Text(
                        educatorName,
                        style: TextStyle(
                          fontSize: 10,
                          color: _getTextColor().withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),

                  // Duration
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 10,
                        color: _getTextColor().withOpacity(0.5),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$durationMinutes min',
                        style: TextStyle(
                          fontSize: 10,
                          color: _getTextColor().withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSearchBar(),
                const SizedBox(height: 24),
                _buildSectionHeader('All Lessons', '', () {}),
                const SizedBox(height: 16),
              ]),
            ),
          ),
          if (_gradeLessons.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final lesson = _gradeLessons[index];
                    return _buildLessonCard(lesson);
                  },
                  childCount: _gradeLessons.length,
                ),
              ),
            )
          else
            SliverFillRemaining(
              child: _buildEmptyState('No lessons available for $_grade'),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search lessons, subjects, educators...',
          hintStyle: TextStyle(color: _getTextColor().withOpacity(0.5)),
          prefixIcon:
              Icon(Icons.search, color: _getTextColor().withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        onChanged: (value) {
          _logInfo('Search query: $value');
        },
      ),
    );
  }

  Widget _buildHomeworkTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment,
                size: 64, color: Color(0xFF2196F3)),
          ),
          const SizedBox(height: 24),
          Text(
            'Homework',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _getTextColor(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Manage your assignments and submissions',
            style: TextStyle(
              color: _getTextColor().withOpacity(0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => HomeworkSubmission(
                          homeworkId:
                              'your-homework-id-here', // ✅ FIXED: Changed from studentCode to homeworkId
                          studentData: _studentInfo,
                        )),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('View Homework'),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFE91E63).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.live_tv, size: 64, color: Color(0xFFE91E63)),
          ),
          const SizedBox(height: 24),
          Text(
            'Live Sessions',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _getTextColor(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Join live classes with your educators',
            style: TextStyle(
              color: _getTextColor().withOpacity(0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => LiveSession(
                          studentCode: _studentCode,
                          studentData: _studentInfo,
                        )),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('View Live Sessions'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 80,
            color: _getTextColor().withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: _getTextColor().withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSheet() {
    return Container(
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              color: _getTextColor().withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // Profile content
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF45a049)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${_studentInfo['first_name']?.toString() ?? 'Student'} ${_studentInfo['last_name']?.toString() ?? ''}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _getTextColor(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_grade • ${_studentInfo['school_name']?.toString() ?? 'Transorange School for the Deaf'}',
            style: TextStyle(
              fontSize: 16,
              color: _getTextColor().withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.badge, color: Color(0xFF4CAF50)),
                const SizedBox(width: 12),
                Text(
                  'Student Code: ${_studentInfo['student_code']?.toString() ?? 'Unknown'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text('Sign Out'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showSubjects() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Available Subjects'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _gradeSubjects.length,
            itemBuilder: (context, index) {
              final subject = _gradeSubjects[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getSubjectColor(subject).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getSubjectIcon(subject),
                      color: _getSubjectColor(subject),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    subject,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to subject-specific lessons
                  },
                ),
              );
            },
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _getPrimaryColor()),
          const SizedBox(height: 20),
          Text(
            'Loading your dashboard...',
            style: TextStyle(
              color: _getTextColor(),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 20),
          Text(
            'Failed to load dashboard',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _getTextColor(),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _getTextColor().withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: _getPrimaryColor(),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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

  BottomNavigationBar _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() => _currentIndex = index);
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: _getCardColor(),
      selectedItemColor: const Color(0xFF4CAF50),
      unselectedItemColor: _getTextColor().withOpacity(0.5),
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      elevation: 8,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.video_library_rounded),
          label: 'Lessons',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment_rounded),
          label: 'Homework',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.live_tv_rounded),
          label: 'Live',
        ),
      ],
    );
  }

  // Color helpers
  Color _getBackgroundColor() => Colors.grey.shade50;
  Color _getTextColor() => Colors.grey.shade900;
  Color _getCardColor() => Colors.white;
  Color _getPrimaryColor() => const Color(0xFF4CAF50);

  // Subject helpers
  IconData _getSubjectIcon(String? subject) {
    switch (subject?.toLowerCase()) {
      case 'mathematics':
      case 'math':
        return Icons.calculate;
      case 'science':
        return Icons.science;
      case 'english':
        return Icons.language;
      case 'south african sign language':
        return Icons.sign_language;
      case 'technology':
        return Icons.computer;
      case 'economic management sciences':
        return Icons.attach_money;
      case 'life orientation':
        return Icons.self_improvement;
      default:
        return Icons.school;
    }
  }

  Color _getSubjectColor(String? subject) {
    switch (subject?.toLowerCase()) {
      case 'mathematics':
      case 'math':
        return const Color(0xFF2196F3);
      case 'science':
        return const Color(0xFFFF9800);
      case 'english':
        return const Color(0xFF4CAF50);
      case 'south african sign language':
        return const Color(0xFF9C27B0);
      case 'technology':
        return const Color(0xFF607D8B);
      case 'economic management sciences':
        return const Color(0xFF795548);
      case 'life orientation':
        return const Color(0xFFE91E63);
      default:
        return const Color(0xFF607D8B);
    }
  }
}

// Video Player Screen
class VideoPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final VoidCallback onVideoCompleted;

  const VideoPlayerScreen({
    super.key,
    required this.lesson,
    required this.onVideoCompleted,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;
  bool _videoCompleted = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      // For demo purposes, using a sample video URL
      // In production, you would use the actual video URL from the lesson data
      final videoUrl = widget.lesson['video_url']?.toString() ??
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..addListener(() {
          if (_controller.value.isInitialized && !_isLoading) {
            setState(() {});
          }

          // Check if video reached the end
          if (_controller.value.position >= _controller.value.duration &&
              _controller.value.duration > Duration.zero) {
            if (!_videoCompleted) {
              _videoCompleted = true;
              widget.onVideoCompleted();
            }
          }
        })
        ..initialize().then((_) {
          setState(() {
            _isLoading = false;
          });
          _controller.setLooping(false);
        });
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
      }
    });
  }

  void _seekForward() {
    final newPosition =
        _controller.value.position + const Duration(seconds: 10);
    _controller.seekTo(newPosition < _controller.value.duration
        ? newPosition
        : _controller.value.duration);
  }

  void _seekBackward() {
    final newPosition =
        _controller.value.position - const Duration(seconds: 10);
    _controller
        .seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.lesson['title']?.toString() ?? 'Video Lesson',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.white),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load video',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please check your internet connection',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initializeVideoPlayer,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Video Player
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),

                    // Video Controls
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.black87,
                      child: Column(
                        children: [
                          // Progress Bar
                          VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Color(0xFF4CAF50),
                              bufferedColor: Colors.grey,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Control Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Seek Backward
                              IconButton(
                                onPressed: _seekBackward,
                                icon: const Icon(Icons.replay_10,
                                    color: Colors.white, size: 30),
                              ),

                              // Play/Pause
                              IconButton(
                                onPressed: _togglePlayPause,
                                icon: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),

                              // Seek Forward
                              IconButton(
                                onPressed: _seekForward,
                                icon: const Icon(Icons.forward_10,
                                    color: Colors.white, size: 30),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Time Display
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_controller.value.position),
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                _formatDuration(_controller.value.duration),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Lesson Info
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.grey[900],
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.lesson['title']?.toString() ??
                                    'Untitled Lesson',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (widget.lesson['description'] != null)
                                Text(
                                  widget.lesson['description'].toString(),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              const SizedBox(height: 16),
                              if (_videoCompleted)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFF4CAF50)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.check_circle,
                                          color: Color(0xFF4CAF50)),
                                      SizedBox(width: 8),
                                      Text(
                                        'Lesson completed! Progress updated.',
                                        style: TextStyle(
                                          color: Color(0xFF4CAF50),
                                          fontWeight: FontWeight.w600,
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
                  ],
                ),
    );
  }
}

// SASL Homework Page (keep the existing implementation)
class SASLHomeworkPage extends StatefulWidget {
  final Map<String, dynamic> homework;
  final Map<String, String> answers;
  final Function(Map<String, String>) onAnswersUpdate;

  const SASLHomeworkPage({
    super.key,
    required this.homework,
    required this.answers,
    required this.onAnswersUpdate,
  });

  @override
  State<SASLHomeworkPage> createState() => _SASLHomeworkPageState();
}

class _SASLHomeworkPageState extends State<SASLHomeworkPage> {
  final Map<String, String> _currentAnswers = {};
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _currentAnswers.addAll(widget.answers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SASL Homework'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveProgress,
          ),
          IconButton(
            icon: const Icon(Icons.assignment_turned_in),
            onPressed: _submitHomework,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exam Header
              _buildExamHeader(),
              const SizedBox(height: 24),

              // Instructions
              _buildInstructions(),
              const SizedBox(height: 32),

              // Section A: Comprehension
              _buildSectionA(),
              const SizedBox(height: 32),

              // Section B: Language Structures
              _buildSectionB(),
              const SizedBox(height: 32),

              // Submit Button
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2196F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.homework['title']?.toString() ?? 'SASL Homework',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2196F3),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Total Marks: ${widget.homework['total_marks']} • Time: ${widget.homework['time_allowed']}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Due: ${widget.homework['due_date']}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INSTRUCTIONS:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '1. Answer ALL questions in both sections.\n'
            '2. Write your answers in the spaces provided.\n'
            '3. Pay attention to mark allocation for each question.\n'
            '4. Use proper SASL grammar and structure in Section B.\n'
            '5. Review your work before submitting.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionA() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SECTION A: COMPREHENSION',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2196F3),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Answer ALL questions in this section.',
            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),

          // Question 1.1
          _buildQuestion(
            '1.1',
            'Watch the provided SASL video narrative and answer the following questions:',
            15,
          ),
          const SizedBox(height: 16),

          _buildSubQuestion(
            '1.1.1',
            'What is the main theme of the narrative? (3 marks)',
            'q1_1_1',
          ),
          const SizedBox(height: 12),

          _buildSubQuestion(
            '1.1.2',
            'List THREE key events that occur in the narrative. (6 marks)',
            'q1_1_2',
          ),
          const SizedBox(height: 12),

          _buildSubQuestion(
            '1.1.3',
            'Describe the relationship between the two main characters. (6 marks)',
            'q1_1_3',
          ),
          const SizedBox(height: 16),

          // Question 1.2
          _buildQuestion(
            '1.2',
            'Based on the narrative, answer the following:',
            10,
          ),
          const SizedBox(height: 16),

          _buildSubQuestion(
            '1.2.1',
            'What cultural elements are represented in the story? Provide TWO examples. (4 marks)',
            'q1_2_1',
          ),
          const SizedBox(height: 12),

          _buildSubQuestion(
            '1.2.2',
            'What is the significance of the setting in the narrative? (3 marks)',
            'q1_2_2',
          ),
          const SizedBox(height: 12),

          _buildSubQuestion(
            '1.2.3',
            'How does the narrative conclude, and what message does it convey? (3 marks)',
            'q1_2_3',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionB() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SECTION B: LANGUAGE STRUCTURES AND CONVENTIONS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2196F3),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Answer ALL questions in this section.',
            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),

          // Question 2.1
          _buildQuestion(
            '2.1',
            'SASL Grammar and Structure:',
            20,
          ),
          const SizedBox(height: 16),

          _buildSubQuestion(
            '2.1.1',
            'Explain the difference between directional verbs and plain verbs in SASL. Provide TWO examples of each. (8 marks)',
            'q2_1_1',
          ),
          const SizedBox(height: 12),

          _buildSubQuestion(
            '2.1.2',
            'Describe how non-manual markers (facial expressions, body shifts) change the meaning of signs in SASL. Provide THREE examples. (6 marks)',
            'q2_1_2',
          ),
          const SizedBox(height: 12),

          _buildSubQuestion(
            '2.1.3',
            'What is the role of classifiers in SASL? Provide TWO examples of how classifiers are used. (6 marks)',
            'q2_1_3',
          ),
          const SizedBox(height: 16),

          // Question 2.2
          _buildQuestion(
            '2.2',
            'SASL Conversation and Dialogue:',
            25,
          ),
          const SizedBox(height: 16),

          _buildSubQuestion(
            '2.2.1',
            'Create a short SASL dialogue (8-10 sentences) between two friends discussing their weekend plans. Focus on proper turn-taking and question formation. (15 marks)',
            'q2_2_1',
            maxLines: 8,
          ),
          const SizedBox(height: 12),

          _buildSubQuestion(
            '2.2.2',
            'Explain the cultural considerations you incorporated in your dialogue. (5 marks)',
            'q2_2_2',
          ),
          const SizedBox(height: 12),

          _buildSubQuestion(
            '2.2.3',
            'Identify THREE different sentence types used in your dialogue (declarative, interrogative, imperative, etc.). (5 marks)',
            'q2_2_3',
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(String number, String text, int marks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'QUESTION $number',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '[$marks marks]',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildSubQuestion(String number, String text, String key,
      {int maxLines = 4}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _currentAnswers[key],
          onChanged: (value) {
            _currentAnswers[key] = value;
          },
          maxLines: maxLines,
          decoration: const InputDecoration(
            hintText: 'Type your answer here...',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(12),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please provide an answer';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitHomework,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'SUBMIT HOMEWORK',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _saveProgress() {
    widget.onAnswersUpdate(_currentAnswers);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Progress saved successfully!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _submitHomework() {
    if (_formKey.currentState!.validate()) {
      widget.onAnswersUpdate(_currentAnswers);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Homework submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all required questions.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
