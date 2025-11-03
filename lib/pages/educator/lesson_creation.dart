// ignore_for_file: deprecated_member_use, unused_field, unused_import, unused_local_variable

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import '../../core/services/lesson_creation_service.dart';
import 'video_editor.dart';

class LessonCreation extends StatefulWidget {
  const LessonCreation({Key? key}) : super(key: key);

  @override
  State<LessonCreation> createState() => _LessonCreationState();
}

class _LessonCreationState extends State<LessonCreation> {
  final LessonCreationService _lessonService = LessonCreationService();
  final _formKey = GlobalKey<FormState>();

  // Form fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedSubject = 'Mathematics';
  String _selectedGrade = 'Grade 10';
  File? _selectedVideo;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _scheduleForLater = false;
  DateTime? _scheduledDate;
  String? _videoDuration;

  // Video player controller for preview
  VideoPlayerController? _videoController;
  bool _isVideoInitializing = false;
  bool _isVideoPlaying = false;

  List<String> _availableSubjects = [];

  // Colors
  final Color _primaryColor = const Color(0xFF4361EE);
  final Color _secondaryColor = const Color(0xFF3A0CA3);
  final Color _accentColor = const Color(0xFF4CC9F0);
  final Color _successColor = const Color(0xFF4ADE80);
  final Color _warningColor = const Color(0xFFF59E0B);
  final Color _errorColor = const Color(0xFFEF4444);
  final Color _backgroundColor = const Color(0xFFF8FAFC);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF1E293B);
  final Color _hintColor = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadEducatorData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadEducatorData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final subjects = await _lessonService.getEducatorSubjects(user.id);
        final grade = await _lessonService.getEducatorGrade(user.id);

        setState(() {
          _availableSubjects = subjects;
          _selectedSubject =
              subjects.isNotEmpty ? subjects.first : 'Mathematics';
          _selectedGrade = grade;
        });
      }
    } catch (e) {
      debugPrint('Error loading educator data: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final videoFile = await _lessonService.pickVideo();
      if (videoFile != null) {
        await _handleVideoSelected(videoFile);
      }
    } catch (e) {
      _showErrorDialog('Video Selection Error', e.toString());
    }
  }

  Future<void> _recordVideo() async {
    try {
      setState(() {
        _isVideoInitializing = true;
      });

      final videoFile = await _lessonService.recordVideo();

      if (videoFile != null) {
        await _handleVideoSelected(videoFile);
      }
    } catch (e) {
      _showErrorDialog('Recording Failed', e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isVideoInitializing = false;
        });
      }
    }
  }

  Future<void> _handleVideoSelected(File videoFile) async {
    try {
      _lessonService.validateVideoFile(videoFile);

      // Dispose previous controller
      await _disposeVideoController();

      setState(() {
        _selectedVideo = videoFile;
        _videoDuration = null;
        _isVideoInitializing = true;
        _isVideoPlaying = false;
      });

      // Get actual video duration
      final duration = await _lessonService.getVideoDuration(videoFile);
      setState(() {
        _videoDuration =
            '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
      });

      // Initialize video controller for preview
      _videoController = VideoPlayerController.file(videoFile);
      await _videoController!.initialize();

      // Add listener to track play state
      _videoController!.addListener(() {
        if (mounted) {
          setState(() {
            _isVideoPlaying = _videoController!.value.isPlaying;
          });
        }
      });

      setState(() {
        _isVideoInitializing = false;
      });
    } catch (e) {
      setState(() {
        _isVideoInitializing = false;
      });
      _showErrorDialog('Video Error', e.toString());
    }
  }

  Future<void> _disposeVideoController() async {
    if (_videoController != null) {
      await _videoController!.pause();
      await _videoController!.dispose();
      _videoController = null;
    }
  }

  Future<void> _replaceVideo() async {
    try {
      // Show options to pick from gallery or record new video
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace Video'),
          content: const Text('Choose how you want to replace the video:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: const Text('Choose from Gallery'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: const Text('Record New Video'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (source != null) {
        final File? newVideoFile;
        if (source == ImageSource.gallery) {
          newVideoFile = await _lessonService.pickVideo();
        } else {
          newVideoFile = await _lessonService.recordVideo();
        }

        if (newVideoFile != null) {
          await _handleVideoSelected(newVideoFile);
          _showSuccessSnackbar('Video replaced successfully!');
        }
      }
    } catch (e) {
      _showErrorDialog('Replace Video Error', e.toString());
    }
  }

  Future<void> _editVideo() async {
    if (_selectedVideo == null) return;

    try {
      final editedFile = await Navigator.push<File>(
        context,
        MaterialPageRoute(
          builder: (context) => VideoEditor(
            initialVideo: _selectedVideo!,
            lessonTitle: _titleController.text.isEmpty
                ? 'Edit Video'
                : _titleController.text,
          ),
        ),
      );

      if (editedFile != null) {
        await _handleVideoSelected(editedFile);
        _showSuccessSnackbar('Video edited successfully!');
      }
    } catch (e) {
      _showErrorDialog('Video Editing Error', e.toString());
    }
  }

  Future<void> _createLesson() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVideo == null) {
      _showErrorDialog(
          'Missing Video', 'Please select or record a video for your lesson.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Step 1: Quick validation (5%)
      setState(() => _uploadProgress = 0.05);

      // Step 2: Get duration and create lesson in parallel (25%)
      final results = await Future.wait([
        _lessonService.getVideoDuration(_selectedVideo!),
        _lessonService.createLesson(
          title: _titleController.text.trim(),
          subject: _selectedSubject,
          grade: _selectedGrade,
          durationSeconds: 0, // Will be updated after duration is known
          educatorId: user.id,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          isPublished: !_scheduleForLater,
          scheduledPublish: _scheduleForLater ? _scheduledDate : null,
        ),
      ]);

      final duration = results[0] as Duration;
      final lessonId = results[1] as String;

      // Update lesson with actual duration
      await _lessonService.updateLessonMedia(
        lessonId: lessonId,
        videoUrl: '', // Will be updated after upload
      );

      setState(() => _uploadProgress = 0.30);

      // Step 3: Upload video and generate thumbnail in parallel (65%)
      final uploadResults = await Future.wait([
        _lessonService.uploadVideo(
          lessonId: lessonId,
          educatorId: user.id,
          videoFile: _selectedVideo!,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _uploadProgress = 0.30 + (progress * 0.65);
              });
            }
          },
        ),
        _lessonService.generateThumbnail(
          lessonId: lessonId,
          educatorId: user.id,
          videoFile: _selectedVideo!,
        ),
      ], eagerError: true);

      final videoUrl = uploadResults[0] as String;
      final thumbnailUrl = uploadResults[1] as String?;

      setState(() => _uploadProgress = 0.95);

      // Step 4: Final update with URLs (5%)
      await _lessonService.updateLessonMedia(
        lessonId: lessonId,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
      );

      setState(() => _uploadProgress = 1.0);

      // Show success message
      await _showSuccessDialog();

      // Navigate back
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Lesson Creation Failed', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: _successColor, size: 28),
            const SizedBox(width: 12),
            Text(
              'Success!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textColor,
              ),
            ),
          ],
        ),
        content: Text(
          _scheduleForLater
              ? 'Your lesson "${_titleController.text}" has been scheduled successfully!'
              : 'Your lesson "${_titleController.text}" has been published successfully!',
          style: TextStyle(
            fontSize: 16,
            color: _textColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: _errorColor, size: 28),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textColor,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 16,
            color: _textColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _successColor,
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              message,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _selectScheduleDate() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate =
        _scheduledDate ?? now.add(const Duration(minutes: 5));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.add(const Duration(minutes: 5)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
              onSurface: _textColor,
            ),
            dialogBackgroundColor: _cardColor,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final TimeOfDay initialTime = _scheduledDate != null
          ? TimeOfDay(
              hour: _scheduledDate!.hour, minute: _scheduledDate!.minute)
          : TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5)));

      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: initialTime,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: _primaryColor,
                onPrimary: Colors.white,
                surface: _cardColor,
                onSurface: _textColor,
              ),
              dialogBackgroundColor: _cardColor,
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        final DateTime scheduledDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        );

        // Validate that scheduled time is at least 5 minutes from now
        if (scheduledDateTime.isBefore(now.add(const Duration(minutes: 5)))) {
          _showErrorDialog(
            'Invalid Schedule Time',
            'Please select a time at least 5 minutes from now.',
          );
          return;
        }

        setState(() {
          _scheduledDate = scheduledDateTime;
        });
      }
    }
  }

  String _formatScheduleDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final scheduledDay = DateTime(date.year, date.month, date.day);

    String dayPrefix;
    if (scheduledDay == today) {
      dayPrefix = 'Today';
    } else if (scheduledDay == tomorrow) {
      dayPrefix = 'Tomorrow';
    } else {
      dayPrefix = '${date.day}/${date.month}/${date.year}';
    }

    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$dayPrefix at $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Create New Lesson',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isUploading ? _buildUploadProgress() : _buildLessonForm(),
    );
  }

  Widget _buildUploadProgress() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: _uploadProgress,
                    strokeWidth: 8,
                    backgroundColor: _hintColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  ),
                ),
                Text(
                  '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              _scheduleForLater
                  ? 'Scheduling Your Lesson...'
                  : 'Publishing Your Lesson...',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _uploadProgress < 0.3
                  ? 'Preparing lesson...'
                  : _uploadProgress < 0.7
                      ? 'Uploading video...'
                      : _uploadProgress < 0.9
                          ? 'Generating thumbnail...'
                          : 'Finalizing...',
              style: TextStyle(
                fontSize: 16,
                color: _hintColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: _hintColor.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonForm() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Video Selection Section
              _buildVideoSelectionSection(),
              const SizedBox(height: 24),

              // Lesson Details Section
              _buildLessonDetailsSection(),
              const SizedBox(height: 24),

              // Schedule Options
              _buildScheduleSection(),
              const SizedBox(height: 32),

              // Create Button
              _buildCreateButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoSelectionSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.videocam_rounded,
                    color: _primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Lesson Video',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedVideo != null)
              _buildVideoPreview()
            else
              _buildVideoSelectionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSelectionButtons() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hintColor.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_rounded,
                size: 48,
                color: _hintColor,
              ),
              const SizedBox(height: 12),
              Text(
                'Add your lesson video',
                style: TextStyle(
                  fontSize: 16,
                  color: _hintColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'MP4, MOV, AVI, MKV, or WEBM • Max 500MB',
                style: TextStyle(
                  fontSize: 12,
                  color: _hintColor.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _pickVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_library_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Choose Video',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _recordVideo,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryColor,
                  side: BorderSide(color: _primaryColor, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Record',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoPreview() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_videoController != null &&
                  _videoController!.value.isInitialized)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: VideoPlayer(_videoController!),
                )
              else if (_isVideoInitializing)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: _primaryColor),
                        const SizedBox(height: 16),
                        Text(
                          'Loading video preview...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam_rounded,
                            size: 48, color: Colors.white),
                        const SizedBox(height: 12),
                        Text(
                          _selectedVideo!.path.split('/').last,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_videoDuration != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Duration: $_videoDuration',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // Play/Pause overlay
              if (_videoController != null &&
                  _videoController!.value.isInitialized)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_videoController!.value.isPlaying) {
                          _videoController!.pause();
                        } else {
                          _videoController!.play();
                        }
                      });
                    },
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black
                                .withOpacity(_isVideoPlaying ? 0.0 : 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                            size: _isVideoPlaying ? 32 : 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Video info overlay
              if (_videoDuration != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _videoDuration!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _replaceVideo,
                icon: Icon(Icons.swap_horiz_rounded,
                    color: _primaryColor, size: 20),
                label: Text(
                  'Replace Video',
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: _primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _editVideo,
                icon: const Icon(Icons.edit_rounded, size: 20),
                label: const Text(
                  'Edit Video',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _secondaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLessonDetailsSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.info_rounded,
                    color: _accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Lesson Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Lesson Title *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Enter a descriptive title for your lesson',
                hintStyle: TextStyle(color: _hintColor),
                filled: true,
                fillColor: _backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              style: TextStyle(
                fontSize: 16,
                color: _textColor,
                fontWeight: FontWeight.w500,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a lesson title';
                }
                if (value.trim().length < 5) {
                  return 'Title must be at least 5 characters long';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              'Description',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: 'Add a description for your lesson (optional)',
                hintStyle: TextStyle(color: _hintColor),
                filled: true,
                fillColor: _backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              style: TextStyle(
                fontSize: 16,
                color: _textColor,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 4,
              textAlignVertical: TextAlignVertical.top,
            ),
            const SizedBox(height: 16),

            // Subject and Grade Display
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject Dropdown - Full width
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subject *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedSubject,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: _backgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: _primaryColor, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        items: _availableSubjects.map((String subject) {
                          return DropdownMenuItem<String>(
                            value: subject,
                            child: Text(
                              subject,
                              style: TextStyle(
                                fontSize: 16,
                                color: _textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedSubject = newValue!;
                          });
                        },
                        style: TextStyle(
                          fontSize: 16,
                          color: _textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        dropdownColor: _cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Grade Display (Non-editable) - Full width
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grade',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _hintColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.school_rounded,
                            color: _primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _selectedGrade,
                            style: TextStyle(
                              fontSize: 16,
                              color: _textColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.lock_outline,
                            color: _hintColor,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Grade is automatically assigned based on your educator profile',
              style: TextStyle(
                fontSize: 12,
                color: _hintColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.schedule_rounded,
                    color: _warningColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Publishing Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Publish Now Option
            GestureDetector(
              onTap: () {
                setState(() {
                  _scheduleForLater = false;
                  _scheduledDate = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !_scheduleForLater
                        ? _primaryColor
                        : _hintColor.withOpacity(0.3),
                    width: !_scheduleForLater ? 2 : 1,
                  ),
                  boxShadow: !_scheduleForLater
                      ? [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              !_scheduleForLater ? _primaryColor : _hintColor,
                          width: 2,
                        ),
                        color: !_scheduleForLater
                            ? _primaryColor
                            : Colors.transparent,
                      ),
                      child: !_scheduleForLater
                          ? Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Publish Now',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Make lesson available immediately',
                            style: TextStyle(
                              fontSize: 14,
                              color: _hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.rocket_launch_rounded,
                      color: !_scheduleForLater ? _primaryColor : _hintColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Schedule for Later Option
            GestureDetector(
              onTap: () {
                setState(() {
                  _scheduleForLater = true;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _scheduleForLater
                        ? _primaryColor
                        : _hintColor.withOpacity(0.3),
                    width: _scheduleForLater ? 2 : 1,
                  ),
                  boxShadow: _scheduleForLater
                      ? [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _scheduleForLater ? _primaryColor : _hintColor,
                          width: 2,
                        ),
                        color: _scheduleForLater
                            ? _primaryColor
                            : Colors.transparent,
                      ),
                      child: _scheduleForLater
                          ? Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Schedule for Later',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Publish at a specific date and time',
                            style: TextStyle(
                              fontSize: 14,
                              color: _hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.calendar_today_rounded,
                      color: _scheduleForLater ? _primaryColor : _hintColor,
                    ),
                  ],
                ),
              ),
            ),

            // Date Picker
            if (_scheduleForLater) ...[
              const SizedBox(height: 20),
              Text(
                'Schedule Time',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _selectScheduleDate,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          color: _primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Schedule Date & Time',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _textColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _scheduledDate == null
                                  ? 'Tap to select date and time'
                                  : _formatScheduleDate(_scheduledDate!),
                              style: TextStyle(
                                fontSize: 15,
                                color: _scheduledDate == null
                                    ? _hintColor
                                    : _primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: _hintColor,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: _warningColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Schedule time must be at least 5 minutes from now',
                        style: TextStyle(
                          fontSize: 12,
                          color: _warningColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _createLesson,
          style: ElevatedButton.styleFrom(
            backgroundColor: _scheduleForLater ? _warningColor : _primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            shadowColor: _scheduleForLater
                ? _warningColor.withOpacity(0.3)
                : _primaryColor.withOpacity(0.3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _scheduleForLater
                    ? Icons.schedule_rounded
                    : Icons.rocket_launch_rounded,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _scheduleForLater ? 'Schedule Lesson' : 'Publish Lesson Now',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
