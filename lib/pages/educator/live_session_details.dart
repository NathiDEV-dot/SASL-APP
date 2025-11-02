import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/live_sessions_service.dart';

class LiveSessionDetails extends StatefulWidget {
  final LiveSessionData session;
  final VoidCallback onSessionUpdated;

  const LiveSessionDetails({
    super.key,
    required this.session,
    required this.onSessionUpdated,
  });

  @override
  State<LiveSessionDetails> createState() => _LiveSessionDetailsState();
}

class _LiveSessionDetailsState extends State<LiveSessionDetails> {
  final LiveSessionsService _sessionsService = LiveSessionsService();
  late LiveSessionData _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  Future<void> _refreshSession() async {
    try {
      final updatedSession = await _sessionsService.getSessionById(_session.id);
      setState(() {
        _session = updatedSession;
      });
      widget.onSessionUpdated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh session: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editSession() {
    // Implementation for editing session
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSession,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editSession,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSessionHeader(),
            const SizedBox(height: 24),
            _buildSessionInfo(),
            const SizedBox(height: 24),
            _buildSessionActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _session.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_session.description.isNotEmpty)
              Text(
                _session.description,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Status', _session.status.toUpperCase()),
            _buildInfoRow('Subject', _session.subject),
            _buildInfoRow('Grade', _session.grade),
            _buildInfoRow(
                'Scheduled Time', _formatDateTime(_session.scheduledTime)),
            _buildInfoRow('Duration', '${_session.durationMinutes} minutes'),
            if (_session.startedAt != null)
              _buildInfoRow('Started At', _formatDateTime(_session.startedAt!)),
            if (_session.endedAt != null)
              _buildInfoRow('Ended At', _formatDateTime(_session.endedAt!)),
            _buildInfoRow('Participants', _session.participantCount.toString()),
            if (_session.meetingUrl != null)
              _buildInfoRow('Meeting URL', _session.meetingUrl!),
            if (_session.recordingUrl != null)
              _buildInfoRow('Recording URL', _session.recordingUrl!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_session.isUpcoming)
              _buildActionButton(
                'Start Session',
                Icons.play_arrow,
                Colors.green,
                () {
                  // Start session logic
                },
              ),
            if (_session.isLive)
              _buildActionButton(
                'End Session',
                Icons.stop,
                Colors.red,
                () {
                  // End session logic
                },
              ),
            if (!_session.isEnded && !_session.isCancelled)
              _buildActionButton(
                'Cancel Session',
                Icons.cancel,
                Colors.orange,
                () {
                  // Cancel session logic
                },
              ),
            if (_session.meetingUrl != null)
              _buildActionButton(
                'Copy Meeting Link',
                Icons.copy,
                Colors.blue,
                () {
                  // Copy link logic
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String text, IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy • HH:mm').format(dateTime);
  }
}
