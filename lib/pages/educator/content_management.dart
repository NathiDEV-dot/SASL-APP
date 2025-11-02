// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:signsync_academy/core/services/content_management_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContentManagement extends StatefulWidget {
  const ContentManagement({super.key});

  @override
  State<ContentManagement> createState() => _ContentManagementState();
}

class _ContentManagementState extends State<ContentManagement> {
  final ContentManagementService _contentService = ContentManagementService();
  final SupabaseClient _supabase = Supabase.instance.client;

  int _selectedFolder = 0;
  List<String> _folders = ['All Content'];
  List<Map<String, dynamic>> _videos = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _searchQuery = '';
  // ignore: unused_field
  String? _currentEducatorId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get current user
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      _currentEducatorId = user.id;

      // Load lessons and stats in parallel
      final futures = await Future.wait([
        _contentService.getEducatorLessons(user.id),
        _contentService.getContentStats(user.id),
      ]);

      final lessons = futures[0] as List<Map<String, dynamic>>;
      final stats = futures[1] as Map<String, dynamic>;

      // Update folders based on available subjects
      _updateFolders(stats['subjects'] as List<String>);

      // Update videos
      _updateVideos(lessons);

      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading content: $e');
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load content: ${e.toString()}');
    }
  }

  void _updateFolders(List<String> subjects) {
    setState(() {
      _folders = ['All Content', ...subjects, 'Archived'];
    });
  }

  void _updateVideos(List<Map<String, dynamic>> lessons) {
    setState(() {
      _videos = lessons.map((lesson) {
        return {
          'id': lesson['id'],
          'title': lesson['title'],
          'duration': lesson['duration_text'],
          'views': lesson['views'] ?? 0,
          'students': lesson['students'] ?? 0,
          'icon': lesson['icon'],
          'color': lesson['color'],
          'subject': lesson['subject'],
          'is_published': lesson['is_published'],
          'video_url': lesson['video_url'],
          'thumbnail_url': lesson['thumbnail_url'],
          'created_at': lesson['created_at'],
          'description': lesson['description'],
        };
      }).toList();
    });
  }

  List<Map<String, dynamic>> get _filteredVideos {
    if (_selectedFolder == 0) return _videos; // All Content

    final selectedFolder = _folders[_selectedFolder];
    if (selectedFolder == 'Archived') {
      return _videos.where((video) => video['is_published'] == false).toList();
    }

    return _videos
        .where((video) => video['subject'] == selectedFolder)
        .toList();
  }

  List<Map<String, dynamic>> get _searchedVideos {
    if (_searchQuery.isEmpty) return _filteredVideos;

    return _filteredVideos.where((video) {
      final title = video['title'] as String;
      return title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _playVideo(Map<String, dynamic> video) {
    final videoUrl = video['video_url'] as String? ?? '';
    final title = video['title'] as String;
    VideoPlayerService.playVideo(context, videoUrl, title);
  }

  void _editContent(Map<String, dynamic> video) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit "${video['title']}"'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    // TODO: Navigate to lesson editing screen
  }

  void _viewAnalytics(Map<String, dynamic> video) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Analytics for "${video['title']}"'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    // TODO: Navigate to analytics screen
  }

  void _createNewLesson() {
    // TODO: Navigate to lesson creation screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Navigate to lesson creation'),
        backgroundColor: _getPrimaryColor(),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      appBar: AppBar(
        title: const Text(
          'Content Library',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: _getPrimaryColor()),
            onPressed: _createNewLesson,
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _getPrimaryColor()),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : RefreshIndicator(
                onRefresh: _refreshData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Stats
                      _buildStatsSection(),
                      const SizedBox(height: 24),

                      // Search and Filter
                      _buildSearchSection(),
                      const SizedBox(height: 24),

                      // Folder Navigation
                      _buildFolderSection(),
                      const SizedBox(height: 24),

                      // Content Grid
                      _buildContentSection(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
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
            'Loading your content...',
            style: TextStyle(
              color: _getTextColor(),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getBorderColor()),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(
            icon: Icons.video_library_rounded,
            value: '${_stats['total_videos'] ?? 0}',
            label: 'Videos',
            iconColor: const Color(0xFF3B82F6),
            bgColor: const Color(0xFFDBEAFE),
          ),
          _buildStatCard(
            icon: Icons.people_rounded,
            value: '${_stats['published_videos'] ?? 0}',
            label: 'Published',
            iconColor: const Color(0xFF16A34A),
            bgColor: const Color(0xFFDCFCE7),
          ),
          _buildStatCard(
            icon: Icons.remove_red_eye_rounded,
            value: '${_stats['total_views'] ?? 0}',
            label: 'Total Views',
            iconColor: const Color(0xFFD97706),
            bgColor: const Color(0xFFFEF3C7),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _getTextColor(),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: _getTextColorSecondary(),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchSection() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              onChanged: _handleSearch,
              decoration: InputDecoration(
                hintText: 'Search content...',
                hintStyle: TextStyle(color: _getTextColorSecondary()),
                prefixIcon:
                    Icon(Icons.search_rounded, color: _getTextColorSecondary()),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: _getCardColor(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: _getCardColor(),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(Icons.filter_list_rounded, color: _getTextColor()),
            onPressed: () {
              _showFilterDialog();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFolderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 12),
          child: Text(
            'Folders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _getTextColor(),
            ),
          ),
        ),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _folders.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFolder = index;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedFolder == index
                          ? _getPrimaryColor()
                          : _getCardColor(),
                      borderRadius: BorderRadius.circular(25),
                      border: _selectedFolder == index
                          ? null
                          : Border.all(color: _getBorderColor()),
                      boxShadow: [
                        BoxShadow(
                          color: _selectedFolder == index
                              ? const Color(0x33000000)
                              : const Color(0x0D000000),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _folders[index],
                      style: TextStyle(
                        color: _selectedFolder == index
                            ? Colors.white
                            : _getTextColor(),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContentSection() {
    final displayVideos = _searchedVideos;

    if (displayVideos.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedFolder == 0 ? 'All Videos' : _folders[_selectedFolder],
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _getTextColor(),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x1A3B82F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${displayVideos.length} items',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getPrimaryColor(),
                  ),
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85, // Increased for video thumbnail
          ),
          itemCount: displayVideos.length,
          itemBuilder: (context, index) {
            final video = displayVideos[index];
            return _buildContentCard(video);
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: _getTextColor().withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No videos found for "$_searchQuery"'
                : 'No videos found',
            style: TextStyle(
              fontSize: 16,
              color: _getTextColor().withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty)
            Text(
              'Create your first lesson to get started',
              style: TextStyle(
                fontSize: 14,
                color: _getTextColor().withOpacity(0.4),
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 20),
          if (_searchQuery.isEmpty)
            ElevatedButton.icon(
              onPressed: _createNewLesson,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Lesson'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getPrimaryColor(),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContentCard(Map<String, dynamic> video) {
    final hasVideo = (video['video_url'] as String?)?.isNotEmpty ?? false;
    final thumbnailUrl = video['thumbnail_url'] as String?;

    return GestureDetector(
      onTap: () => _playVideo(video),
      child: Container(
        constraints: const BoxConstraints(
          maxHeight: 220,
        ),
        decoration: BoxDecoration(
          color: _getCardColor(),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(color: _getBorderColor()),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Video Thumbnail Section
            _buildVideoThumbnail(video, thumbnailUrl, hasVideo),

            // Content Info Section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _getLightColor(video['color'] as Color),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getMediumColor(video['color'] as Color),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          video['icon'] as IconData,
                          color: video['color'] as Color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video['title'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getTextColor(),
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getBackgroundColor(),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.schedule_rounded,
                                      size: 10, color: _getTextColorTertiary()),
                                  const SizedBox(width: 2),
                                  Text(
                                    video['duration'],
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: _getTextColorTertiary(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Stats section
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getBackgroundColorLight(),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.remove_red_eye_rounded,
                                size: 12, color: _getTextColorTertiary()),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${video['views']} views',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: _getTextColorTertiary(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.people_rounded,
                                size: 12, color: _getTextColorTertiary()),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${video['students']} students',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: _getTextColorTertiary(),
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
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: _getBorderColorLight()),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(
                    icon: Icons.play_arrow_rounded,
                    label: 'Play',
                    onPressed: () => _playVideo(video),
                  ),
                  Container(
                    height: 16,
                    width: 1,
                    color: _getBorderColorLight(),
                  ),
                  _buildActionButton(
                    icon: Icons.edit_rounded,
                    label: 'Edit',
                    onPressed: () => _editContent(video),
                  ),
                  Container(
                    height: 16,
                    width: 1,
                    color: _getBorderColorLight(),
                  ),
                  _buildActionButton(
                    icon: Icons.analytics_rounded,
                    label: 'Stats',
                    onPressed: () => _viewAnalytics(video),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail(
      Map<String, dynamic> video, String? thumbnailUrl, bool hasVideo) {
    return Stack(
      children: [
        Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            image: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(thumbnailUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: thumbnailUrl == null || thumbnailUrl.isEmpty
              ? Center(
                  child: Icon(
                    Icons.videocam_rounded,
                    color: Colors.grey.shade600,
                    size: 40,
                  ),
                )
              : null,
        ),

        // Play button overlay
        if (hasVideo)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: _getPrimaryColor(),
                    size: 30,
                  ),
                ),
              ),
            ),
          ),

        // No video indicator
        if (!hasVideo)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam_off_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'No Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 12, color: _getPrimaryColor()),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: _getPrimaryColor(),
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          minimumSize: Size.zero,
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Content'),
        content: const Text('Advanced filtering options coming soon...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Color helper methods
  Color _getLightColor(Color baseColor) {
    return baseColor.withAlpha(51);
  }

  Color _getLighterColor(Color baseColor) {
    return baseColor.withAlpha(26);
  }

  Color _getMediumColor(Color baseColor) {
    return baseColor.withAlpha(77);
  }

  Color _getTextColorSecondary() {
    return _getTextColor().withAlpha(153);
  }

  Color _getTextColorTertiary() {
    return _getTextColor().withAlpha(128);
  }

  Color _getBackgroundColorLight() {
    return _getBackgroundColor().withAlpha(128);
  }

  Color _getBorderColorLight() {
    return _getBorderColor().withAlpha(128);
  }

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
