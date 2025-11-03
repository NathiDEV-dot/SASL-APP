// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:signsync_academy/core/services/content_management_service.dart';
import 'package:signsync_academy/core/services/video_player_service.dart';
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
    Navigator.pushNamed(context, '/live_session');
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

  // ========== EDIT FUNCTIONALITY ==========

  void _editContent(Map<String, dynamic> video) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEditBottomSheet(video),
    );
  }

  Widget _buildEditBottomSheet(Map<String, dynamic> video) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _getTextColor().withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Edit Content',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _getTextColor(),
            ),
          ),
          const SizedBox(height: 16),
          _buildEditOption(
            icon: Icons.title_rounded,
            title: 'Edit Title & Description',
            onTap: () => _editTitleAndDescription(video),
          ),
          _buildEditOption(
            icon: Icons.video_library_rounded,
            title: 'Replace Video',
            onTap: () => _replaceVideo(video),
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: _getBorderColor(),
          ),
          const SizedBox(height: 8),
          _buildEditOption(
            icon: Icons.delete_rounded,
            title: 'Delete Lesson',
            color: Colors.red,
            onTap: () => _deleteLesson(video),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEditOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: color ?? _getPrimaryColor(),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? _getTextColor(),
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 24,
    );
  }

  void _editTitleAndDescription(Map<String, dynamic> video) {
    Navigator.pop(context); // Close bottom sheet
    _showEditDialog(video);
  }

  void _replaceVideo(Map<String, dynamic> video) async {
    Navigator.pop(context); // Close bottom sheet
    try {
      final newVideo = await _contentService.pickVideoFromGallery();
      if (newVideo != null) {
        if (!_contentService.validateVideoFile(newVideo)) {
          _showError('Video file too large. Maximum size is 500MB.');
          return;
        }

        setState(() {
          _isLoading = true;
        });

        // Use the ultra-fast replacement with progress
        await _contentService.replaceLessonVideo(
          lessonId: video['id'] as String,
          newVideoFile: newVideo,
          currentVideoUrl: video['video_url'] as String,
          onProgress: (progress) {
            // Update your progress UI here
            print(
                'Replacement progress: ${(progress * 100).toStringAsFixed(0)}%');
          },
        );

        await _refreshData();
        _showSuccess('Video replaced successfully');
      }
    } catch (e) {
      _showError('Failed to replace video: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _deleteLesson(Map<String, dynamic> video) {
    Navigator.pop(context); // Close bottom sheet
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Lesson', style: TextStyle(color: _getTextColor())),
        content: Text(
          'Are you sure you want to delete "${video['title']}"? This action cannot be undone.',
          style: TextStyle(color: _getTextColor()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDeleteLesson(video);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteLesson(Map<String, dynamic> video) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _contentService.deleteLesson(video['id'] as String);
      await _refreshData();
      _showSuccess('Lesson deleted successfully');
    } catch (e) {
      _showError('Failed to delete lesson: ${e.toString()}');
    }
  }

  void _showEditDialog(Map<String, dynamic> video) {
    final titleController =
        TextEditingController(text: video['title'] as String);
    final descriptionController =
        TextEditingController(text: video['description'] as String? ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Lesson', style: TextStyle(color: _getTextColor())),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_contentService.validateTitle(titleController.text)) {
                Navigator.pop(context);
                await _updateLessonDetails(
                  video,
                  titleController.text,
                  descriptionController.text,
                );
              } else {
                _showError('Please enter a valid title (minimum 2 characters)');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateLessonDetails(Map<String, dynamic> video, String newTitle,
      String newDescription) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _contentService.updateLessonTitle(video['id'] as String, newTitle);
      await _contentService.updateLessonDescription(
          video['id'] as String, newDescription);

      await _refreshData();
      _showSuccess('Lesson updated successfully');
    } catch (e) {
      _showError('Failed to update lesson: ${e.toString()}');
    }
  }

  void _viewAnalytics(Map<String, dynamic> video) {
    // Navigate to analytics screen
    Navigator.pushNamed(
      context,
      '/review_submissions',
      arguments: {
        'lessonId': video['id'],
        'lessonTitle': video['title'],
      },
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
          childAspectRatio: 0.75, // Adjusted to prevent gaps
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          SizedBox(
            height: 110,
            child: _buildVideoThumbnail(video, thumbnailUrl, hasVideo),
          ),

          // Content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and icon
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
                          size: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
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
                  const SizedBox(height: 4),

                  // Duration
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 10, color: _getTextColorTertiary()),
                      const SizedBox(width: 3),
                      Text(
                        video['duration_text'] as String? ?? '0s',
                        style: TextStyle(
                          fontSize: 9,
                          color: _getTextColorTertiary(),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Stats
                  Row(
                    children: [
                      Icon(Icons.remove_red_eye_rounded,
                          size: 10, color: _getTextColorTertiary()),
                      const SizedBox(width: 3),
                      Text(
                        '${video['views']}',
                        style: TextStyle(
                          fontSize: 9,
                          color: _getTextColorTertiary(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.people_rounded,
                          size: 10, color: _getTextColorTertiary()),
                      const SizedBox(width: 3),
                      Text(
                        '${video['students']}',
                        style: TextStyle(
                          fontSize: 9,
                          color: _getTextColorTertiary(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Actions
          Container(
            height: 36,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: _getBorderColor()),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _playVideo(video),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(11),
                    ),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded,
                              size: 14, color: _getPrimaryColor()),
                          const SizedBox(width: 4),
                          Text(
                            'Play',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _getPrimaryColor(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 20, color: _getBorderColor()),
                Expanded(
                  child: InkWell(
                    onTap: () => _editContent(video),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded,
                              size: 14, color: _getPrimaryColor()),
                          const SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _getPrimaryColor(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 20, color: _getBorderColor()),
                Expanded(
                  child: InkWell(
                    onTap: () => _viewAnalytics(video),
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(11),
                    ),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bar_chart_rounded,
                              size: 14, color: _getPrimaryColor()),
                          const SizedBox(width: 4),
                          Text(
                            'Stats',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _getPrimaryColor(),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        minimumSize: Size.zero,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: _getPrimaryColor()),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: _getPrimaryColor(),
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
