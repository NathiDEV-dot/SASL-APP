// lib/pages/student/homework_submission.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signsync_academy/core/services/homework_service.dart';

class HomeworkSubmission extends StatefulWidget {
  final String studentCode;
  final Map<String, dynamic> studentData;

  const HomeworkSubmission({
    super.key,
    required this.studentCode,
    required this.studentData,
  });

  @override
  State<HomeworkSubmission> createState() => _HomeworkSubmissionState();
}

class _HomeworkSubmissionState extends State<HomeworkSubmission> {
  final HomeworkService _homeworkService = HomeworkService();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadHomeworkData();
  }

  Future<void> _loadHomeworkData() async {
    try {
      setState(() => _isLoading = true);

      final assignments =
          await _homeworkService.getHomeworkAssignments(widget.studentCode);
      final submissions =
          await _homeworkService.getHomeworkSubmissions(widget.studentCode);

      setState(() {
        _assignments = assignments;
        _submissions = submissions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading homework: $e')),
      );
    }
  }

  void _showSubmissionDialog(Map<String, dynamic> assignment) {
    showDialog(
      context: context,
      builder: (context) => HomeworkSubmissionDialog(
        assignment: assignment,
        studentCode: widget.studentCode,
        onSubmitted: _loadHomeworkData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Homework'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHomeworkData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Student Info Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    '${widget.studentData['first_name']?[0]}${widget.studentData['last_name']?[0]}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.studentData['first_name']} ${widget.studentData['last_name']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Grade: ${widget.studentData['grade']} • Code: ${widget.studentCode}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                _buildTab(0, 'Assignments', _assignments.length),
                _buildTab(1, 'Submissions', _submissions.length),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedTab == 0
                    ? _buildAssignmentsList()
                    : _buildSubmissionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String title, int count) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _selectedTab == index ? Colors.blue : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: _selectedTab == index
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _selectedTab == index ? Colors.blue : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _selectedTab == index ? Colors.blue : Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color:
                        _selectedTab == index ? Colors.white : Colors.grey[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentsList() {
    if (_assignments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Assignments',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'You have no pending homework assignments',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _assignments.length,
      itemBuilder: (context, index) {
        final assignment = _assignments[index];
        final lesson = assignment['lessons'] as Map<String, dynamic>? ?? {};
        final dueDate = DateTime.parse(assignment['due_date']);
        final isOverdue = dueDate.isBefore(DateTime.now());
        final isSubmitted =
            _submissions.any((sub) => sub['assignment_id'] == assignment['id']);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        assignment['title'] ?? 'Untitled Assignment',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? Colors.red[100]
                            : (isSubmitted
                                ? Colors.green[100]
                                : Colors.blue[100]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isOverdue
                            ? 'Overdue'
                            : (isSubmitted ? 'Submitted' : 'Pending'),
                        style: TextStyle(
                          color: isOverdue
                              ? Colors.red[800]
                              : (isSubmitted
                                  ? Colors.green[800]
                                  : Colors.blue[800]),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (lesson['title'] != null) ...[
                  Text(
                    'Lesson: ${lesson['title']}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  assignment['description'] ?? 'No description provided',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Due: ${_formatDate(dueDate)}',
                      style: TextStyle(
                        color: isOverdue ? Colors.red : Colors.grey[600],
                        fontWeight:
                            isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (!isSubmitted)
                      ElevatedButton(
                        onPressed: () => _showSubmissionDialog(assignment),
                        child: const Text('Submit'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmissionsList() {
    if (_submissions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Submissions',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'You have not submitted any homework yet',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _submissions.length,
      itemBuilder: (context, index) {
        final submission = _submissions[index];
        final assignment =
            submission['homework_assignments'] as Map<String, dynamic>? ?? {};
        final submittedAt = DateTime.parse(submission['submitted_at']);
        final status = submission['status'] ?? 'pending';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment['title'] ?? 'Unknown Assignment',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (submission['submission_text'] != null) ...[
                  Text(
                    submission['submission_text'],
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Submitted: ${_formatDate(submittedAt)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (submission['points_earned'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Score: ${submission['points_earned']}/${assignment['max_points'] ?? 100}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
                if (submission['feedback'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Feedback: ${submission['feedback']}',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'graded':
        return Colors.green;
      case 'submitted':
        return Colors.blue;
      case 'late':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Homework Submission Dialog
class HomeworkSubmissionDialog extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final String studentCode;
  final VoidCallback onSubmitted;

  const HomeworkSubmissionDialog({
    super.key,
    required this.assignment,
    required this.studentCode,
    required this.onSubmitted,
  });

  @override
  State<HomeworkSubmissionDialog> createState() =>
      _HomeworkSubmissionDialogState();
}

class _HomeworkSubmissionDialogState extends State<HomeworkSubmissionDialog> {
  final TextEditingController _submissionController = TextEditingController();
  final HomeworkService _homeworkService = HomeworkService();
  bool _isSubmitting = false;

  Future<void> _submitHomework() async {
    if (_submissionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your submission')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _homeworkService.submitHomework(
        studentCode: widget.studentCode,
        assignmentId: widget.assignment['id'],
        submissionText: _submissionController.text.trim(),
        attachmentUrls: [], // You can add file upload functionality here
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Homework submitted successfully!')),
      );

      widget.onSubmitted();
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Submit Homework'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.assignment['title'] ?? 'Untitled Assignment',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _submissionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Your Submission',
                border: OutlineInputBorder(),
                hintText: 'Type your homework submission here...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitHomework,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
