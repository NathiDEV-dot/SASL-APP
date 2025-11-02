// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:signsync_academy/core/services/submission_service.dart';
import 'services/submission_service.dart';

class ReviewSubmissions extends StatefulWidget {
  const ReviewSubmissions({super.key});

  @override
  State<ReviewSubmissions> createState() => _ReviewSubmissionsState();
}

class _ReviewSubmissionsState extends State<ReviewSubmissions> {
  int _selectedFilter = 0; // 0: All, 1: Pending, 2: Graded
  final List<String> _filters = ['All', 'Pending', 'Graded'];

  final SubmissionService _submissionService = SubmissionService();
  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final submissions = await _submissionService.getEducatorSubmissions();
      setState(() {
        _submissions = submissions;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredSubmissions {
    if (_selectedFilter == 0) return _submissions;
    if (_selectedFilter == 1) {
      return _submissions.where((s) => s['status'] == 'pending').toList();
    }
    return _submissions.where((s) => s['status'] == 'graded').toList();
  }

  Map<String, dynamic> _getSubmissionStats() {
    final pendingCount =
        _submissions.where((s) => s['status'] == 'pending').length;
    final gradedCount =
        _submissions.where((s) => s['status'] == 'graded').length;
    final overdueCount = _submissions.where((s) {
      final dueDate =
          s['due_date'] != null ? DateTime.parse(s['due_date']) : null;
      return dueDate != null &&
          dueDate.isBefore(DateTime.now()) &&
          s['status'] == 'pending';
    }).length;

    return {
      'pending': pendingCount,
      'graded': gradedCount,
      'overdue': overdueCount,
      'total': _submissions.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      appBar: AppBar(
        title: const Text(
          'Review Submissions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: _getTextColor()),
            onPressed: _searchSubmissions,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: _getTextColor()),
            onPressed: _loadSubmissions,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage.isNotEmpty
              ? _buildErrorState()
              : Column(
                  children: [
                    // Stats Overview
                    _buildStatsSection(),

                    // Filter Chips
                    _buildFilterSection(),

                    // Submissions List
                    Expanded(
                      child: _filteredSubmissions.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadSubmissions,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredSubmissions.length,
                                itemBuilder: (context, index) {
                                  return _buildSubmissionCard(
                                      _filteredSubmissions[index]);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _quickGrade,
        backgroundColor: _getPrimaryColor(),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.edit_document),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _getPrimaryColor()),
          const SizedBox(height: 16),
          Text(
            'Loading submissions...',
            style: TextStyle(
              color: _getTextColor().withOpacity(0.7),
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
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: Colors.red.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading submissions',
            style: TextStyle(
              color: _getTextColor(),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(
              color: _getTextColor().withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadSubmissions,
            style: ElevatedButton.styleFrom(
              backgroundColor: _getPrimaryColor(),
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final stats = _getSubmissionStats();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getPrimaryColor().withOpacity(0.1),
            _getPrimaryColor().withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            stats['pending'].toString(),
            'Pending',
            Icons.pending_actions_rounded,
            Colors.orange,
          ),
          _buildStatItem(
            stats['graded'].toString(),
            'Graded',
            Icons.assignment_turned_in_rounded,
            Colors.green,
          ),
          _buildStatItem(
            stats['overdue'].toString(),
            'Overdue',
            Icons.warning_amber_rounded,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _getTextColor().withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: FilterChip(
              selected: _selectedFilter == index,
              label: Text(_filters[index]),
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = index;
                });
              },
              backgroundColor: _getCardColor(),
              selectedColor: _getPrimaryColor(),
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color:
                    _selectedFilter == index ? Colors.white : _getTextColor(),
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: _getBorderColor()),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> submission) {
    final isPending = submission['status'] == 'pending';
    final student = submission['students'] ?? {};
    final assignment = submission['assignments'] ?? {};
    final dueDate = submission['due_date'] != null
        ? DateTime.parse(submission['due_date'])
        : null;

    final priority = _getPriorityLevel(dueDate, isPending);
    final priorityColor = _getPriorityColor(priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isPending ? priorityColor.withOpacity(0.3) : _getBorderColor(),
          width: isPending ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _viewSubmission(submission),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with priority indicator
                Stack(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color:
                            _getSubjectColor(assignment['subject'] ?? 'General')
                                .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getSubjectColor(
                                  assignment['subject'] ?? 'General')
                              .withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _getStudentInitials(student['first_name'] ?? '',
                              student['last_name'] ?? ''),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getSubjectColor(
                                assignment['subject'] ?? 'General'),
                          ),
                        ),
                      ),
                    ),
                    if (isPending)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: priorityColor,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: _getCardColor(), width: 2),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _getTextColor(),
                              ),
                            ),
                          ),
                          _buildStatusBadge(submission),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        assignment['title'] ?? 'No Title',
                        style: TextStyle(
                          fontSize: 16,
                          color: _getTextColor().withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 14,
                              color: _getTextColor().withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Text(
                            _formatSubmittedTime(submission['submitted_at']),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getTextColor().withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.calendar_today_rounded,
                              size: 14,
                              color: _getTextColor().withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Text(
                            _formatDueDate(dueDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getDueDateColor(dueDate),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (isPending) _buildActionButtons(submission),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Map<String, dynamic> submission) {
    final isPending = submission['status'] == 'pending';
    final grade = submission['grade'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPending
            ? Colors.orange.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending ? Colors.orange : Colors.green,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPending ? Icons.pending_rounded : Icons.check_circle_rounded,
            size: 14,
            color: isPending ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 4),
          Text(
            isPending ? 'Pending' : 'Graded ${grade ?? ""}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isPending ? Colors.orange : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> submission) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _gradeSubmission(submission),
            icon: const Icon(Icons.grading_rounded, size: 18),
            label: const Text('Grade Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getPrimaryColor(),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _viewSubmission(submission),
          icon: Icon(Icons.visibility_rounded,
              color: _getTextColor().withOpacity(0.6)),
          style: IconButton.styleFrom(
            backgroundColor: _getBackgroundColor(),
            padding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in_rounded,
            size: 80,
            color: _getTextColor().withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 1
                ? 'No Pending Submissions'
                : _selectedFilter == 2
                    ? 'No Graded Submissions'
                    : 'No Submissions Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _getTextColor().withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All caught up! New submissions will appear here.',
            style: TextStyle(
              fontSize: 14,
              color: _getTextColor().withOpacity(0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _getStudentInitials(String firstName, String lastName) {
    if (firstName.isEmpty && lastName.isEmpty) return '?';
    return '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
        .toUpperCase();
  }

  String _formatSubmittedTime(String? submittedAt) {
    if (submittedAt == null) return 'Unknown';

    final submitted = DateTime.parse(submittedAt);
    final now = DateTime.now();
    final difference = now.difference(submitted);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  String _formatDueDate(DateTime? dueDate) {
    if (dueDate == null) return 'No due date';

    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (difference.inDays == 0) return 'Due today';
    if (difference.inDays == 1) return 'Due tomorrow';
    if (difference.inDays > 1) return 'Due in ${difference.inDays} days';
    if (difference.inDays == -1) return 'Due yesterday';
    return 'Due ${difference.inDays.abs()} days ago';
  }

  String _getPriorityLevel(DateTime? dueDate, bool isPending) {
    if (!isPending) return 'low';
    if (dueDate == null) return 'medium';

    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (difference.inDays < 0) return 'high'; // Overdue
    if (difference.inDays == 0) return 'high'; // Due today
    if (difference.inDays <= 2) return 'medium'; // Due in 2 days
    return 'low';
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getSubjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':
      case 'math':
        return const Color(0xFF3B82F6);
      case 'science':
        return const Color(0xFF10B981);
      case 'history':
        return const Color(0xFFF59E0B);
      case 'physics':
        return const Color(0xFFEF4444);
      case 'literature':
      case 'english':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getDueDateColor(DateTime? dueDate) {
    if (dueDate == null) return _getTextColor().withOpacity(0.6);

    final now = DateTime.now();
    if (dueDate.isBefore(now)) return Colors.red;
    if (dueDate.difference(now).inDays == 0) return Colors.orange;
    return _getTextColor().withOpacity(0.6);
  }

  // Action methods
  void _gradeSubmission(Map<String, dynamic> submission) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGradingSheet(submission),
    );
  }

  void _viewSubmission(Map<String, dynamic> submission) {
    // Navigate to submission detail page or show video
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Viewing submission from ${submission['students']?['first_name'] ?? 'Student'}'),
        backgroundColor: _getPrimaryColor(),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _searchSubmissions() async {
    final result = await showSearch(
      context: context,
      delegate: _SubmissionSearchDelegate(_submissionService),
    );

    if (result != null) {
      // Handle search result
    }
  }

  void _quickGrade() {
    // Implement quick grade functionality for multiple submissions
  }

  Widget _buildGradingSheet(Map<String, dynamic> submission) {
    // Implement grading sheet with form
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Grade Submission',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _getTextColor(),
            ),
          ),
          // Add grading form here
        ],
      ),
    );
  }

  // Theme methods
  Color _getBackgroundColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0F0F1E)
        : const Color(0xFFF8FAFF);
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
        ? const Color(0xFF333344)
        : const Color(0xFFE2E8F0);
  }

  Color _getPrimaryColor() {
    return const Color(0xFF3B82F6);
  }
}

// Search delegate for submissions
class _SubmissionSearchDelegate extends SearchDelegate {
  final SubmissionService _submissionService;

  _SubmissionSearchDelegate(this._submissionService);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _submissionService.searchSubmissions(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final results = snapshot.data ?? [];

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final submission = results[index];
            return ListTile(
              title: Text(
                  '${submission['students']?['first_name']} ${submission['students']?['last_name']}'),
              subtitle: Text(submission['assignments']?['title'] ?? ''),
              onTap: () {
                close(context, submission);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container(); // Return empty for now
  }
}
