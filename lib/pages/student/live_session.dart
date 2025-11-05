import 'dart:async';

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
  bool _isSessionActive = false;
  int _sessionDuration = 0;
  late Timer _sessionTimer;

  @override
  void initState() {
    super.initState();
    // Simulate session timer
    _startSessionTimer();
  }

  @override
  void dispose() {
    _sessionTimer.cancel();
    super.dispose();
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _sessionDuration++;
      });
    });
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _toggleSession() {
    setState(() {
      _isSessionActive = !_isSessionActive;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Live Session'),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.black87),
            onPressed: () {
              _showSessionInfo();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Info Card
            _buildStudentInfoCard(),
            const SizedBox(height: 24),

            // Session Status
            _buildSessionStatus(),
            const SizedBox(height: 32),

            // Session Controls
            _buildSessionControls(),
            const SizedBox(height: 32),

            // Features Grid
            _buildFeaturesGrid(),
            const SizedBox(height: 24),

            // Upcoming Sessions
            _buildUpcomingSessions(),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: Colors.blue[600],
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.studentData['first_name']} ${widget.studentData['last_name']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Grade ${widget.studentData['grade']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    'Code: ${widget.studentCode}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isSessionActive ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isSessionActive ? Colors.green[100]! : Colors.orange[100]!,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSessionActive ? 'Session Active' : 'Ready to Start',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color:
                      _isSessionActive ? Colors.green[800] : Colors.orange[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isSessionActive
                    ? 'Duration: ${_formatDuration(_sessionDuration)}'
                    : 'Start a new session when ready',
                style: TextStyle(
                  color:
                      _isSessionActive ? Colors.green[600] : Colors.orange[600],
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isSessionActive ? Colors.green[100] : Colors.orange[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  _isSessionActive ? Icons.circle : Icons.schedule,
                  size: 12,
                  color:
                      _isSessionActive ? Colors.green[800] : Colors.orange[800],
                ),
                const SizedBox(width: 6),
                Text(
                  _isSessionActive ? 'LIVE' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isSessionActive
                        ? Colors.green[800]
                        : Colors.orange[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Session Controls',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(
                  _isSessionActive ? Icons.stop : Icons.play_arrow,
                  size: 20,
                ),
                label: Text(_isSessionActive ? 'End Session' : 'Start Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSessionActive ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _toggleSession,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.video_call, size: 20),
                label: const Text('Join Call'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // Handle join call
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturesGrid() {
    const features = [
      {'icon': Icons.share, 'title': 'Share Screen', 'color': Colors.blue},
      {'icon': Icons.chat, 'title': 'Chat', 'color': Colors.green},
      {'icon': Icons.assignment, 'title': 'Whiteboard', 'color': Colors.orange},
      {'icon': Icons.attach_file, 'title': 'Resources', 'color': Colors.purple},
      {'icon': Icons.record_voice_over, 'title': 'Record', 'color': Colors.red},
      {'icon': Icons.people, 'title': 'Breakout Rooms', 'color': Colors.teal},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Session Features',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: features.length,
          itemBuilder: (context, index) {
            final feature = features[index];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  // Handle feature tap
                  _showFeatureDialog(feature['title'] as String);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      feature['icon'] as IconData,
                      size: 32,
                      color: feature['color'] as Color,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      feature['title'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUpcomingSessions() {
    final upcomingSessions = [
      {'date': 'Tomorrow, 10:00 AM', 'topic': 'Mathematics - Algebra'},
      {'date': 'Friday, 2:00 PM', 'topic': 'Science - Physics'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming Sessions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...upcomingSessions.map((session) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 1,
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.calendar_today,
                      color: Colors.blue[600], size: 20),
                ),
                title: Text(
                  session['date']!,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(session['topic']!),
                trailing: IconButton(
                  icon: const Icon(Icons.notifications_none, size: 20),
                  onPressed: () {
                    // Set reminder
                  },
                ),
              ),
            )),
      ],
    );
  }

  void _showSessionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Live Session Info'),
        content: const Text(
          'Live sessions allow real-time interaction with students. '
          'You can share your screen, use the whiteboard, chat, and record sessions '
          'for later review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showFeatureDialog(String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(featureName),
        content:
            Text('$featureName feature will be available in the next update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
