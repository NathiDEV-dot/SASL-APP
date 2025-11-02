import 'package:flutter/material.dart';

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
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Homework Submission',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Student: ${widget.studentData['first_name']} ${widget.studentData['last_name']}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Code: ${widget.studentCode}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text('Homework features coming soon...'),
          ],
        ),
      ),
    );
  }
}
