import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeworkSubmission extends StatefulWidget {
  final String homeworkId;
  final Map<String, dynamic> studentData;

  const HomeworkSubmission({
    super.key,
    required this.homeworkId,
    required this.studentData,
  });

  @override
  State<HomeworkSubmission> createState() => _HomeworkSubmissionState();
}

class _HomeworkSubmissionState extends State<HomeworkSubmission>
    with WidgetsBindingObserver {
  final HomeworkService _homeworkService = HomeworkService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _commentsController = TextEditingController();

  File? _selectedVideo;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _isVideoInitializing = false;
  String? _videoDuration;
  Map<String, dynamic>? _homeworkDetails;
  bool _isAlreadySubmitted = false;
  Map<String, dynamic>? _existingSubmission;

  // Student-focused color scheme
  final Color _primaryColor = const Color(0xFF10B981);
  final Color _secondaryColor = const Color(0xFF059669);
  final Color _accentColor = const Color(0xFF34D399);
  final Color _successColor = const Color(0xFF10B981);
  final Color _warningColor = const Color(0xFFF59E0B);
  final Color _errorColor = const Color(0xFFEF4444);
  final Color _backgroundColor = const Color(0xFFF0FDF4);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF064E3B);
  final Color _hintColor = const Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHomeworkData();
    _checkExistingSubmission();
  }

  @override
  void dispose() {
    _commentsController.dispose();
    _homeworkService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _homeworkService.didChangeAppLifecycleState(state);
  }

  Future<void> _loadHomeworkData() async {
    try {
      final homeworkDetails =
          await _homeworkService.getHomeworkDetails(widget.homeworkId);
      setState(() {
        _homeworkDetails = homeworkDetails;
      });
    } catch (e) {
      debugPrint('Error loading homework details: $e');
    }
  }

  Future<void> _checkExistingSubmission() async {
    try {
      final studentId =
          widget.studentData['id'] ?? widget.studentData['user_id'];
      final isSubmitted = await _homeworkService.isHomeworkSubmitted(
          widget.homeworkId, studentId);
      final existingSubmission = await _homeworkService.getExistingSubmission(
          widget.homeworkId, studentId);

      setState(() {
        _isAlreadySubmitted = isSubmitted;
        _existingSubmission = existingSubmission;
      });
    } catch (e) {
      debugPrint('Error checking existing submission: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final videoFile = await _homeworkService.pickVideo();
      if (videoFile != null) {
        await _handleVideoSelected(videoFile);
      }
    } catch (e) {
      _showErrorDialog('Video Selection Error', e.toString());
    }
  }

  Future<void> _recordVideo() async {
    try {
      final isCameraAvailable =
          await _homeworkService.checkCameraAvailability();
      if (!isCameraAvailable) {
        _showErrorDialog(
            'Camera Unavailable', 'No camera found on this device.');
        return;
      }

      setState(() {
        _isVideoInitializing = true;
      });

      final videoFile = await _homeworkService.recordVideo();

      if (videoFile != null) {
        await _handleVideoSelected(videoFile);
        _showSuccessSnackbar('Video recorded successfully!');
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
      _homeworkService.validateVideoFile(videoFile);

      setState(() {
        _selectedVideo = videoFile;
        _videoDuration = null;
        _isVideoInitializing = true;
      });

      final duration = await _homeworkService.getVideoDuration(videoFile);
      setState(() {
        _videoDuration =
            '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
        _isVideoInitializing = false;
      });
    } catch (e) {
      setState(() {
        _isVideoInitializing = false;
      });
      _showErrorDialog('Video Error', e.toString());
    }
  }

  Future<void> _submitHomework() async {
    if (_selectedVideo == null) {
      _showErrorDialog('Missing Video',
          'Please select or record a video for your homework submission.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final studentId =
          widget.studentData['id'] ?? widget.studentData['user_id'];
      final studentCode = widget.studentData['student_code'] ?? 'N/A';
      final studentName = widget.studentData['full_name'] ?? 'Unknown Student';
      final studentGrade = widget.studentData['grade'] ?? 'Unknown Grade';

      // Get duration
      setState(() => _uploadProgress = 0.1);
      final duration = await _homeworkService.getVideoDuration(_selectedVideo!);

      // Upload video
      final videoUrl = await _homeworkService.uploadHomeworkVideo(
        homeworkId: widget.homeworkId,
        studentId: studentId,
        videoFile: _selectedVideo!,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = 0.1 + (progress * 0.7);
            });
          }
        },
      );

      setState(() => _uploadProgress = 0.8);

      // Submit homework
      if (_isAlreadySubmitted && _existingSubmission != null) {
        await _homeworkService.updateSubmission(
          submissionId: _existingSubmission!['id'],
          videoUrl: videoUrl,
          durationSeconds: duration.inSeconds,
          comments: _commentsController.text.trim().isEmpty
              ? null
              : _commentsController.text.trim(),
        );
      } else {
        await _homeworkService.submitHomework(
          homeworkId: widget.homeworkId,
          studentId: studentId,
          studentCode: studentCode,
          studentName: studentName,
          studentGrade: studentGrade,
          videoUrl: videoUrl,
          durationSeconds: duration.inSeconds,
          comments: _commentsController.text.trim().isEmpty
              ? null
              : _commentsController.text.trim(),
        );
      }

      setState(() => _uploadProgress = 1.0);
      await _showSuccessDialog();
    } catch (e) {
      _showErrorDialog('Submission Failed', e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
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
          _isAlreadySubmitted
              ? 'Your homework has been resubmitted successfully!'
              : 'Your homework has been submitted successfully!',
          style: TextStyle(
            fontSize: 16,
            color: _textColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          _isAlreadySubmitted ? 'Resubmit Homework' : 'Submit Homework',
          style: const TextStyle(
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
      body: _isUploading ? _buildUploadProgress() : _buildSubmissionForm(),
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
              _isAlreadySubmitted
                  ? 'Resubmitting Homework...'
                  : 'Submitting Homework...',
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
                  ? 'Preparing submission...'
                  : _uploadProgress < 0.8
                      ? 'Uploading video...'
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

  Widget _buildSubmissionForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHomeworkInfoCard(),
          const SizedBox(height: 20),
          _buildStudentInfoCard(),
          const SizedBox(height: 20),
          _buildVideoSubmissionCard(),
          const SizedBox(height: 20),
          _buildCommentsCard(),
          const SizedBox(height: 24),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildHomeworkInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  child: Icon(Icons.assignment, color: _primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Homework Assignment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_homeworkDetails != null) ...[
              Text(
                _homeworkDetails!['title'] ?? 'Untitled Homework',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
              if (_homeworkDetails!['description'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  _homeworkDetails!['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: _hintColor,
                  ),
                ),
              ],
              if (_homeworkDetails!['due_date'] != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: _hintColor),
                    const SizedBox(width: 8),
                    Text(
                      'Due: ${_formatDate(_homeworkDetails!['due_date'])}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _hintColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Loading homework details...',
                style: TextStyle(
                  fontSize: 14,
                  color: _hintColor,
                ),
              ),
            ],
            if (_isAlreadySubmitted) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _warningColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: _warningColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You have already submitted this homework. Submitting again will replace your previous submission.',
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

  Widget _buildStudentInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  child: Icon(Icons.person, color: _accentColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Student Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Name', widget.studentData['full_name'] ?? 'Unknown'),
            _buildInfoRow(
                'Student Code', widget.studentData['student_code'] ?? 'N/A'),
            _buildInfoRow('Grade', widget.studentData['grade'] ?? 'Unknown'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: _hintColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSubmissionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    color: _secondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.videocam, color: _secondaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Homework Video',
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
              _buildVideoSelection(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSelection() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hintColor.withOpacity(0.3), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_library, size: 48, color: _hintColor),
              const SizedBox(height: 12),
              Text(
                'Add your homework video',
                style: TextStyle(
                  fontSize: 16,
                  color: _hintColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Record or upload a video response',
                style: TextStyle(
                  fontSize: 12,
                  color: _hintColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.upload),
                label: const Text('Upload Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isVideoInitializing ? null : _recordVideo,
                icon: _isVideoInitializing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.videocam),
                label: const Text('Record'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryColor,
                  side: BorderSide(color: _primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
          height: 180,
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _primaryColor.withOpacity(0.3), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam, size: 48, color: _primaryColor),
              const SizedBox(height: 12),
              Text(
                'Video Ready',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
              if (_videoDuration != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Duration: $_videoDuration',
                  style: TextStyle(
                    color: _hintColor,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _selectedVideo!.path.split('/').last,
                style: TextStyle(
                  color: _hintColor,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Replace'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryColor,
                  side: BorderSide(color: _primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  _showSuccessSnackbar('Edit video feature coming soon!');
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _secondaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  child: Icon(Icons.comment, color: _accentColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Additional Comments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentsController,
              decoration: InputDecoration(
                hintText:
                    'Add any comments about your submission (optional)...',
                hintStyle: TextStyle(color: _hintColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _hintColor.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryColor),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 4,
              style: TextStyle(
                fontSize: 14,
                color: _textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _selectedVideo == null ? null : _submitHomework,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isAlreadySubmitted ? _warningColor : _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isAlreadySubmitted ? Icons.refresh : Icons.send,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _isAlreadySubmitted ? 'Resubmit Homework' : 'Submit Homework',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown date';
    }
  }
}

class HomeworkService with WidgetsBindingObserver {
  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();

  // Camera state management
  bool _isCameraInUse = false;
  bool _isAppInBackground = false;
  Completer<File?>? _recordingCompleter;

  HomeworkService() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _isAppInBackground = true;
        _cancelRecordingIfInProgress();
        break;
      case AppLifecycleState.resumed:
        _isAppInBackground = false;
        break;
      case AppLifecycleState.detached:
        _cleanupAllResources();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _cancelRecordingIfInProgress() {
    if (_isCameraInUse &&
        _recordingCompleter != null &&
        !_recordingCompleter!.isCompleted) {
      _recordingCompleter!.completeError(
          Exception('Recording interrupted - app went to background'));
      _recordingCompleter = null;
    }
    _isCameraInUse = false;
  }

  void _cleanupAllResources() {
    _isCameraInUse = false;
    _recordingCompleter = null;
  }

  // Check and request camera permissions
  Future<bool> _checkCameraPermissions() async {
    try {
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        cameraStatus = await Permission.camera.request();
      }

      var microphoneStatus = await Permission.microphone.status;
      if (!microphoneStatus.isGranted) {
        microphoneStatus = await Permission.microphone.request();
      }

      var storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        storageStatus = await Permission.storage.request();
      }

      return cameraStatus.isGranted &&
          microphoneStatus.isGranted &&
          storageStatus.isGranted;
    } catch (e) {
      debugPrint('Permission check error: $e');
      return false;
    }
  }

  // Pick video from gallery
  Future<File?> pickVideo() async {
    try {
      await _cleanupCameraResources();

      final XFile? pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );

      return pickedFile != null ? File(pickedFile.path) : null;
    } catch (e) {
      await _cleanupCameraResources();
      throw Exception('Failed to pick video: ${e.toString()}');
    }
  }

  // Record video using camera
  Future<File?> recordVideo() async {
    if (_isCameraInUse) {
      throw Exception('Camera is currently in use. Please wait...');
    }

    if (_isAppInBackground) {
      throw Exception('Cannot start recording while app is in background');
    }

    final hasPermissions = await _checkCameraPermissions();
    if (!hasPermissions) {
      throw Exception(
          'Camera, microphone, and storage permissions are required to record videos. Please enable them in app settings.');
    }

    _isCameraInUse = true;
    _recordingCompleter = Completer<File?>();

    try {
      await _preCameraSetup();

      final XFile? recordedFile = await _imagePicker
          .pickVideo(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxDuration: const Duration(minutes: 10),
      )
          .timeout(const Duration(seconds: 60), onTimeout: () {
        throw Exception(
            'Camera recording timed out. Please try recording a shorter video.');
      });

      if (recordedFile != null) {
        final file = File(recordedFile.path);
        if (await file.exists()) {
          _recordingCompleter!.complete(file);
          return file;
        } else {
          throw Exception('Recorded video file was not saved properly.');
        }
      } else {
        _recordingCompleter!.complete(null);
        return null;
      }
    } catch (e) {
      debugPrint('Camera recording error: $e');
      _recordingCompleter!.completeError(e);

      if (e.toString().contains('Permission') ||
          e.toString().contains('permission')) {
        throw Exception(
            'Camera permission denied. Please enable camera permissions in app settings.');
      } else if (e.toString().contains('timeout')) {
        throw Exception(
            'Recording took too long. Please try shorter recordings (1-2 minutes).');
      } else if (e.toString().contains('camera') ||
          e.toString().contains('Camera')) {
        throw Exception(
            'Camera is busy. Please close other camera apps and try again.');
      } else {
        throw Exception('Camera error: ${e.toString()}');
      }
    } finally {
      await _postCameraCleanup();
    }
  }

  Future<void> _preCameraSetup() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await Future(() {});
  }

  Future<void> _postCameraCleanup() async {
    _isCameraInUse = false;
    _recordingCompleter = null;
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _cleanupCameraResources() async {
    _isCameraInUse = false;
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // Check camera availability
  Future<bool> checkCameraAvailability() async {
    try {
      return true;
    } catch (e) {
      debugPrint('Camera availability check failed: $e');
      return false;
    }
  }

  // Validate video file
  void validateVideoFile(File videoFile) {
    final fileSize = videoFile.lengthSync();
    const maxSize = 200 * 1024 * 1024; // 200MB for homework submissions
    if (fileSize > maxSize) {
      throw Exception('Video file too large. Maximum size is 200MB');
    }

    final extension = path.extension(videoFile.path).toLowerCase();
    final allowedExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];
    if (!allowedExtensions.contains(extension)) {
      throw Exception('Unsupported video format');
    }
  }

  // Get video duration safely
  Future<Duration> getVideoDuration(File videoFile) async {
    try {
      try {
        final fileSize = await videoFile.length();
        if (fileSize > 0) {
          final estimatedSeconds = (fileSize / (500 * 1024)).ceil();
          return Duration(seconds: estimatedSeconds.clamp(5, 600));
        }
      } catch (e) {
        debugPrint('File size estimation failed: $e');
      }
      return const Duration(seconds: 60);
    } catch (e) {
      debugPrint('All duration methods failed, using default: $e');
      return const Duration(seconds: 60);
    }
  }

  // Transcode video to compatible format
  Future<File> transcodeVideoToCompatibleFormat(File originalVideo) async {
    try {
      print('Starting video transcoding for homework submission...');
      await VideoCompress.setLogLevel(0);

      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        originalVideo.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (mediaInfo == null || mediaInfo.file == null) {
        throw Exception('Video transcoding failed');
      }

      print('Homework video transcoding completed: ${mediaInfo.file!.path}');
      return File(mediaInfo.file!.path);
    } catch (e) {
      print('Homework video transcoding error: $e');
      return originalVideo;
    }
  }

  // Upload homework video
  Future<String> uploadHomeworkVideo({
    required String homeworkId,
    required String studentId,
    required File videoFile,
    required Function(double) onProgress,
  }) async {
    try {
      // Transcode video first (30% of progress)
      onProgress(0.1);
      final compatibleVideo = await transcodeVideoToCompatibleFormat(videoFile);
      onProgress(0.3);

      // Upload transcoded video (70% of progress)
      final fileName =
          'submission_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = 'homework_submissions/$homeworkId/$studentId/$fileName';

      await _client.storage.from('videos').uploadBinary(
            filePath,
            await compatibleVideo.readAsBytes(),
            fileOptions: const FileOptions(upsert: true),
          );

      onProgress(1.0);

      // Clean up temporary file
      try {
        if (compatibleVideo.path != videoFile.path) {
          await compatibleVideo.delete();
        }
      } catch (e) {
        print('Could not delete temporary video file: $e');
      }

      return _client.storage.from('videos').getPublicUrl(filePath);
    } catch (e) {
      print('Homework video upload failed: $e');
      throw Exception('Failed to upload homework video: ${e.toString()}');
    }
  }

  // Get homework details
  Future<Map<String, dynamic>?> getHomeworkDetails(String homeworkId) async {
    try {
      final response = await _client
          .from('homeworks')
          .select('*')
          .eq('id', homeworkId)
          .single();

      return response as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting homework details: $e');
      return null;
    }
  }

  // Check if homework is already submitted
  Future<bool> isHomeworkSubmitted(String homeworkId, String studentId) async {
    try {
      final response = await _client
          .from('homework_submissions')
          .select('id')
          .eq('homework_id', homeworkId)
          .eq('student_id', studentId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // Get existing submission
  Future<Map<String, dynamic>?> getExistingSubmission(
      String homeworkId, String studentId) async {
    try {
      final response = await _client
          .from('homework_submissions')
          .select('*')
          .eq('homework_id', homeworkId)
          .eq('student_id', studentId)
          .maybeSingle();

      return response as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  // Submit homework
  Future<String> submitHomework({
    required String homeworkId,
    required String studentId,
    required String studentCode,
    required String studentName,
    required String studentGrade,
    required String videoUrl,
    required int durationSeconds,
    String? comments,
  }) async {
    try {
      final response = await _client.from('homework_submissions').insert({
        'homework_id': homeworkId,
        'student_id': studentId,
        'student_code': studentCode,
        'student_name': studentName,
        'student_grade': studentGrade,
        'video_url': videoUrl,
        'duration_seconds': durationSeconds,
        'comments': comments,
        'submitted_at': DateTime.now().toIso8601String(),
        'status': 'submitted',
        'grade': null,
        'feedback': null,
      }).select('id');

      if (response.isEmpty) throw Exception('No ID returned');

      final submissionId = response.first['id'] as String;
      print('Homework submitted with ID: $submissionId');

      return submissionId;
    } catch (e) {
      print('Failed to submit homework: $e');
      throw Exception('Failed to submit homework: ${e.toString()}');
    }
  }

  // Update existing submission
  Future<void> updateSubmission({
    required String submissionId,
    required String videoUrl,
    required int durationSeconds,
    String? comments,
  }) async {
    try {
      await _client.from('homework_submissions').update({
        'video_url': videoUrl,
        'duration_seconds': durationSeconds,
        'comments': comments,
        'submitted_at': DateTime.now().toIso8601String(),
        'status': 'resubmitted',
        'grade': null,
        'feedback': null,
      }).eq('id', submissionId);

      print('Homework submission updated: $submissionId');
    } catch (e) {
      print('Failed to update submission: $e');
      throw Exception('Failed to update submission: ${e.toString()}');
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupAllResources();
  }
}
