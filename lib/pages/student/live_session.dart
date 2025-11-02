import 'package:flutter/material.dart';

class LiveSession extends StatefulWidget {
  final String studentCode;
  final Map<String, dynamic> studentData;

  const LiveSession({
    super.key,
    required this.studentCode,
    required this.studentData,
  });

  @override
  State<LiveSession> createState() => _LiveSessionState();
}

class _LiveSessionState extends State<LiveSession> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Sessions'),
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
            const Icon(Icons.live_tv, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Live Sessions',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Student: ${widget.studentData['first_name']} ${widget.studentData['last_name']}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Grade: ${widget.studentData['grade']}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text('Live session features coming soon...'),
          ],
        ),
      ),
    );
  }
}
