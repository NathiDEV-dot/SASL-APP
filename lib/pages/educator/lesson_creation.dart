// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
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

  bool _isVideoInitializing = false;
  List<String> _availableSubjects = [];

  // Modern Color Scheme
  final Color _primaryColor = const Color(0xFF6366F1);
  final Color _primaryDark = const Color(0xFF4F46E5);
  final Color _secondaryColor = const Color(0xFFEC4899);
  final Color _accentColor = const Color(0xFF06B6D4);
  final Color _successColor = const Color(0xFF10B981);
  final Color _warningColor = const Color(0xFFF59E0B);
  final Color _errorColor = const Color(0xFFEF4444);
  final Color _backgroundColor = const Color(0xFFF8FAFC);
  final Color _surfaceColor = Colors.white;
  final Color _textPrimary = const Color(0xFF1E293B);
  final Color _textSecondary = const Color(0xFF64748B);
  final Color _textTertiary = const Color(0xFF94A3B8);
  final Color _borderColor = const Color(0xFFE2E8F0);

  // Gradients
  final Gradient _primaryGradient = const LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _loadEducatorData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
      final isCameraAvailable = await _lessonService.checkCameraAvailability();
      if (!isCameraAvailable) {
        _showErrorDialog(
            'Camera Unavailable', 'No camera found on this device.');
        return;
      }

      setState(() {
        _isVideoInitializing = true;
        _selectedVideo = null;
      });

      final videoFile = await _lessonService.recordVideo();

      if (videoFile != null) {
        await _handleVideoSelected(videoFile);
        _showSuccessSnackbar('Video recorded successfully!');
      }
    } catch (e) {
      final userFriendlyError = _getRecordingErrorMessage(e);
      _showErrorDialog('Recording Failed', userFriendlyError);
    } finally {
      if (mounted) {
        setState(() {
          _isVideoInitializing = false;
        });
      }
    }
  }

  String _getRecordingErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('permission')) {
      return 'Camera permission denied. Please enable camera permissions in app settings.';
    } else if (errorString.contains('camera') && errorString.contains('busy')) {
      return 'Camera is busy. Please close other camera apps and try again.';
    } else if (errorString.contains('timeout')) {
      return 'Recording timed out. Please try again.';
    } else if (errorString.contains('file') ||
        errorString.contains('storage')) {
      return 'Storage error. Please check available storage space.';
    } else {
      return 'Recording failed. Please try again. Error: ${error.toString()}';
    }
  }

  Future<void> _handleVideoSelected(File videoFile) async {
    try {
      _lessonService.validateVideoFile(videoFile);

      setState(() {
        _selectedVideo = videoFile;
        _videoDuration = null;
        _isVideoInitializing = true;
      });

      final duration = await _lessonService.getVideoDuration(videoFile);
      setState(() {
        _videoDuration =
            '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
        _isVideoInitializing = false;
      });

      debugPrint('Video selected successfully - duration: $_videoDuration');
    } catch (e) {
      setState(() {
        _isVideoInitializing = false;
      });
      debugPrint('Video handling completed without preview: $e');
      _showSuccessSnackbar('Video selected successfully!');
    }
  }

  Future<void> _replaceVideo() async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Replace Video',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ),
                _buildActionTile(
                  icon: Icons.video_library_rounded,
                  title: 'Choose from Gallery',
                  subtitle: 'Select from your device',
                  color: _primaryColor,
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                _buildActionTile(
                  icon: Icons.videocam_rounded,
                  title: 'Record New Video',
                  subtitle: 'Record with camera',
                  color: _secondaryColor,
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textSecondary,
                      side: BorderSide(color: _borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
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

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: _textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: _textSecondary),
      ),
      trailing:
          Icon(Icons.arrow_forward_ios_rounded, color: _textTertiary, size: 16),
      onTap: onTap,
    );
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

      setState(() => _uploadProgress = 0.05);

      final results = await Future.wait([
        _lessonService.getVideoDuration(_selectedVideo!),
        _lessonService.createLesson(
          title: _titleController.text.trim(),
          subject: _selectedSubject,
          grade: _selectedGrade,
          durationSeconds: 0,
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

      await _lessonService.updateLessonMedia(
        lessonId: lessonId,
        videoUrl: '',
      );

      setState(() => _uploadProgress = 0.30);

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

      await _lessonService.updateLessonMedia(
        lessonId: lessonId,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
      );

      setState(() => _uploadProgress = 1.0);

      await _showSuccessDialog();

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
      builder: (context) => Dialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: _primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'Success!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _scheduleForLater
                    ? 'Your lesson "${_titleController.text}" has been scheduled successfully!'
                    : 'Your lesson "${_titleController.text}" has been published successfully!',
                style: TextStyle(
                  fontSize: 16,
                  color: _textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _errorColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline_rounded,
                    color: _errorColor, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  color: _textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textSecondary,
                        side: BorderSide(color: _borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Try Again'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
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
              surface: _surfaceColor,
              onSurface: _textPrimary,
            ),
            dialogBackgroundColor: _surfaceColor,
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
                surface: _surfaceColor,
                onSurface: _textPrimary,
              ),
              dialogBackgroundColor: _surfaceColor,
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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: _isUploading ? _buildUploadProgress() : _buildLessonForm(),
    );
  }

  Widget _buildUploadProgress() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: _uploadProgress,
                    strokeWidth: 8,
                    backgroundColor: _textTertiary.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  ),
                ),
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: _primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
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
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _uploadProgress < 0.3
                  ? 'Preparing lesson content...'
                  : _uploadProgress < 0.7
                      ? 'Uploading video content...'
                      : _uploadProgress < 0.9
                          ? 'Generating preview...'
                          : 'Finalizing...',
              style: TextStyle(
                fontSize: 16,
                color: _textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: _textTertiary.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
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
    );
  }

  Widget _buildVideoSelectionSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: _primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.videocam_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Lesson Video',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
          height: 160,
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _borderColor,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.video_library_rounded,
                  size: 32,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add your lesson video',
                style: TextStyle(
                  fontSize: 16,
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'MP4, MOV, AVI, MKV, or WEBM • Max 500MB',
                style: TextStyle(
                  fontSize: 13,
                  color: _textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.video_library_rounded, size: 20),
                label: const Text(
                  'Choose Video',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildRecordButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildRecordButton() {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: _isVideoInitializing ? null : _recordVideo,
        icon: _isVideoInitializing
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _primaryColor,
                ),
              )
            : Icon(Icons.videocam_rounded, size: 20, color: _primaryColor),
        label: Text(
          _isVideoInitializing ? 'Recording...' : 'Record',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _isVideoInitializing ? _textTertiary : _primaryColor,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryColor,
          side: BorderSide(
              color: _isVideoInitializing ? _borderColor : _primaryColor,
              width: 2),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _primaryColor.withOpacity(0.1),
                _accentColor.withOpacity(0.1)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _primaryColor.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.videocam_rounded,
                  size: 36,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Video Ready',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (_videoDuration != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Duration: $_videoDuration',
                    style: TextStyle(
                      color: _primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                _selectedVideo!.path.split('/').last,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _replaceVideo,
                icon: Icon(Icons.swap_horiz_rounded,
                    color: _primaryColor, size: 20),
                label: Text(
                  'Replace',
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
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
                  'Edit',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
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
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_accentColor, _primaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.info_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Lesson Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Lesson Title *',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Enter a descriptive title for your lesson',
                hintStyle: TextStyle(color: _textTertiary),
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
                color: _textPrimary,
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
            const SizedBox(height: 20),

            // Description
            Text(
              'Description',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: 'Add a description for your lesson (optional)',
                hintStyle: TextStyle(color: _textTertiary),
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
                color: _textPrimary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 4,
              textAlignVertical: TextAlignVertical.top,
            ),
            const SizedBox(height: 20),

            // Subject and Grade
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subject *',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
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
                                  fontSize: 15,
                                  color: _textPrimary,
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
                            fontSize: 15,
                            color: _textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          dropdownColor: _surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grade',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: _backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _borderColor),
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
                                fontSize: 15,
                                color: _textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.lock_outline,
                              color: _textTertiary,
                              size: 16,
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
            Text(
              'Grade is automatically assigned based on your educator profile',
              style: TextStyle(
                fontSize: 12,
                color: _textTertiary,
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
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_warningColor, _secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Publishing Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Publish Now Option
            _buildPublishOption(
              isSelected: !_scheduleForLater,
              icon: Icons.rocket_launch_rounded,
              title: 'Publish Now',
              subtitle: 'Make lesson available immediately',
              onTap: () {
                setState(() {
                  _scheduleForLater = false;
                  _scheduledDate = null;
                });
              },
            ),
            const SizedBox(height: 16),

            // Schedule for Later Option
            _buildPublishOption(
              isSelected: _scheduleForLater,
              icon: Icons.calendar_today_rounded,
              title: 'Schedule for Later',
              subtitle: 'Publish at a specific date and time',
              onTap: () {
                setState(() {
                  _scheduleForLater = true;
                });
              },
            ),

            // Date Picker
            if (_scheduleForLater) ...[
              const SizedBox(height: 24),
              Text(
                'Schedule Time',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _selectScheduleDate,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(16),
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
                                color: _textPrimary,
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
                                    ? _textTertiary
                                    : _primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: _textTertiary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: _warningColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Schedule time must be at least 5 minutes from now',
                        style: TextStyle(
                          fontSize: 13,
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

  Widget _buildPublishOption({
    required bool isSelected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
              isSelected ? _primaryColor.withOpacity(0.05) : _backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primaryColor : _borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    isSelected ? _primaryColor : _textTertiary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : _textTertiary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? _primaryColor : _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? _primaryColor : _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _primaryColor : _textTertiary,
                  width: 2,
                ),
                color: isSelected ? _primaryColor : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
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
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                _scheduleForLater ? 'Schedule Lesson' : 'Publish Lesson Now',
                style: const TextStyle(
                  fontSize: 17,
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
