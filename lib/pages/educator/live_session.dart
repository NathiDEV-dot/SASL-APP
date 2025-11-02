// ignore_for_file: deprecated_member_use

// ignore: unused_import
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/services/live_sessions_service.dart';
// ignore: unused_import
import 'create_live_session.dart';
import 'live_session_details.dart';

class LiveSession extends StatefulWidget {
  const LiveSession({super.key});

  @override
  State<LiveSession> createState() => _LiveSessionState();
}

class _LiveSessionState extends State<LiveSession> {
  final LiveSessionsService _sessionsService = LiveSessionsService();
  List<LiveSessionData> _sessions = [];
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;
  String? _errorMessage;

  // Filter states
  String _currentFilter = 'all'; // all, upcoming, live, completed
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final sessions = await _sessionsService.getEducatorSessions(user.id);
        final stats = await _sessionsService.getSessionStatistics(user.id);

        setState(() {
          _sessions = sessions;
          _statistics = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<LiveSessionData> get _filteredSessions {
    var filtered = _sessions;

    // Apply status filter
    if (_currentFilter == 'upcoming') {
      filtered = filtered.where((session) => session.isUpcoming).toList();
    } else if (_currentFilter == 'live') {
      filtered = filtered.where((session) => session.isLive).toList();
    } else if (_currentFilter == 'completed') {
      filtered = filtered.where((session) => session.isEnded).toList();
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered
          .where((session) =>
              session.title.toLowerCase().contains(query) ||
              session.description.toLowerCase().contains(query) ||
              session.subject.toLowerCase().contains(query))
          .toList();
    }

    return filtered;
  }

  Future<void> _startSession(LiveSessionData session) async {
    try {
      await _sessionsService.startLiveSession(session.id);
      _showSuccess('Live session started successfully!');
      _loadSessions();
    } catch (e) {
      _showError('Failed to start session: $e');
    }
  }

  Future<void> _endSession(LiveSessionData session) async {
    try {
      await _sessionsService.endLiveSession(session.id);
      _showSuccess('Live session ended successfully!');
      _loadSessions();
    } catch (e) {
      _showError('Failed to end session: $e');
    }
  }

  Future<void> _cancelSession(LiveSessionData session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Session'),
        content: const Text(
            'Are you sure you want to cancel this live session? Students will be notified.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Session'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Session',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _sessionsService.cancelLiveSession(session.id);
        _showSuccess('Session cancelled successfully!');
        _loadSessions();
      } catch (e) {
        _showError('Failed to cancel session: $e');
      }
    }
  }

  void _showSessionDetails(LiveSessionData session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveSessionDetails(
          session: session,
          onSessionUpdated: _loadSessions,
        ),
      ),
    );
  }

  void _createNewSession() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateLiveSession(
          onSessionCreated: _loadSessions,
        ),
      ),
    );
  }

  void _copyMeetingLink(LiveSessionData session) {
    if (session.meetingUrl != null) {
      // In a real app, you would use clipboard package
      // Clipboard.setData(ClipboardData(text: session.meetingUrl!));
      _showSuccess('Meeting link copied to clipboard!');
    }
  }

  void _joinSession(LiveSessionData session) {
    if (session.meetingUrl != null) {
      // In a real app, you would launch the meeting URL
      _showInfo('Joining session: ${session.title}');
      // You can integrate with Jitsi, Zoom, or Teams here
    } else {
      _showError('No meeting link available for this session');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
              : _buildContent(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'Live Sessions',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadSessions,
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.help_outline_rounded),
          onPressed: _showHelp,
          tooltip: 'Help',
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Statistics Overview
        _buildStatisticsOverview(),

        // Search and Filters
        _buildSearchAndFilters(),

        // Sessions List
        Expanded(
          child: _filteredSessions.isEmpty
              ? _buildEmptyState()
              : _buildSessionsList(),
        ),
      ],
    );
  }

  Widget _buildStatisticsOverview() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4361EE), Color(0xFF3A0CA3)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.live_tv_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Session Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                _statistics['total_sessions']?.toString() ?? '0',
                'Total',
                Icons.video_library_rounded,
              ),
              _buildStatItem(
                _statistics['upcoming_sessions']?.toString() ?? '0',
                'Upcoming',
                Icons.schedule_rounded,
              ),
              _buildStatItem(
                _statistics['live_sessions']?.toString() ?? '0',
                'Live Now',
                Icons.live_tv_rounded,
              ),
              _buildStatItem(
                _statistics['total_participants']?.toString() ?? '0',
                'Participants',
                Icons.people_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search sessions by title, subject...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _getBorderColor()),
              ),
              filled: true,
              fillColor: _getCardColor(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Filter Chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('All Sessions', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Upcoming', 'upcoming'),
                const SizedBox(width: 8),
                _buildFilterChip('Live Now', 'live'),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', 'completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _currentFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _currentFilter = value;
        });
      },
      backgroundColor: _getCardColor(),
      selectedColor: const Color(0xFF4361EE),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : _getTextColor(),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildSessionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredSessions.length,
      itemBuilder: (context, index) {
        final session = _filteredSessions[index];
        return _buildSessionCard(session);
      },
    );
  }

  Widget _buildSessionCard(LiveSessionData session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showSessionDetails(session),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _getBorderColor()),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status and actions
                Row(
                  children: [
                    _buildSessionStatus(session),
                    const Spacer(),
                    _buildSessionActions(session),
                  ],
                ),
                const SizedBox(height: 12),

                // Session title and basic info
                Text(
                  session.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _getTextColor(),
                  ),
                ),
                const SizedBox(height: 8),

                if (session.description.isNotEmpty)
                  Text(
                    session.description,
                    style: TextStyle(
                      color: _getTextColor().withOpacity(0.7),
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                const SizedBox(height: 12),

                // Session details
                _buildSessionDetails(session),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionStatus(LiveSessionData session) {
    Color color;
    String statusText;
    IconData icon;

    if (session.isCancelled) {
      color = Colors.grey;
      statusText = 'Cancelled';
      icon = Icons.cancel_rounded;
    } else if (session.isEnded) {
      color = Colors.blue;
      statusText = 'Completed';
      icon = Icons.check_circle_rounded;
    } else if (session.isLive) {
      color = Colors.green;
      statusText = 'Live Now';
      icon = Icons.live_tv_rounded;
    } else {
      color = Colors.orange;
      statusText = 'Upcoming';
      icon = Icons.schedule_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionActions(LiveSessionData session) {
    if (session.isCancelled) {
      return const SizedBox.shrink();
    } else if (session.isEnded) {
      return IconButton(
        icon: const Icon(Icons.play_circle_filled_rounded),
        onPressed: () {
          if (session.recordingUrl != null) {
            _showInfo('Opening recording...');
          } else {
            _showInfo('No recording available for this session');
          }
        },
        tooltip: 'Watch Recording',
      );
    } else if (session.isLive) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: Colors.green),
            onPressed: () => _joinSession(session),
            tooltip: 'Join Session',
          ),
          IconButton(
            icon: const Icon(Icons.stop_rounded, color: Colors.red),
            onPressed: () => _endSession(session),
            tooltip: 'End Session',
          ),
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (session.canJoin)
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.green),
              onPressed: () => _startSession(session),
              tooltip: 'Start Session',
            ),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            onPressed: () => _copyMeetingLink(session),
            tooltip: 'Copy Meeting Link',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'edit') {
                _showSessionDetails(session);
              } else if (value == 'cancel') {
                _cancelSession(session);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Edit Session'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'cancel',
                child: Row(
                  children: [
                    Icon(Icons.cancel_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Cancel Session', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildSessionDetails(LiveSessionData session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow(
          Icons.schedule_rounded,
          'Scheduled for ${_formatDateTime(session.scheduledTime)}',
        ),
        _buildDetailRow(
          Icons.timer_rounded,
          'Duration: ${session.durationMinutes} minutes',
        ),
        _buildDetailRow(
          Icons.category_rounded,
          '${session.subject} • ${session.grade}',
        ),
        if (session.participantCount > 0)
          _buildDetailRow(
            Icons.people_rounded,
            '${session.participantCount} participants',
          ),
        if (session.isLive)
          _buildDetailRow(
            Icons.circle_rounded,
            'Live now - Join to start teaching',
            color: Colors.green,
          ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon,
              size: 16, color: color ?? _getTextColor().withOpacity(0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color ?? _getTextColor().withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _createNewSession,
      backgroundColor: const Color(0xFF4361EE),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: const Text('New Session'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
            'Loading your live sessions...',
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
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: _getErrorColor(),
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to Load Sessions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _getTextColor(),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'An unexpected error occurred',
            style: TextStyle(
              color: _getTextColor().withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _loadSessions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getPrimaryColor(),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Try Again'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _showHelp,
                child: const Text('Get Help'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.live_tv_rounded,
            size: 80,
            color: _getTextColor().withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Live Sessions',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _getTextColor(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentFilter == 'all'
                ? 'Schedule your first live session to start teaching in real-time'
                : 'No $_currentFilter sessions found',
            style: TextStyle(
              color: _getTextColor().withOpacity(0.7),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_currentFilter == 'all')
            ElevatedButton.icon(
              onPressed: _createNewSession,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Schedule Live Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getPrimaryColor(),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Live Sessions Help'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Schedule sessions for future dates'),
            SizedBox(height: 8),
            Text('• Start sessions 5 minutes before scheduled time'),
            SizedBox(height: 8),
            Text('• Share meeting links with students'),
            SizedBox(height: 8),
            Text('• Recordings are saved automatically'),
          ],
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

  // Color helpers
  Color _getBackgroundColor() => Colors.grey.shade50;
  Color _getCardColor() => Colors.white;
  Color _getBorderColor() => Colors.grey.shade300;
  Color _getTextColor() => Colors.grey.shade900;
  Color _getPrimaryColor() => const Color(0xFF4361EE);
  Color _getErrorColor() => const Color(0xFFEF4444);

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (sessionDay == today) {
      return 'Today at ${DateFormat('HH:mm').format(dateTime)}';
    } else if (sessionDay == today.add(const Duration(days: 1))) {
      return 'Tomorrow at ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('MMM dd, yyyy • HH:mm').format(dateTime);
    }
  }
}
