// ignore_for_file: deprecated_member_use, unnecessary_import, unused_import, unused_field, prefer_const_constructors, unused_element, avoid_print

import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/lesson_creation_service.dart';
import '../../../core/models/lesson_data.dart';

class LessonCreation extends StatefulWidget {
  const LessonCreation({super.key});

  @override
  State<LessonCreation> createState() => _LessonCreationState();
}

class _LessonCreationState extends State<LessonCreation> with WidgetsBindingObserver {
  final LessonCreationService _lessonService = LessonCreationService();
  final ImagePicker _imagePicker = ImagePicker();
  late LessonData _lessonData;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Camera state
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  bool _isFrontCamera = false;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  String? _recordedVideoPath;

  // UI State
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadError;
  String? _temporaryVideoPath;
  Uint8List? _webVideoBytes;
  String? _webVideoFileName;
  bool _isExtractingDuration = false;

  // Video player
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideoLoading = false;
  bool _hasVideoError = false;

  // Data
  List<String> _availableSubjects = [];
  String _educatorGrade = '';
  bool _isLoadingData = true;

  // Scheduling
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Colors
  final Color _primaryColor = const Color(0xFF4361EE);
  final Color _successColor = const Color(0xFF10B981);
  final Color _warningColor = const Color(0xFFF59E0B);
  final Color _errorColor = const Color(0xFFEF4444);
  final Color _infoColor = const Color(0xFF3B82F6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _lessonData = LessonData(
      title: '',
      description: '',
      subject: '',
      grade: '',
      durationText: 'Duration will be auto-detected',
      videoFile: null,
      publishImmediately: true,
      scheduledDate: null,
    );

    _titleController.addListener(_updateLessonData);
    _descriptionController.addListener(_updateLessonData);
    
    _loadEducatorData();
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _descriptionController.dispose();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _cameraController?.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_cameraController != null) {
        _initializeCamera();
      }
    }
  }

  // ========== DATA METHODS ==========

  Future<void> _loadEducatorData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _educatorGrade = await _lessonService.getEducatorGrade(user.id);
        _availableSubjects = await _lessonService.getEducatorSubjects(user.id);

        // Add validation
        if (_educatorGrade.isEmpty) {
          _educatorGrade = 'Grade Not Set';
        }
        if (_availableSubjects.isEmpty) {
          _availableSubjects = ['General'];
        }

        setState(() {
          _lessonData = _lessonData.copyWith(
            grade: _educatorGrade,
            subject: _availableSubjects.first,
          );
          _isLoadingData = false;
        });
      } else {
        throw Exception('User not authenticated');
      }
    } catch (e) {
      print('Error loading educator data: $e');
      setState(() {
        _educatorGrade = 'Grade Not Set';
        _availableSubjects = ['General'];
        _isLoadingData = false;
      });
    }
  }

  void _updateLessonData() {
    setState(() {
      _lessonData = _lessonData.copyWith(
        title: _titleController.text,
        description: _descriptionController.text,
      );
    });
  }

  // ========== SCHEDULING METHODS ==========

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _updateScheduledDateTime();
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _updateScheduledDateTime();
      });
    }
  }

  void _updateScheduledDateTime() {
    if (_selectedDate != null && _selectedTime != null) {
      final scheduledDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Ensure the scheduled time is in the future
      if (scheduledDateTime.isAfter(DateTime.now())) {
        setState(() {
          _lessonData = _lessonData.copyWith(scheduledDate: scheduledDateTime);
        });
      } else {
        _showError('Scheduled time must be in the future');
        setState(() {
          _selectedDate = null;
          _selectedTime = null;
          _lessonData = _lessonData.copyWith(scheduledDate: null);
        });
      }
    }
  }

  void _clearScheduledDate() {
    setState(() {
      _selectedDate = null;
      _selectedTime = null;
      _lessonData = _lessonData.copyWith(scheduledDate: null);
    });
  }

  String _formatScheduledDate(DateTime date) {
    return '${_getWeekday(date.weekday)}, ${date.day} ${_getMonth(date.month)} ${date.year}';
  }

  String _formatScheduledTime(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _getWeekday(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }

  String _getMonth(int month) {
    switch (month) {
      case 1: return 'January';
      case 2: return 'February';
      case 3: return 'March';
      case 4: return 'April';
      case 5: return 'May';
      case 6: return 'June';
      case 7: return 'July';
      case 8: return 'August';
      case 9: return 'September';
      case 10: return 'October';
      case 11: return 'November';
      case 12: return 'December';
      default: return '';
    }
  }

  // ========== CAMERA METHODS ==========

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No cameras available');
      }

      final camera = _cameras!.first;
      
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing camera: $e');
      }
      _showError('Failed to initialize camera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    setState(() {
      _isCameraInitialized = false;
    });

    await _cameraController?.dispose();

    final newCameraId = _isFrontCamera ? 0 : 1;
    final camera = _cameras![newCameraId];

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
    );

    await _cameraController!.initialize();

    setState(() {
      _isCameraInitialized = true;
      _isFrontCamera = !_isFrontCamera;
    });
  }

  Future<void> _startRecording() async {
    if (!_isCameraInitialized || _isRecording) return;

    try {
      await _cameraController!.startVideoRecording();
      
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      // Start recording timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
      });

    } catch (e) {
      if (kDebugMode) {
        print('Error starting recording: $e');
      }
      _showError('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      
      _recordingTimer?.cancel();
      
      setState(() {
        _isRecording = false;
        _recordedVideoPath = videoFile.path;
      });

      // Process the recorded video
      final recordedVideo = File(videoFile.path);
      await _processRecordedVideo(recordedVideo, 'recorded_video.mp4');

    } catch (e) {
      if (kDebugMode) {
        print('Error stopping recording: $e');
      }
      _showError('Failed to stop recording: $e');
    }
  }

  // ========== VIDEO PROCESSING METHODS ==========

  Future<void> _processRecordedVideo(File videoFile, String fileName) async {
    try {
      setState(() {
        _temporaryVideoPath = videoFile.path;
        _lessonData = _lessonData.copyWith(
          videoFile: videoFile,
          durationText: 'Processing...',
        );
        _isExtractingDuration = true;
      });

      // Add file existence check
      if (!await videoFile.exists()) {
        throw Exception('Video file not found');
      }

      final duration = await _lessonService.getVideoDuration(videoFile);
      
      setState(() {
        _lessonData = _lessonData.copyWith(
          videoDuration: duration,
          durationText: _formatDurationForDisplay(duration),
        );
        _isExtractingDuration = false;
      });

      await _initializeVideoPlayer(videoFile: videoFile);
      
      _showSuccess('Video recorded successfully! Duration: ${_formatDurationForDisplay(duration)}');
      
    } catch (e) {
      setState(() {
        _isExtractingDuration = false;
        _lessonData = _lessonData.copyWith(durationText: 'Duration unknown');
      });
      _showError('Failed to process video: $e');
    }
  }

  Future<void> _processWebRecordedVideo(Uint8List videoBytes, String fileName) async {
    try {
      if (videoBytes.isEmpty) {
        throw Exception('Video bytes are empty');
      }

      setState(() {
        _webVideoBytes = videoBytes;
        _webVideoFileName = fileName;
        _lessonData = _lessonData.copyWith(
          videoFile: null,
          durationText: 'Processing...',
        );
        _isExtractingDuration = true;
      });

      final duration = await _lessonService.getVideoDurationFromBytes(videoBytes);
      
      setState(() {
        _lessonData = _lessonData.copyWith(
          videoDuration: duration,
          durationText: _formatDurationForDisplay(duration),
        );
        _isExtractingDuration = false;
      });

      _showSuccess('Video recorded successfully! Ready to upload.');
      
    } catch (e) {
      setState(() {
        _isExtractingDuration = false;
        _lessonData = _lessonData.copyWith(durationText: 'Duration unknown');
      });
      _showError('Failed to process recorded video: $e');
    }
  }

  // ========== VIDEO UPLOAD METHODS ==========

  Future<void> _uploadVideo() async {
    try {
      setState(() {
        _uploadError = null;
        _hasVideoError = false;
      });

      if (kIsWeb) {
        // For web, use image_picker
        final XFile? file = await _imagePicker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 30),
        );

        if (file != null) {
          final bytes = await file.readAsBytes();
          _webVideoBytes = bytes;
          _webVideoFileName = file.name;

          setState(() {
            _lessonData = _lessonData.copyWith(
              videoFile: null,
              durationText: 'Calculating duration...',
            );
            _isExtractingDuration = true;
          });

          final duration = await _lessonService.getVideoDurationFromBytes(bytes);

          setState(() {
            _lessonData = _lessonData.copyWith(
              videoDuration: duration,
              durationText: _formatDurationForDisplay(duration),
            );
            _isExtractingDuration = false;
          });

          _showFileSelected(file.name);
        }
      } else {
        // For mobile, use file_picker
        final result = await FilePicker.platform.pickFiles(
          type: FileType.video,
          allowMultiple: false,
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.single;

          if (file.path == null) {
            throw Exception('Unable to access video file path');
          }

          // Validate the file
          _lessonService.validateVideoFile(file);

          final videoFile = File(file.path!);
          _temporaryVideoPath = file.path!;

          setState(() {
            _lessonData = _lessonData.copyWith(
              videoFile: videoFile,
              durationText: 'Calculating duration...',
            );
            _isExtractingDuration = true;
          });

          final duration = await _lessonService.getVideoDuration(videoFile);

          setState(() {
            _lessonData = _lessonData.copyWith(
              videoDuration: duration,
              durationText: _formatDurationForDisplay(duration),
            );
            _isExtractingDuration = false;
          });

          await _initializeVideoPlayer(videoFile: videoFile);
          _showFileSelected(file.name);
        }
      }
    } catch (e) {
      _handleUploadError(e);
    }
  }

  Future<void> _initializeVideoPlayer({File? videoFile, String? videoUrl}) async {
    try {
      setState(() {
        _isVideoLoading = true;
        _hasVideoError = false;
      });

      await _videoPlayerController?.dispose();
      _chewieController?.dispose();

      if (videoFile != null) {
        _videoPlayerController = VideoPlayerController.file(videoFile);
      } else if (videoUrl != null) {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      } else {
        throw Exception('No video source provided');
      }

      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: _primaryColor,
          handleColor: _primaryColor,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey.withOpacity(0.5),
        ),
        placeholder: Container(
          color: Colors.grey.shade900,
          child: const Center(
            child: Icon(Icons.videocam_rounded, color: Colors.white, size: 50),
          ),
        ),
      );

      setState(() {
        _isVideoLoading = false;
      });
    } catch (e) {
      setState(() {
        _isVideoLoading = false;
        _hasVideoError = true;
      });
    }
  }

  // ========== SAVE LESSON ==========

  Future<void> _saveLesson() async {
    if (!_canSaveLesson) return;

    try {
      // Validate data before saving
      await _lessonService.validateLessonData(
        title: _lessonData.title,
        subject: _lessonData.subject,
        grade: _lessonData.grade,
        durationSeconds: _lessonData.videoDuration?.inSeconds ?? 0,
      );

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
        _uploadError = null;
      });

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final lessonId = await _lessonService.createLesson(
        title: _lessonData.title,
        subject: _lessonData.subject,
        grade: _lessonData.grade,
        durationSeconds: _lessonData.videoDuration?.inSeconds ?? 0,
        educatorId: user.id,
        description: _lessonData.description ?? '',
        isPublished: _lessonData.publishImmediately,
        scheduledPublish: _lessonData.scheduledDate,
      );

      String? videoUrl;
      String? thumbnailUrl;

      if (_lessonData.videoFile != null || _webVideoBytes != null) {
        if (kIsWeb && _webVideoBytes != null && _webVideoBytes!.isNotEmpty) {
          videoUrl = await _lessonService.uploadVideoWebFromList(
            lessonId: lessonId,
            educatorId: user.id,
            fileBytes: _webVideoBytes!,
            fileName: _webVideoFileName ?? 'video.mp4',
            onProgress: (progress) {
              if (mounted) {
                setState(() => _uploadProgress = progress * 0.8);
              }
            },
          );

          // Generate thumbnail with error handling
          if (_webVideoBytes != null && _webVideoBytes!.isNotEmpty) {
            try {
              thumbnailUrl = await _lessonService.generateThumbnailFromBytes(
                lessonId: lessonId,
                educatorId: user.id,
                videoBytes: _webVideoBytes!,
              );
            } catch (e) {
              print('Thumbnail generation failed: $e');
              // Continue without thumbnail
            }
          }
        } else if (!kIsWeb && _lessonData.videoFile != null) {
          videoUrl = await _lessonService.uploadVideo(
            lessonId: lessonId,
            educatorId: user.id,
            videoFile: _lessonData.videoFile!,
            onProgress: (progress) {
              if (mounted) {
                setState(() => _uploadProgress = progress * 0.8);
              }
            },
          );

          // Generate thumbnail with error handling
          try {
            thumbnailUrl = await _lessonService.generateThumbnail(
              lessonId: lessonId,
              educatorId: user.id,
              videoFile: _lessonData.videoFile!,
            );
          } catch (e) {
            print('Thumbnail generation failed: $e');
            // Continue without thumbnail
          }
        }

        if (videoUrl != null) {
          await _lessonService.updateLessonUrls(
            lessonId: lessonId,
            videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl ?? '',
          );
        }
      }

      _showSuccessAndNavigate();

    } catch (e) {
      _handleUploadError(e);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _handleUploadError(dynamic error) {
    String errorMessage = 'An unexpected error occurred';

    if (error is SocketException) {
      errorMessage = 'Network connection failed. Please check your internet.';
    } else if (error is HttpException) {
      errorMessage = 'Server error. Please try again later.';
    } else if (error is FormatException) {
      errorMessage = 'Invalid file format. Please try another video.';
    } else {
      errorMessage = error.toString();
    }

    setState(() {
      _uploadError = errorMessage;
      _isUploading = false;
    });

    _showError(errorMessage);
  }

  // ========== UI BUILDING METHODS ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressIndicator(),
          const SizedBox(height: 32),
          _buildLessonInfoForm(),
          const SizedBox(height: 32),
          _buildVideoSection(),
          const SizedBox(height: 32),
          _buildGradeSelection(),
          const SizedBox(height: 32),
          _buildSchedulingOptions(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getCardColor(),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _getBorderColor()),
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              color: _getTextColor(), size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Create New Lesson',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _getTextColor(),
          letterSpacing: -0.3,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: _lessonProgress,
          backgroundColor: Colors.grey.shade300,
          color: _primaryColor,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Lesson Creation Progress',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              '${(_lessonProgress * 100).round()}% Complete',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLessonInfoForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Lesson Information', Icons.info_outline_rounded, _infoColor),
        const SizedBox(height: 20),
        _buildFormField(
          label: 'Lesson Title *',
          hintText: 'Advanced Calculus: Derivatives & Applications',
          controller: _titleController,
          icon: Icons.title_rounded,
          maxLines: 1,
        ),
        const SizedBox(height: 20),
        _buildFormField(
          label: 'Description',
          hintText: 'Describe the lesson content and learning objectives...',
          controller: _descriptionController,
          icon: Icons.description_rounded,
          maxLines: 3,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _buildSubjectDropdown()),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDurationDisplay(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Video Content', Icons.videocam_rounded, _primaryColor),
        const SizedBox(height: 20),
        
        // Camera Preview
        _buildCameraPreview(),
        const SizedBox(height: 16),
        
        // Video Preview (if video is recorded/uploaded)
        if (_hasVideo) _buildVideoPreview(),
        
        // Video Options
        _buildVideoOptions(),
      ],
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _primaryColor),
              const SizedBox(height: 16),
              const Text(
                'Initializing Camera...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getBorderColor()),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CameraPreview(_cameraController!),
          ),
          
          // Recording indicator
          if (_isRecording) _buildRecordingIndicator(),
          
          // Camera controls
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: _buildCameraControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _errorColor.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _formatDurationForDisplay(_recordingDuration),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Switch camera button
        IconButton(
          onPressed: _switchCamera,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.flip_camera_ios_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        
        // Record button
        GestureDetector(
          onTap: _isRecording ? _stopRecording : _startRecording,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _isRecording ? _errorColor : Colors.white,
                width: 4,
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? _errorColor : Colors.white,
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.videocam_rounded,
                color: _isRecording ? Colors.white : _errorColor,
                size: 30,
              ),
            ),
          ),
        ),
        
        // Cancel button (only when recording)
        if (_isRecording)
          IconButton(
            onPressed: _stopRecording,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          )
        else
          const SizedBox(width: 48), // Placeholder for spacing
      ],
    );
  }

  Widget _buildVideoOptions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            'Upload Video',
            Icons.upload_rounded,
            _infoColor,
            'Choose from gallery',
            onTap: _uploadVideo,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionCard(
            'Record Video',
            Icons.videocam_rounded,
            _primaryColor,
            'Use device camera',
            onTap: () {
              // Camera is already showing, this is just for information
              _showInfo('Camera is ready for recording above');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPreview() {
    String fileName = 'Video Selected';
    if (_webVideoFileName != null) {
      fileName = _webVideoFileName!;
    } else if (_temporaryVideoPath != null) {
      fileName = path.basename(_temporaryVideoPath!);
    } else if (_lessonData.videoFile != null) {
      fileName = path.basename(_lessonData.videoFile!.path);
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 250,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _getBorderColor().withOpacity(0.5)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _isUploading ? _buildUploadProgress() : _buildVideoPlayer(),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getCardColor(),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _getBorderColor()),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.videocam_rounded, color: _primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fileName,
                      style: TextStyle(
                        color: _getTextColor(),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _successColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_lessonData.videoDuration != null)
                Row(
                  children: [
                    Icon(Icons.timer_rounded,
                        color: _getTextColor().withOpacity(0.6), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _formatDurationForDisplay(_lessonData.videoDuration!),
                      style: TextStyle(
                        color: _getTextColor().withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _playVideoFullScreen,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play Video'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: _uploadVideo,
                    icon: const Icon(Icons.replay_rounded),
                    tooltip: 'Replace Video',
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_uploadError != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _errorColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: _errorColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _uploadError!,
                    style: TextStyle(color: _errorColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    if (_isVideoLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _primaryColor),
              const SizedBox(height: 16),
              const Text(
                'Loading video preview...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasVideoError) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_rounded, color: _primaryColor, size: 50),
              const SizedBox(height: 16),
              const Text(
                'Video Selected',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                kIsWeb ? 'Ready to upload' : 'Tap Play Video to preview',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Chewie(controller: _chewieController!),
        ),
      );
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_rounded, color: Colors.white, size: 50),
            SizedBox(height: 8),
            Text(
              'No video selected',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            value: _uploadProgress > 0 ? _uploadProgress : null,
            color: _primaryColor,
            strokeWidth: 4,
          ),
          const SizedBox(height: 16),
          Text(
            '${(_uploadProgress * 100).round()}%',
            style: TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Uploading video...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeSelection() {
    if (_isLoadingData) {
      return _buildSectionHeader('Target Audience', Icons.people_alt_rounded, _successColor);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Target Audience', Icons.people_alt_rounded, _successColor),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _successColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _successColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.school_rounded, color: _successColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _educatorGrade,
                      style: TextStyle(
                        color: _getTextColor(),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Automatically assigned from your profile',
                      style: TextStyle(
                        color: _getTextColor().withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.check_circle_rounded, color: _successColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subject *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _getTextColor(),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _getBorderColor()),
          ),
          child: DropdownButtonFormField<String>(
            value: _lessonData.subject.isNotEmpty ? _lessonData.subject : null,
            items: _availableSubjects.map((String subject) {
              return DropdownMenuItem<String>(
                value: subject,
                child: Text(subject),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _lessonData = _lessonData.copyWith(subject: newValue);
                });
              }
            },
            decoration: InputDecoration(
              hintText: 'Select your subject',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              prefixIcon: Icon(Icons.category_rounded,
                  color: _getTextColor().withOpacity(0.5)),
            ),
            style: TextStyle(
              color: _getTextColor(),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duration',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _getTextColor(),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _getBorderColor()),
            color: _getCardColor(),
          ),
          child: Row(
            children: [
              Icon(Icons.timer_rounded,
                  color: _getTextColor().withOpacity(0.5), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _lessonData.durationText,
                  style: TextStyle(
                    color: _isExtractingDuration
                        ? _primaryColor
                        : _getTextColor().withOpacity(_hasVideo ? 1.0 : 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_isExtractingDuration)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _primaryColor,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSchedulingOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Scheduling', Icons.schedule_rounded, _warningColor),
        const SizedBox(height: 20),
        _buildScheduleOption(
          'Publish Immediately',
          'Lesson will be available to students right away',
          Icons.publish_rounded,
          _lessonData.publishImmediately,
          () => _scheduleLesson(immediate: true),
        ),
        const SizedBox(height: 16),
        _buildScheduleOption(
          'Schedule for Later',
          'Set a specific date and time for publication',
          Icons.schedule_rounded,
          !_lessonData.publishImmediately,
          () => _scheduleLesson(immediate: false),
        ),
        
        // Date and Time Picker (only shown when "Schedule for Later" is selected)
        if (!_lessonData.publishImmediately) ...[
          const SizedBox(height: 20),
          _buildDateTimePicker(),
        ],
      ],
    );
  }

  Widget _buildDateTimePicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _warningColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _warningColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: _warningColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Schedule Publication',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _getTextColor(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Date Picker
          _buildDateTimeOption(
            'Select Date',
            _selectedDate == null 
                ? 'Choose publication date'
                : _formatScheduledDate(_selectedDate!),
            Icons.calendar_month_rounded,
            _selectDate,
          ),
          const SizedBox(height: 12),
          
          // Time Picker
          _buildDateTimeOption(
            'Select Time',
            _selectedTime == null
                ? 'Choose publication time'
                : _formatScheduledTime(_selectedTime!),
            Icons.access_time_rounded,
            _selectTime,
          ),
          
          // Selected DateTime Display
          if (_selectedDate != null && _selectedTime != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _successColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: _successColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scheduled for:',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getTextColor().withOpacity(0.6),
                          ),
                        ),
                        Text(
                          '${_formatScheduledDate(_selectedDate!)} at ${_formatScheduledTime(_selectedTime!)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _getTextColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _clearScheduledDate,
                    icon: Icon(Icons.close_rounded, color: _errorColor, size: 16),
                    tooltip: 'Clear schedule',
                  ),
                ],
              ),
            ),
          ],
          
          // Validation message
          if (!_lessonData.publishImmediately && _lessonData.scheduledDate == null) ...[
            const SizedBox(height: 8),
            Text(
              'Please select both date and time to schedule publication',
              style: TextStyle(
                fontSize: 12,
                color: _errorColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateTimeOption(String title, String value, IconData icon, VoidCallback onTap) {
    return Material(
      color: _getCardColor(),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _getBorderColor()),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _warningColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _warningColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getTextColor(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        color: value.contains('Choose') 
                            ? _getTextColor().withOpacity(0.4)
                            : _primaryColor,
                        fontWeight: value.contains('Choose') ? FontWeight.normal : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, 
                  color: _getTextColor().withOpacity(0.5), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleOption(String title, String subtitle, IconData icon,
      bool isSelected, VoidCallback onTap) {
    return Material(
      color: isSelected ? _primaryColor.withOpacity(0.08) : _getCardColor(),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? _primaryColor : _getBorderColor(),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? _primaryColor : _getCardColor(),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? Colors.white
                      : _getTextColor().withOpacity(0.6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _getTextColor(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: _getTextColor().withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? _primaryColor : _getBorderColor(),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        color: _primaryColor,
                        size: 16,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: FloatingActionButton.extended(
        onPressed: _canSaveLesson && !_isUploading ? _saveLesson : null,
        backgroundColor:
            _canSaveLesson && !_isUploading ? _primaryColor : Colors.grey,
        foregroundColor: Colors.white,
        icon: _isUploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_rounded),
        label: Text(_isUploading ? 'Saving...' : 'Save Lesson'),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _getTextColor(),
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _getTextColor(),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: _getTextColor().withOpacity(0.4),
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _getBorderColor()),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _getBorderColor()),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
            filled: true,
            fillColor:
                enabled ? _getCardColor() : _getCardColor().withOpacity(0.5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            prefixIcon:
                Icon(icon, color: _getTextColor().withOpacity(0.5), size: 20),
          ),
          style: TextStyle(
            color: _getTextColor(),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, String subtitle,
      {VoidCallback? onTap}) {
    return Material(
      color: _getCardColor(),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _getBorderColor().withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _getTextColor(),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: _getTextColor().withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== HELPER METHODS ==========

  bool get _canSaveLesson {
    if (_lessonData.publishImmediately) {
      // For immediate publishing, no schedule validation needed
      return _titleController.text.isNotEmpty &&
          _lessonData.subject.isNotEmpty &&
          _lessonData.grade.isNotEmpty &&
          _hasVideo &&
          !_isLoadingData;
    } else {
      // For scheduled publishing, ensure schedule is set
      return _titleController.text.isNotEmpty &&
          _lessonData.subject.isNotEmpty &&
          _lessonData.grade.isNotEmpty &&
          _hasVideo &&
          !_isLoadingData &&
          _lessonData.scheduledDate != null;
    }
  }

  bool get _hasVideo {
    return _lessonData.videoFile != null || _webVideoBytes != null;
  }

  double get _lessonProgress {
    double progress = 0.0;
    if (_titleController.text.isNotEmpty) progress += 0.3;
    if (_lessonData.grade.isNotEmpty) progress += 0.3;
    if (_hasVideo) progress += 0.3;
    if (_lessonData.publishImmediately || _lessonData.scheduledDate != null) progress += 0.1;
    return progress;
  }

  String _formatDurationForDisplay(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  void _playVideoFullScreen() {
    if (_chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Video Preview'),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            backgroundColor: Colors.black,
            body: Center(
              child: Chewie(controller: _chewieController!),
            ),
          ),
        ),
      );
    } else {
      _showInfo('Please wait while the video loads...');
    }
  }

  // ========== UTILITY METHODS ==========

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _errorColor,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _successColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _infoColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showFileSelected(String fileName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: $fileName'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccessAndNavigate() {
    if (_lessonData.publishImmediately) {
      _showSuccess('Lesson created and published successfully!');
    } else {
      _showSuccess('Lesson created and scheduled for ${_formatScheduledDate(_lessonData.scheduledDate!)} at ${_formatScheduledTime(TimeOfDay.fromDateTime(_lessonData.scheduledDate!))}');
    }
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _scheduleLesson({required bool immediate}) {
    setState(() {
      _lessonData = _lessonData.copyWith(
        publishImmediately: immediate,
        scheduledDate: immediate ? null : _lessonData.scheduledDate,
      );
      
      // Clear date/time selection when switching to immediate publish
      if (immediate) {
        _selectedDate = null;
        _selectedTime = null;
      }
    });
  }

  Color _getBackgroundColor() => Colors.white;
  Color _getCardColor() => Colors.grey.shade50;
  Color _getBorderColor() => Colors.grey.shade300;
  Color _getTextColor() => Colors.grey.shade900;
}