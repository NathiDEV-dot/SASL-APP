import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class LessonViewer extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final String studentCode;

  const LessonViewer({
    super.key,
    required this.lesson,
    required this.studentCode,
  });

  @override
  State<LessonViewer> createState() => _LessonViewerState();
}

class _LessonViewerState extends State<LessonViewer> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isFavorite = false;
  double _playbackSpeed = 1.0;
  bool _showSpeedOptions = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    _checkIfFavorite();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      final videoUrl = widget.lesson['video_url'] as String?;
      if (videoUrl != null && videoUrl.isNotEmpty) {
        _videoPlayerController = VideoPlayerController.network(videoUrl);
        await _videoPlayerController.initialize();

        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController,
          autoPlay: false,
          looping: false,
          allowFullScreen: true,
          allowMuting: true,
          showControlsOnInitialize: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.blue,
            handleColor: Colors.blue.shade700,
            backgroundColor: Colors.grey.shade300,
            bufferedColor: Colors.grey.shade400,
          ),
          placeholder: Container(
            color: Colors.grey.shade900,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
              ),
            ),
          ),
          overlay: widget.lesson['thumbnail_url'] != null
              ? Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(widget.lesson['thumbnail_url']!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              : null,
        );
      }
    } catch (e) {
      print('Error initializing video player: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkIfFavorite() async {
    // Simulate checking if lesson is in favorites
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() {
      _isFavorite = false; // This would come from your database
    });
  }

  Future<void> _toggleFavorite() async {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    // Here you would update the favorite status in your database
    // using student_favorites table
  }

  Future<void> _downloadVideo() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission required')),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final externalDir = await getExternalStorageDirectory();
      final downloadUrl = widget.lesson['video_url'] as String;
      final fileName = '${widget.lesson['title']}.mp4'.replaceAll(' ', '_');

      // For now, simulate download since we need proper setup
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        setState(() {
          _downloadProgress = i / 100;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download completed!'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  void _changePlaybackSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
      _videoPlayerController.setPlaybackSpeed(speed);
      _showSpeedOptions = false;
    });
  }

  void _markAsCompleted() {
    // Update student_progress table
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marked as completed!')),
    );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final educator = lesson['profiles'] as Map<String, dynamic>?;
    final educatorName = educator != null
        ? '${educator['first_name'] ?? ''} ${educator['last_name'] ?? ''}'
            .trim()
        : 'Unknown Educator';
    final educatorAvatar = educator?['avatar_url'] as String?;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Header with video player
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _isLoading
                  ? Container(
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _chewieController != null
                      ? Chewie(controller: _chewieController!)
                      : Container(
                          color: Colors.grey.shade900,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text('Video unavailable',
                                  style:
                                      TextStyle(color: Colors.grey.shade400)),
                            ],
                          ),
                        ),
            ),
            actions: [
              IconButton(
                icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : Colors.white),
                onPressed: _toggleFavorite,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'download') {
                    _downloadVideo();
                  } else if (value == 'speed') {
                    setState(() {
                      _showSpeedOptions = !_showSpeedOptions;
                    });
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(Icons.download),
                        SizedBox(width: 8),
                        Text('Download Video'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'speed',
                    child: Row(
                      children: [
                        Icon(Icons.speed),
                        SizedBox(width: 8),
                        Text('Playback Speed'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Lesson content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and metadata
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lesson['title']?.toString() ?? 'Untitled Lesson',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Educator info
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: educatorAvatar != null
                                      ? NetworkImage(educatorAvatar)
                                      : null,
                                  child: educatorAvatar == null
                                      ? Text(educatorName.isNotEmpty
                                          ? educatorName[0]
                                          : 'E')
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        educatorName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${lesson['subject']} • ${lesson['grade']}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Quick actions
                      Column(
                        children: [
                          _buildMetricChip(
                            Icons.play_circle_outline,
                            '${lesson['view_count'] ?? 0}',
                          ),
                          const SizedBox(height: 8),
                          _buildMetricChip(
                            Icons.download,
                            '${lesson['download_count'] ?? 0}',
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Action buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionButton(
                          Icons.download,
                          _isDownloading ? 'Downloading...' : 'Download',
                          _isDownloading ? null : _downloadVideo,
                          isActive: _isDownloading,
                        ),
                        _buildActionButton(
                          Icons.speed,
                          '${_playbackSpeed}x',
                          () => setState(() {
                            _showSpeedOptions = !_showSpeedOptions;
                          }),
                        ),
                        _buildActionButton(
                          Icons.check_circle,
                          'Mark Complete',
                          _markAsCompleted,
                        ),
                      ],
                    ),
                  ),

                  if (_isDownloading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: Colors.grey.shade300,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
                    ),
                  ],

                  if (_showSpeedOptions) ...[
                    const SizedBox(height: 16),
                    _buildSpeedOptions(),
                  ],

                  const SizedBox(height: 24),

                  // Description
                  if (lesson['description'] != null) ...[
                    const Text(
                      'About this lesson',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      lesson['description']!.toString(),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Lesson details
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lesson Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildEnhancedDetailItem(
                          'Subject',
                          lesson['subject']?.toString() ?? 'N/A',
                          Icons.subject,
                        ),
                        _buildEnhancedDetailItem(
                          'Grade Level',
                          lesson['grade']?.toString() ?? 'N/A',
                          Icons.school,
                        ),
                        _buildEnhancedDetailItem(
                          'Duration',
                          '${((lesson['duration'] as num? ?? 0) / 60).ceil()} minutes',
                          Icons.timer,
                        ),
                        _buildEnhancedDetailItem(
                          'Views',
                          '${lesson['view_count'] ?? 0}',
                          Icons.visibility,
                        ),
                        _buildEnhancedDetailItem(
                          'Downloads',
                          '${lesson['download_count'] ?? 0}',
                          Icons.download,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    ); // Added missing closing parenthesis and semicolon
  }

  Widget _buildActionButton(
      IconData icon, String label, VoidCallback? onPressed,
      {bool isActive = false}) {
    return Column(
      children: [
        IconButton.filled(
          onPressed: onPressed,
          icon: Icon(icon,
              color: isActive ? Colors.blue.shade400 : Colors.grey.shade700),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedOptions() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: speeds.map((speed) {
        return ActionChip(
          label: Text('${speed}x'),
          onPressed: () => _changePlaybackSpeed(speed),
          backgroundColor: _playbackSpeed == speed
              ? Colors.blue.shade100
              : Colors.grey.shade100,
        );
      }).toList(),
    );
  }

  Widget _buildEnhancedDetailItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
