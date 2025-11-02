// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:signsync_academy/core/services/content_management_service.dart';
import 'package:signsync_academy/core/services/video_player_service.dart'; // ADD THIS IMPORT
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class ContentManagement extends StatefulWidget {
  const ContentManagement({super.key});

  @override
  State<ContentManagement> createState() => _ContentManagementState();
}

class _ContentManagementState extends State<ContentManagement> {
  final ContentManagementService _contentService = ContentManagementService();
  final SupabaseClient _supabase = Supabase.instance.client;

  int _selectedFolder = 0;
  final List<String> _folders = [
    'All Content',
    'Mathematics',
    'English',
    'South African Sign Language',
    'Technology',
    'Economic Management Sciences',
    'Life Orientation',
    'Archived'
  ];
  List<Map<String, dynamic>> _videos = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String? _currentEducatorId;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FlutterDownloader.initialize(debug: true);
      });
      await _loadData();
    } catch (e) {
      debugPrint('❌ Error initializing: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      _currentEducatorId = user.id;
      final lessons = await _contentService.getEducatorLessons(user.id);

      _updateVideos(lessons);

      // Load stats in background
      _contentService.getContentStats(user.id).then((stats) {
        if (mounted) {
          setState(() {
            _stats = stats;
          });
        }
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading content: $e');
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load content');
    }
  }

  void _updateVideos(List<Map<String, dynamic>> lessons) {
    setState(() {
      _videos = lessons;
    });
  }

  List<Map<String, dynamic>> get _filteredVideos {
    if (_selectedFolder == 0) return _videos;
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
    setState(() {
      _isLoading = true;
    });
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

  void _createNewLesson() {
    Navigator.pushNamed(context, '/lesson_creation');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      body: _isLoading
          ? _buildLoadingState()
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // Header
                        _buildHeaderSection(),
                        // Stats
                        _buildStatsSection(),
                        // Search
                        _buildSearchSection(),
                        // Folders
                        _buildFolderSection(),
                        // Content Header
                        if (_searchedVideos.isNotEmpty) _buildContentHeader(),
                      ],
                    ),
                  ),
                ];
              },
              body: RefreshIndicator(
                onRefresh: _refreshData,
                child: _searchedVideos.isNotEmpty
                    ? _buildContentGrid()
                    : _buildEmptyState(),
              ),
            ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Content Library',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _getTextColor(),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.add, color: _getPrimaryColor(), size: 24),
                onPressed: _createNewLesson,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
              IconButton(
                icon: Icon(Icons.refresh_rounded,
                    color: _getPrimaryColor(), size: 24),
                onPressed: _refreshData,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ],
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getCardColor(),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatCard(
              value: '${_stats['total_videos'] ?? 0}',
              label: 'Videos',
            ),
            _buildStatCard(
              value: '${_stats['published_videos'] ?? 0}',
              label: 'Published',
            ),
            _buildStatCard(
              value: '${_stats['total_views'] ?? 0}',
              label: 'Total Views',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({required String value, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _getPrimaryColor(),
          ),
        ),
        const SizedBox(height: 4),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
          filled: true,
          fillColor: _getCardColor(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFolderSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Folders',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _getTextColor(),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _folders.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      _folders[index],
                      style: TextStyle(
                        fontSize: 12,
                        color: _selectedFolder == index
                            ? Colors.white
                            : _getTextColor(),
                      ),
                    ),
                    selected: _selectedFolder == index,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFolder = index;
                      });
                    },
                    backgroundColor: _getCardColor(),
                    selectedColor: _getPrimaryColor(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentHeader() {
    final displayVideos = _searchedVideos;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    );
  }

  Widget _buildContentGrid() {
    final displayVideos = _searchedVideos;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: displayVideos.length,
        itemBuilder: (context, index) {
          final video = displayVideos[index];
          return _buildContentCard(video);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create Lesson'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getPrimaryColor(),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContentCard(Map<String, dynamic> video) {
    final hasVideo = (video['video_url'] as String?)?.isNotEmpty ?? false;
    final thumbnailUrl = video['thumbnail_url'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getBorderColor()),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thumbnail - Fixed height
          SizedBox(
            height: 100,
            child: _buildVideoThumbnail(video, thumbnailUrl, hasVideo),
          ),

          // Content - Flexible but constrained
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title and icon
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _getLightColor(video['color'] as Color),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              video['icon'] as IconData,
                              color: video['color'] as Color,
                              size: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              video['title'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getTextColor(),
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Duration
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getBackgroundColor(),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 10, color: _getTextColorTertiary()),
                            const SizedBox(width: 4),
                            Text(
                              video['duration_text'] as String? ?? '0s',
                              style: TextStyle(
                                fontSize: 10,
                                color: _getTextColorTertiary(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Stats - Fixed height with reduced spacing
                  SizedBox(
                    height: 28, // Reduced from 32px to 28px
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.remove_red_eye_rounded,
                                size: 10, color: _getTextColorTertiary()),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${video['views']} views',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: _getTextColorTertiary(),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.people_rounded,
                                size: 10, color: _getTextColorTertiary()),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${video['students']} students',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: _getTextColorTertiary(),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
          ),

          // Actions - Fixed height with reduced padding
          Container(
            height: 34, // Reduced from 36px to 34px
            padding: const EdgeInsets.symmetric(
                vertical: 2), // Reduced vertical padding
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: _getBorderColor()),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _playVideo(video),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            size: 12, color: _getPrimaryColor()),
                        const SizedBox(width: 4),
                        Text(
                          'Play',
                          style: TextStyle(
                            fontSize: 10,
                            color: _getPrimaryColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                    width: 1,
                    height: 16,
                    color: _getBorderColor()), // Reduced height
                Expanded(
                  child: TextButton(
                    onPressed: () => _editContent(video),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_rounded,
                            size: 12, color: _getPrimaryColor()),
                        const SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 10,
                            color: _getPrimaryColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                    width: 1,
                    height: 16,
                    color: _getBorderColor()), // Reduced height
                Expanded(
                  child: TextButton(
                    onPressed: () => _viewAnalytics(video),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics_rounded,
                            size: 12, color: _getPrimaryColor()),
                        const SizedBox(width: 4),
                        Text(
                          'Stats',
                          style: TextStyle(
                            fontSize: 10,
                            color: _getPrimaryColor(),
                          ),
                        ),
                      ],
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

  Widget _buildVideoThumbnail(
      Map<String, dynamic> video, String? thumbnailUrl, bool hasVideo) {
    return GestureDetector(
      onTap: () => _playVideo(video),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
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
                      size: 32,
                    ),
                  )
                : null,
          ),
          if (hasVideo)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: _getPrimaryColor(),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _editContent(Map<String, dynamic> video) {
    // Your edit content logic here
  }

  void _viewAnalytics(Map<String, dynamic> video) {
    // Your analytics logic here
  }

  // Color helper methods
  Color _getLightColor(Color baseColor) {
    return baseColor.withAlpha(51);
  }

  Color _getTextColorSecondary() {
    return _getTextColor().withAlpha(153);
  }

  Color _getTextColorTertiary() {
    return _getTextColor().withAlpha(128);
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
