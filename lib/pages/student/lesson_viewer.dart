import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';

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
  bool _isCompleted = false;
  CancelToken? _downloadCancelToken;
  String? _downloadedFilePath;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    _checkLessonStatus();
    _checkIfDownloaded();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      final videoUrl = widget.lesson['video_url'] as String?;

      // Check if we have a downloaded version first
      if (_downloadedFilePath != null &&
          File(_downloadedFilePath!).existsSync()) {
        _videoPlayerController =
            VideoPlayerController.file(File(_downloadedFilePath!));
      } else if (videoUrl != null && videoUrl.isNotEmpty) {
        _videoPlayerController = VideoPlayerController.network(videoUrl);
      } else {
        throw Exception('No video available');
      }

      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControlsOnInitialize: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF4CAF50),
          handleColor: const Color(0xFF45a049),
          backgroundColor: Colors.grey.shade300,
          bufferedColor: Colors.grey.shade400,
        ),
        placeholder: Container(
          color: Colors.grey.shade900,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.green.shade400),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading video...',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Container(
            color: Colors.grey.shade900,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Video unavailable\n$errorMessage',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('Error initializing video player: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkIfDownloaded() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'lesson_${widget.lesson['id']}.mp4';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        setState(() {
          _downloadedFilePath = filePath;
        });
      }
    } catch (e) {
      print('Error checking downloaded file: $e');
    }
  }

  Future<void> _checkLessonStatus() async {
    try {
      final response = await Supabase.instance.client
          .from('student_progress')
          .select()
          .eq('student_id', widget.studentCode)
          .eq('lesson_id', widget.lesson['id'])
          .maybeSingle();

      if (response != null) {
        setState(() {
          _isCompleted = response['completed'] ?? false;
        });
      }
    } catch (e) {
      print('Error checking lesson status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      setState(() {
        _isFavorite = !_isFavorite;
      });

      if (_isFavorite) {
        await Supabase.instance.client.from('student_favorites').upsert({
          'student_id': widget.studentCode,
          'lesson_id': widget.lesson['id'],
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        await Supabase.instance.client
            .from('student_favorites')
            .delete()
            .eq('student_id', widget.studentCode)
            .eq('lesson_id', widget.lesson['id']);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _isFavorite ? 'Added to favorites!' : 'Removed from favorites'),
          backgroundColor: _isFavorite ? Colors.green : Colors.grey,
        ),
      );
    } catch (e) {
      print('Error updating favorite: $e');
      setState(() {
        _isFavorite = !_isFavorite;
      });
    }
  }

  Future<void> _downloadVideo() async {
    final videoUrl = widget.lesson['video_url'] as String?;
    if (videoUrl == null || videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No video available for download'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Request storage permission
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Storage permission required to download videos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadCancelToken = CancelToken();
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'lesson_${widget.lesson['id']}.mp4';
      final filePath = '${directory.path}/$fileName';

      final dio = Dio();

      await dio.download(
        videoUrl,
        filePath,
        cancelToken: _downloadCancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      // Update download count in database
      await Supabase.instance.client.from('lessons').update({
        'download_count': (widget.lesson['download_count'] ?? 0) + 1,
      }).eq('id', widget.lesson['id']);

      setState(() {
        _downloadedFilePath = filePath;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Download completed!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OPEN',
            textColor: Colors.white,
            onPressed: () {
              _showDownloadSuccessDialog(filePath);
            },
          ),
        ),
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadCancelToken = null;
        });
      }
    }
  }

  void _showDownloadSuccessDialog(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Complete'),
        content: const Text(
            'Video has been downloaded successfully. You can now watch it offline.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _switchToLocalVideo(filePath);
            },
            child: const Text('PLAY OFFLINE'),
          ),
        ],
      ),
    );
  }

  Future<void> _switchToLocalVideo(String filePath) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Dispose old controllers
      _chewieController?.dispose();
      _videoPlayerController.dispose();

      // Create new controller with local file
      _videoPlayerController = VideoPlayerController.file(File(filePath));
      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControlsOnInitialize: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF4CAF50),
          handleColor: const Color(0xFF45a049),
          backgroundColor: Colors.grey.shade300,
          bufferedColor: Colors.grey.shade400,
        ),
      );

      setState(() {
        _isLoading = false;
        _downloadedFilePath = filePath;
      });
    } catch (e) {
      print('Error switching to local video: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _cancelDownload() {
    _downloadCancelToken?.cancel('Download cancelled by user');
  }

  Future<void> _deleteDownloadedVideo() async {
    if (_downloadedFilePath != null) {
      try {
        final file = File(_downloadedFilePath!);
        if (await file.exists()) {
          await file.delete();
        }

        setState(() {
          _downloadedFilePath = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Downloaded video deleted'),
            backgroundColor: Colors.green,
          ),
        );

        // Switch back to online version
        await _switchToOnlineVideo();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _switchToOnlineVideo() async {
    try {
      setState(() {
        _isLoading = true;
      });

      _chewieController?.dispose();
      _videoPlayerController.dispose();

      final videoUrl = widget.lesson['video_url'] as String?;
      if (videoUrl != null && videoUrl.isNotEmpty) {
        _videoPlayerController = VideoPlayerController.network(videoUrl);
        await _videoPlayerController.initialize();

        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
          allowMuting: true,
          showControlsOnInitialize: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: const Color(0xFF4CAF50),
            handleColor: const Color(0xFF45a049),
            backgroundColor: Colors.grey.shade300,
            bufferedColor: Colors.grey.shade400,
          ),
        );
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error switching to online video: $e');
      setState(() {
        _isLoading = false;
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

  Future<void> _markAsCompleted() async {
    try {
      await Supabase.instance.client.from('student_progress').upsert({
        'student_id': widget.studentCode,
        'lesson_id': widget.lesson['id'],
        'completed': true,
        'progress_percentage': 100,
        'completed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      setState(() {
        _isCompleted = true;
      });

      await Supabase.instance.client.from('lessons').update({
        'view_count': (widget.lesson['view_count'] ?? 0) + 1,
      }).eq('id', widget.lesson['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lesson marked as completed! 🎉'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking as completed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getSubjectColor(String? subject) {
    switch (subject?.toLowerCase()) {
      case 'mathematics':
      case 'math':
        return const Color(0xFF2196F3);
      case 'science':
        return const Color(0xFFFF9800);
      case 'english':
        return const Color(0xFF4CAF50);
      case 'south african sign language':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF607D8B);
    }
  }

  @override
  void dispose() {
    _downloadCancelToken?.cancel();
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
    final subject = lesson['subject']?.toString() ?? 'General';
    final subjectColor = _getSubjectColor(subject);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: _isLoading
                  ? Container(
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      ),
                    )
                  : _chewieController != null &&
                          _videoPlayerController.value.isInitialized
                      ? Stack(
                          children: [
                            Chewie(controller: _chewieController!),
                            if (_downloadedFilePath != null)
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.download_done,
                                          size: 14, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'OFFLINE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Container(
                          color: Colors.grey.shade900,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_circle_filled,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Video not available',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
            actions: [
              if (_downloadedFilePath != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: _deleteDownloadedVideo,
                  tooltip: 'Delete downloaded video',
                ),
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : Colors.white,
                  size: 28,
                ),
                onPressed: _toggleFavorite,
              ),
            ],
          ),
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
                            // Subject badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: subjectColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: subjectColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                subject.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: subjectColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Title
                            Text(
                              lesson['title']?.toString() ?? 'Untitled Lesson',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Educator info
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: educatorAvatar != null
                                      ? NetworkImage(educatorAvatar)
                                      : null,
                                  child: educatorAvatar == null
                                      ? Text(
                                          educatorName.isNotEmpty
                                              ? educatorName[0]
                                              : 'E',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        )
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
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
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
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Action buttons
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        if (_isDownloading)
                          _buildCancelDownloadButton()
                        else
                          _buildDownloadButton(subjectColor),
                        _buildSpeedButton(),
                        _buildCompleteButton(),
                      ],
                    ),
                  ),

                  if (_isDownloading) _buildDownloadProgress(),

                  if (_showSpeedOptions) ...[
                    const SizedBox(height: 16),
                    _buildSpeedOptions(),
                  ],

                  const SizedBox(height: 32),

                  // Description
                  if (lesson['description'] != null &&
                      lesson['description'].toString().isNotEmpty) ...[
                    const Text(
                      'About this lesson',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        lesson['description']!.toString(),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade800,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Lesson details
                  const Text(
                    'Lesson Details',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildEnhancedDetailItem(
                          'Subject',
                          lesson['subject']?.toString() ?? 'N/A',
                          Icons.subject,
                          subjectColor,
                        ),
                        _buildEnhancedDetailItem(
                          'Grade Level',
                          lesson['grade']?.toString() ?? 'N/A',
                          Icons.school,
                          const Color(0xFF9C27B0),
                        ),
                        _buildEnhancedDetailItem(
                          'Duration',
                          '${((lesson['duration'] as num? ?? 0) / 60).ceil()} minutes',
                          Icons.timer,
                          const Color(0xFFFF9800),
                        ),
                        _buildEnhancedDetailItem(
                          'Views',
                          '${lesson['view_count'] ?? 0}',
                          Icons.visibility,
                          const Color(0xFF2196F3),
                        ),
                        _buildEnhancedDetailItem(
                          'Downloads',
                          '${lesson['download_count'] ?? 0}',
                          Icons.download,
                          const Color(0xFF4CAF50),
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

  Widget _buildDownloadButton(Color color) {
    return _buildActionButton(
      _downloadedFilePath != null ? Icons.download_done : Icons.download,
      _downloadedFilePath != null ? 'Downloaded' : 'Download',
      _downloadedFilePath != null ? null : _downloadVideo,
      color: _downloadedFilePath != null ? Colors.green : color,
    );
  }

  Widget _buildCancelDownloadButton() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: IconButton(
            onPressed: _cancelDownload,
            icon: const Icon(
              Icons.cancel,
              color: Colors.red,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cancel',
          style: TextStyle(
            fontSize: 12,
            color: Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedButton() {
    return _buildActionButton(
      Icons.speed,
      '${_playbackSpeed}x',
      () => setState(() {
        _showSpeedOptions = !_showSpeedOptions;
      }),
      color: const Color(0xFFFF9800),
    );
  }

  Widget _buildCompleteButton() {
    return _buildActionButton(
      _isCompleted ? Icons.check_circle : Icons.check_circle_outline,
      _isCompleted ? 'Completed' : 'Mark Complete',
      _isCompleted ? null : _markAsCompleted,
      color: _isCompleted ? const Color(0xFF4CAF50) : Colors.grey.shade600,
    );
  }

  Widget _buildDownloadProgress() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Downloading... ${(_downloadProgress * 100).toInt()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${(_downloadProgress * 100).toInt()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF2196F3),
              ),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback? onPressed, {
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
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
        return FilterChip(
          label: Text(
            '${speed}x',
            style: TextStyle(
              color: _playbackSpeed == speed ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          selected: _playbackSpeed == speed,
          onSelected: (_) => _changePlaybackSpeed(speed),
          backgroundColor: Colors.grey.shade100,
          selectedColor: const Color(0xFFFF9800),
          checkmarkColor: Colors.white,
        );
      }).toList(),
    );
  }

  Widget _buildEnhancedDetailItem(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
