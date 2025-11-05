import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart' as camera_package;
import 'package:signsync_academy/core/services/lesson_creation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // Camera state - EXACTLY LIKE VideoUploadPage
  bool _isCameraInitializing = false;
  bool _isRecording = false;
  double _zoomLevel = 1.0;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  List<String> _availableSubjects = [];

  // Colors
  final Color _primaryColor = const Color(0xFF6366F1);
  final Color _backgroundColor = const Color(0xFFF8FAFC);
  final Color _surfaceColor = Colors.white;
  final Color _textPrimary = const Color(0xFF1E293B);
  final Color _textSecondary = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadEducatorData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _lessonService.dispose();
    _stopRecordingTimer();
    super.dispose();
  }

  void _startRecordingTimer() {
    _recordingDuration = Duration.zero;
    _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration += Duration(seconds: 1);
      });
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingDuration = Duration.zero;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _isCameraInitializing = true;
      });
      await _lessonService.initializeCamera();
      setState(() {
        _zoomLevel = _lessonService.currentZoomLevel;
      });
    } catch (e) {
      _showErrorDialog('Camera Error', e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
        });
      }
    }
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
      final videoFile = await _lessonService.pickVideoFromGallery();
      if (videoFile != null) {
        await _handleVideoSelected(videoFile);
      }
    } catch (e) {
      _showErrorDialog('Video Selection Error', e.toString());
    }
  }

  Future<void> _startRecording() async {
    try {
      await _lessonService.startRecording();
      setState(() {
        _isRecording = true;
      });
      _startRecordingTimer();
    } catch (e) {
      _showErrorDialog('Recording Failed', e.toString());
    }
  }

  Future<void> _stopRecording() async {
    try {
      final videoFile = await _lessonService.stopRecording();
      if (videoFile != null) {
        await _handleVideoSelected(videoFile);
      }
    } catch (e) {
      _showErrorDialog('Recording Error', e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
        _stopRecordingTimer();
      }
    }
  }

  Future<void> _handleVideoSelected(File videoFile) async {
    try {
      _lessonService.validateVideoFile(videoFile);

      final fileInfo = await _lessonService.getFileInfo(videoFile);

      setState(() {
        _selectedVideo = videoFile;
        _videoDuration = null;
      });

      final duration = await _lessonService.getVideoDuration(videoFile);
      setState(() {
        _videoDuration =
            '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
      });
    } catch (e) {
      _showErrorDialog('Video Error', e.toString());
    }
  }

  Future<void> _switchCamera() async {
    try {
      setState(() {
        _isCameraInitializing = true;
      });
      await _lessonService.switchCamera();
      setState(() {
        _zoomLevel = _lessonService.currentZoomLevel;
      });
    } catch (e) {
      _showErrorDialog('Camera Switch Error', e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
        });
      }
    }
  }

  Future<void> _setZoomLevel(double level) async {
    try {
      await _lessonService.setZoomLevel(level);
      setState(() {
        _zoomLevel = _lessonService.currentZoomLevel;
      });
    } catch (e) {
      debugPrint('Zoom error: $e');
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

      await _lessonService.createLessonUltraFast(
        title: _titleController.text.trim(),
        subject: _selectedSubject,
        grade: _selectedGrade,
        videoFile: _selectedVideo!,
        educatorId: user.id,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isPublished: !_scheduleForLater,
        scheduledPublish: _scheduleForLater ? _scheduledDate : null,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      await _showSuccessDialog();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorDialog('Lesson Creation Failed', e.toString());
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
        title: Text('Success!'),
        content: Text(
          _scheduleForLater
              ? 'Your lesson "${_titleController.text}" has been scheduled successfully!'
              : 'Your lesson "${_titleController.text}" has been published successfully!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectScheduleDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(minutes: 5)),
      firstDate: now.add(const Duration(minutes: 5)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5))),
      );

      if (time != null) {
        final DateTime scheduledDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        );

        setState(() {
          _scheduledDate = scheduledDateTime;
        });
      }
    }
  }

  String _formatScheduleDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  Widget _buildCameraPreview() {
    if (_isCameraInitializing) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 10),
              Text(
                'Initializing Camera...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (!_lessonService.isCameraInitialized) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off, color: Colors.white, size: 48),
              SizedBox(height: 10),
              Text(
                'Camera Not Available',
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _initializeCamera,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child:
                camera_package.CameraPreview(_lessonService.cameraController!),
          ),

          // Camera Controls - EXACTLY LIKE VideoUploadPage
          Positioned(
            top: 10,
            left: 10,
            child: Row(
              children: [
                // Switch Camera Button
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: Icon(Icons.cameraswitch, color: Colors.white),
                    onPressed: _switchCamera,
                  ),
                ),
                SizedBox(width: 10),
                // Zoom Indicator
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_zoomLevel.toStringAsFixed(1)}x',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Zoom Slider - EXACTLY LIKE VideoUploadPage
          Positioned(
            bottom: 10,
            left: 20,
            right: 20,
            child: Slider(
              value: _zoomLevel,
              min: 1.0,
              max: 5.0,
              onChanged: _setZoomLevel,
              activeColor: Colors.white,
              inactiveColor: Colors.white54,
            ),
          ),

          // Recording Timer - EXACTLY LIKE VideoUploadPage
          if (_isRecording)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.circle, color: Colors.white, size: 12),
                    SizedBox(width: 6),
                    Text(
                      _formatDuration(_recordingDuration),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Create New Lesson'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
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
            CircularProgressIndicator(
              value: _uploadProgress,
              backgroundColor: _textSecondary.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              strokeWidth: 8,
            ),
            SizedBox(height: 20),
            Text(
              '${(_uploadProgress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            SizedBox(height: 10),
            Text(
              _scheduleForLater
                  ? 'Scheduling Lesson...'
                  : 'Publishing Lesson...',
              style: TextStyle(
                fontSize: 16,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Selection - EXACTLY LIKE VideoUploadPage
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Lesson Video',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildCameraPreview(),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.video_library),
                            label: Text('Gallery'),
                            onPressed: _pickVideo,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(
                                _isRecording ? Icons.stop : Icons.videocam),
                            label: Text(_isRecording ? 'Stop' : 'Record'),
                            onPressed:
                                _isRecording ? _stopRecording : _startRecording,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isRecording ? Colors.red : _primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Selected Video Preview - EXACTLY LIKE VideoUploadPage
            if (_selectedVideo != null)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.video_file, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Selected Video:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Spacer(),
                          TextButton.icon(
                            icon: Icon(Icons.swap_horiz, size: 16),
                            label: Text('Replace'),
                            onPressed: _pickVideo,
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'File: ${_selectedVideo!.path.split('/').last}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4),
                      if (_videoDuration != null)
                        Text(
                          'Duration: $_videoDuration',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: Icon(Icons.play_arrow),
                        label: Text('Preview Video'),
                        onPressed: () {
                          // Add video preview functionality here
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 16),

            // Lesson Details
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lesson Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a lesson title';
                        }
                        if (value.trim().length < 2) {
                          return 'Title must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedSubject,
                      decoration: InputDecoration(
                        labelText: 'Subject',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.subject),
                      ),
                      items: _availableSubjects.map((String subject) {
                        return DropdownMenuItem<String>(
                          value: subject,
                          child: Text(subject),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedSubject = newValue!;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Grade: $_selectedGrade',
                      style: TextStyle(
                        fontSize: 16,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Schedule Options
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Publishing Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            leading: Radio<bool>(
                              value: false,
                              groupValue: _scheduleForLater,
                              onChanged: (value) {
                                setState(() {
                                  _scheduleForLater = false;
                                });
                              },
                            ),
                            title: Text('Publish Now'),
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            leading: Radio<bool>(
                              value: true,
                              groupValue: _scheduleForLater,
                              onChanged: (value) {
                                setState(() {
                                  _scheduleForLater = true;
                                });
                              },
                            ),
                            title: Text('Schedule'),
                          ),
                        ),
                      ],
                    ),
                    if (_scheduleForLater) ...[
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _selectScheduleDate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(_scheduledDate == null
                            ? 'Select Date & Time'
                            : 'Scheduled: ${_formatScheduleDate(_scheduledDate!)}'),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Create Button - EXACTLY LIKE VideoUploadPage
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createLesson,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  _scheduleForLater ? 'Schedule Lesson' : 'Publish Lesson',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
